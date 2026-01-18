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
    if (request == null || request.Items == null || request.Items.Count == 0)
    {
        return BadRequest(new { success = false, message = "Dữ liệu không hợp lệ" });
    }

    await using var connection = new SqlConnection(_connectionString);
    await connection.OpenAsync();

    await using var transaction = await connection.BeginTransactionAsync();  // ← ĐÚNG: không cast

    try
    {
        int insertedCount = 0;

        const string sql = @"
            IF NOT EXISTS (
                SELECT 1 FROM QRInvPhisical 
                WHERE Ivcode = @Ivcode AND RVC = @RVC AND Vperiod = @Vperiod AND Vphis = @Vphis
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
                -- Lưu ý: không điều kiện Vphis = @Vphis ở WHERE vì ta đang update nó
            END";

        foreach (var item in request.Items)
        {
            if (string.IsNullOrWhiteSpace(item.Ivcode) || 
                string.IsNullOrWhiteSpace(item.RVC) || 
                string.IsNullOrWhiteSpace(item.Vperiod))
                continue;

            await using var cmd = new SqlCommand(sql, connection, transaction as SqlTransaction); // ← cast ở đây nếu cần, nhưng thường không cần

            cmd.Parameters.AddWithValue("@Ivcode", item.Ivcode.Trim());
            cmd.Parameters.AddWithValue("@Vend", item.Vend);
            cmd.Parameters.AddWithValue("@Vphis", item.Vphis);
            cmd.Parameters.AddWithValue("@RVC", item.RVC.Trim());
            cmd.Parameters.AddWithValue("@Vperiod", item.Vperiod.Trim());
            cmd.Parameters.AddWithValue("@CreatedBy", item.CreatedBy ?? "MobileApp");

            insertedCount += await cmd.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();

        // Gửi badge update (giữ nguyên)
        int badgeCount = await CalculateBadgeCount();
        if (badgeCount > 0)
        {
            await _fcmService.SendSilentBadgeUpdate(badgeCount);
        }

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
        // Log lỗi thật (nên dùng ILogger)
        Console.WriteLine(ex); // tạm thời
        return StatusCode(500, new 
        { 
            success = false, 
            message = $"Lỗi server: {ex.Message}" 
        });
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

                var sql = @"
                    SELECT 
                        Ivcode,
                        Vend,
                        Vphis,
                        RVC,
                        Vperiod
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
                        ["ivcode"] = reader["Ivcode"],
                        ["vend"] = reader["Vend"],
                        ["vphis"]   = reader["Vphis"] is decimal d ? d : 0m,
                        ["rvc"] = reader["RVC"],
                        ["vperiod"] = reader["Vperiod"]
                    });
                }

                return Ok(results);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
        private async Task<int> CalculateBadgeCount()
        {
            await using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();

            var sql = @"
                SELECT COUNT(*) 
                FROM Inventory 
                WHERE LastModified > DATEADD(minute, -60, GETDATE())"; // Thay đổi trong 60 phút gần nhất
                // Bạn có thể điều chỉnh thời gian hoặc điều kiện khác (ví dụ: so với LastViewed của user)

            await using var cmd = new SqlCommand(sql, conn);
            var count = (int)(await cmd.ExecuteScalarAsync() ?? 0);
            return count;
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
}