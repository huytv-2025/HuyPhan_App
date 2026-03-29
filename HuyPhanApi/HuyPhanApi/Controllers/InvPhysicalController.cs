using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Data;
using HuyPhanApi.Services;

namespace HuyPhanApi.Controllers
{
    [ApiController]
    [Route("api/invphysical")]
    public class InvPhysicalController : ControllerBase
    {
        private readonly string _connectionString;
        private readonly FcmService _fcmService; // ← Inject FcmService

        public InvPhysicalController(
            IConfiguration configuration, 
            FcmService fcmService) // ← Thêm FcmService vào constructor
        {
            _connectionString = configuration.GetConnectionString("Default") 
                ?? throw new InvalidOperationException(
                    "Không tìm thấy connection string 'Default' trong configuration " +
                    "(appsettings.json / secrets.json / environment variables).");

            _fcmService = fcmService;
        }
       [HttpPost("save")]
public async Task<IActionResult> SavePhysicalInventory([FromBody] SavePhysicalRequest request)
{
    if (request?.Items == null || request.Items.Count == 0)
    {
        return BadRequest(new { success = false, message = "Dữ liệu không hợp lệ hoặc rỗng" });
    }

    await using var connection = new SqlConnection(_connectionString);
    await connection.OpenAsync();

    // Cast ngay từ đầu để đảm bảo kiểu
    await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

    try
    {
        int insertedCount = 0;

        const string sql = @"
            IF NOT EXISTS (
                SELECT 1 FROM QRInvPhisical 
                WHERE Ivcode = @Ivcode AND RVC = @RVC AND Vperiod = @Vperiod
            )
            BEGIN
                INSERT INTO QRInvPhisical 
                (Ivcode, Vend, Vphis, RVC, Vperiod, CreatedDate, CreatedBy, IsActive)
                VALUES (@Ivcode, @Vend, @Vphis, @RVC, @Vperiod, GETDATE(), @CreatedBy, 1);
            END
            ELSE
            BEGIN
                UPDATE QRInvPhisical
                SET Vend = @Vend,
                    Vphis = @Vphis,
                    CreatedDate = GETDATE(),
                    CreatedBy = @CreatedBy
                WHERE Ivcode = @Ivcode AND RVC = @RVC AND Vperiod = @Vperiod;
            END";

        foreach (var item in request.Items)
        {
            if (string.IsNullOrWhiteSpace(item.Ivcode) || 
                string.IsNullOrWhiteSpace(item.RVC) || 
                string.IsNullOrWhiteSpace(item.Vperiod))
                continue;

            await using var cmd = new SqlCommand(sql, connection, transaction);  // ← Bây giờ đúng kiểu

            cmd.Parameters.AddWithValue("@Ivcode", item.Ivcode.Trim());
            cmd.Parameters.AddWithValue("@Vend", item.Vend);
            cmd.Parameters.AddWithValue("@Vphis", item.Vphis);
            cmd.Parameters.AddWithValue("@RVC", item.RVC.Trim());
            cmd.Parameters.AddWithValue("@Vperiod", item.Vperiod.Trim());
            cmd.Parameters.AddWithValue("@CreatedBy", item.CreatedBy ?? "MobileApp");

            insertedCount += await cmd.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();

        // ... phần badge update giữ nguyên ...

        return Ok(new 
        { 
            success = true, 
            message = $"Đã lưu thành công {insertedCount} dòng kiểm kê vật lý",
            count = insertedCount 
        });
    }
    catch (Exception ex)
    {
        await transaction.RollbackAsync();
        Console.WriteLine($"Lỗi lưu kiểm kê: {ex.Message}\nStackTrace: {ex.StackTrace}");
        return StatusCode(500, new { success = false, message = $"Lỗi server: {ex.Message}" });
    }
}
        [HttpGet]   // Giữ nguyên [HttpGet] vì Flutter đang gọi /api/invphysical
public async Task<IActionResult> Get(
    [FromQuery] string? vperiod = null,
    [FromQuery] string? rvc = null)
{
    try
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        // Bước 1: Xác định kỳ lọc (nếu không gửi → lấy kỳ lớn nhất từ GlobPara hoặc max trong Inventory)
        string filterVPeriod;
        if (string.IsNullOrWhiteSpace(vperiod))
        {
            // Cách 1: Lấy từ GlobPara (nếu bạn dùng bảng này để lưu kỳ hiện hành)
            const string getLatestSql = @"
                SELECT TOP 1 ParaStr 
                FROM GlobPara 
                WHERE ParaName = 'INVPeriod'";

            await using var cmdLatest = new SqlCommand(getLatestSql, conn);
            var latest = await cmdLatest.ExecuteScalarAsync();
            filterVPeriod = latest?.ToString()?.Trim();

            // Nếu GlobPara không có → fallback lấy kỳ max từ bảng Inventory
            if (string.IsNullOrWhiteSpace(filterVPeriod))
            {
                const string getMaxPeriod = "SELECT MAX(Vperiod) FROM Inventory";
                await using var cmdMax = new SqlCommand(getMaxPeriod, conn);
                filterVPeriod = (await cmdMax.ExecuteScalarAsync())?.ToString()?.Trim() 
                    ?? DateTime.Now.ToString("yyyyMM");
            }
        }
        else
        {
            filterVPeriod = vperiod.Trim();
        }

        var sql = @"
            SELECT 
                i.Vicode          AS ivcode,
                i.RVC             AS rvc,
                dbo.fTCVNToUnicode(l.RVCName)         AS rvcname,
                i.vEnd            AS quantity,          -- Tồn hệ thống
                i.Vperiod         AS period,
                ISNULL(NULLIF(TRIM(d.IName), ''), 'Không có tên') AS name,              -- ← TÊN HÀNG từ bảng DefItem (hoặc bảng sản phẩm của bạn)
                p.Vphis           AS vphis,             -- ← Tồn vật lý từ QRInvPhisical
                p.CreatedDate     AS createdDate        -- ← Ngày kiểm kê
            FROM Inventory i
            LEFT JOIN DefRVCList l ON i.RVC = l.RVCNo
            LEFT JOIN ItemDef d ON i.VICode = d.ICode   -- ← JOIN bảng sản phẩm để lấy tên (đổi tên bảng nếu khác)
            LEFT JOIN QRInvPhisical p ON 
                p.Ivcode = i.Vicode 
                AND p.RVC = i.RVC 
                AND p.Vperiod = i.Vperiod
            WHERE i.Vperiod = @Vperiod";  // ← Luôn lọc theo kỳ đã xác định

        var parameters = new List<SqlParameter>
        {
            new SqlParameter("@Vperiod", filterVPeriod)
        };

        if (!string.IsNullOrWhiteSpace(rvc))
        {
            sql += " AND i.RVC = @RVC";
            parameters.Add(new SqlParameter("@RVC", rvc.Trim()));
        }

        sql += " ORDER BY i.Vicode";

        await using var cmd = new SqlCommand(sql, conn);
        foreach (var p in parameters) cmd.Parameters.Add(p);

        await using var reader = await cmd.ExecuteReaderAsync();
        var list = new List<Dictionary<string, object>>();

        while (await reader.ReadAsync())
        {
            var row = new Dictionary<string, object>();
            for (int i = 0; i < reader.FieldCount; i++)
            {
                var key = reader.GetName(i).ToLowerInvariant();
                row[key] = reader.IsDBNull(i) ? null : reader.GetValue(i);
            }
            list.Add(row);
        }

        // Trả thêm thông tin kỳ đang dùng (để Flutter hiển thị)
        return Ok(new 
        {
            data = list,
            currentVperiod = filterVPeriod
        });
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Lỗi API invphysical/get: {ex}");
        return StatusCode(500, new { success = false, message = ex.Message });
    }
}
    // Models
    public class SavePhysicalRequest
    {
        public List<PhysicalItem> Items { get; set; } = new();
    }

    public class PhysicalItem
    {
        public string Ivcode { get; set; } = string.Empty;
        public decimal Vend { get; set; }
        public decimal Vphis { get; set; }
        public string RVC { get; set; } = string.Empty;
        public string Vperiod { get; set; } = string.Empty;
        public string? CreatedBy { get; set; }
    }
}}