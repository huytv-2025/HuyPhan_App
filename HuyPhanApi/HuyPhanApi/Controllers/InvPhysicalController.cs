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
        [HttpGet("get")]
public async Task<IActionResult> GetPhysicalInventory(
    [FromQuery] string? vperiod = null,
    [FromQuery] string? rvc = null)
{
    try
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();
// Bước 1: Xác định filterVPeriod (tự lấy INVPeriod mới nhất nếu không gửi param)
        string filterVPeriod;
        if (string.IsNullOrWhiteSpace(vperiod))
        {
            const string getLatestSql = @"
                SELECT TOP 1 ParaStr 
                FROM GlobPara 
                WHERE ParaName = 'INVPeriod'";

            await using var cmdLatest = new SqlCommand(getLatestSql, connection);
            var latest = await cmdLatest.ExecuteScalarAsync();
            filterVPeriod = latest?.ToString()?.Trim() ?? DateTime.Now.ToString("yyyyMM");
        }
        else
        {
            filterVPeriod = vperiod.Trim();
        }
        var sql = @"
            SELECT 
                Ivcode,
                Vend,
                Vphis,
                RVC,
                Vperiod,
                CreatedDate,          -- ← Thêm trường này
                CreatedBy             -- ← Optional: nếu muốn hiển thị người tạo luôn
            FROM QRInvPhisical
            WHERE IsActive = 1";

        var parameters = new List<SqlParameter>();

        if (!string.IsNullOrWhiteSpace(vperiod))
        {
            sql += " AND Vperiod = @Vperiod";
            parameters.Add(new SqlParameter("@Vperiod", vperiod.Trim()));
        }

        if (!string.IsNullOrWhiteSpace(rvc))
        {
            sql += " AND RVC = @RVC";
            parameters.Add(new SqlParameter("@RVC", rvc.Trim()));
        }

        sql += " ORDER BY Vperiod DESC, Ivcode";

        await using var cmd = new SqlCommand(sql, connection);
        foreach (var p in parameters)
        {
            cmd.Parameters.Add(p);
        }

        await using var reader = await cmd.ExecuteReaderAsync();

        var results = new List<Dictionary<string, object>>();

        while (await reader.ReadAsync())
        {
            results.Add(new Dictionary<string, object>
            {
                ["ivcode"]      = reader["Ivcode"],
                ["vend"]        = reader["Vend"],
                ["vphis"]       = reader["Vphis"] is decimal d ? d : 0m,
                ["rvc"]         = reader["RVC"],
                ["vperiod"]     = reader["Vperiod"],
                ["createdDate"] = reader.IsDBNull(reader.GetOrdinal("CreatedDate")) 
    ? null 
    : ((DateTime)reader["CreatedDate"]).ToString("dd/MM/yyyy HH:mm"),  // ← Format đẹp
                ["createdBy"]   = reader["CreatedBy"] ?? "Unknown"  // Optional
            });
        }

        return Ok(results);
    }
    catch (Exception ex)
    {
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