using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace HuyPhanApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]  // → api/inventory
    public class InventoryController : ControllerBase
    {
        private readonly string _connectionString;

        public InventoryController(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("Default")
                ?? throw new InvalidOperationException("Không tìm thấy connection string 'Default'");
        }

        [HttpGet]
        public async Task<IActionResult> Get(
            [FromQuery] string? vperiod = null,
            [FromQuery] string? rvc = null)
        {
            try
            {
                await using var conn = new SqlConnection(_connectionString);
                await conn.OpenAsync();

                var sql = @"
                    SELECT 
                        i.Vicode          AS ivcode,
                        dbo.fTCVNToUnicode(f.IName)          AS name,
                        i.RVC             AS rvc,
                        dbo.fTCVNToUnicode(l.RVCName)         AS rvcname,
                        i.vEnd            AS quantity,
                        i.Vperiod         AS period
                    FROM Inventory i
                    LEFT JOIN DefRVCList l ON i.RVC = l.RVCNo
                    LEFT JOIN ItemDef f ON i.VICode = f.ICode
                    WHERE 1=1";

                var parameters = new List<SqlParameter>();

                if (!string.IsNullOrWhiteSpace(vperiod))
                {
                    sql += " AND i.Vperiod = @Vperiod";
                    parameters.Add(new SqlParameter("@Vperiod", vperiod.Trim()));
                }

                if (!string.IsNullOrWhiteSpace(rvc))
                {
                    sql += " AND i.RVC = @RVC";
                    parameters.Add(new SqlParameter("@RVC", rvc.Trim()));
                }

                sql += " ORDER BY i.Vicode";

                await using var cmd = new SqlCommand(sql, conn);
                foreach (var p in parameters)
                {
                    cmd.Parameters.Add(p);
                }

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

                return Ok(list);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Lỗi API Inventory: {ex.Message}\n{ex.StackTrace}");
                return StatusCode(500, new { success = false, message = $"Lỗi server: {ex.Message}" });
            }
        }

        [HttpGet("locations")]
        public async Task<IActionResult> GetLocations()
        {
            try
            {
                await using var conn = new SqlConnection(_connectionString);
                await conn.OpenAsync();

                const string sql = @"
                    SELECT DISTINCT 
                        RVCNo AS code,
                        RVCName AS name
                    FROM DefRVCList
                    ORDER BY RVCNo";

                await using var cmd = new SqlCommand(sql, conn);
                await using var reader = await cmd.ExecuteReaderAsync();

                var list = new List<Dictionary<string, string>>();

                while (await reader.ReadAsync())
                {
                    list.Add(new Dictionary<string, string>
                    {
                        ["code"] = reader["code"].ToString().Trim(),
                        ["name"] = reader["name"]?.ToString().Trim() ?? "Không tên"
                    });
                }

                // Thêm mặc định "Tất cả"
                list.Insert(0, new Dictionary<string, string> { ["code"] = "", ["name"] = "Tất cả kho" });

                return Ok(list);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // ================== ENDPOINT QUÉT QR - THÊM VÀO ĐÂY ==================
        [HttpPost("search")]
        public async Task<IActionResult> SearchByQR([FromBody] QRSearchRequest request)
        {
            if (string.IsNullOrWhiteSpace(request?.QRCode))
            {
                return BadRequest(new { success = false, message = "QRCode không được để trống" });
            }

            try
            {
                await using var conn = new SqlConnection(_connectionString);
                await conn.OpenAsync();

                const string sql = @"
                    SELECT TOP 50
                        i.Vicode                                      AS ivcode,
                        i.RVC                                         AS rvc,
                        i.Vperiod                                     AS period,
                        i.vEnd                                        AS quantity,
                        dbo.fTCVNToUnicode(l.RVCName)                 AS rvcname,
                        ISNULL(NULLIF(TRIM(f.IName), ''), 'Không có tên') AS name,
                        ISNULL(NULLIF(TRIM(f.ICode), ''), i.Vicode)   AS code,
                        ''                                            AS imagePath
                    FROM Inventory i
                    LEFT JOIN DefRVCList l ON i.RVC = l.RVCNo
                    LEFT JOIN ItemDef f ON i.VICode = f.ICode
                    WHERE (i.Vicode = @QRCode OR f.ICode = @QRCode)
                    ORDER BY i.Vperiod DESC, i.Vicode";

                await using var cmd = new SqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@QRCode", request.QRCode.Trim());

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

                return Ok(new 
                { 
                    success = true, 
                    data = list,
                    message = list.Count > 0 ? $"Tìm thấy {list.Count} kết quả" : "Không tìm thấy sản phẩm với mã này"
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Lỗi SearchByQR: {ex.Message}\n{ex.StackTrace}");
                return StatusCode(500, new { success = false, message = "Lỗi server khi tìm kiếm QR" });
            }
        }
    }

    // ====================== MODEL HỖ TRỢ ======================
    public class QRSearchRequest
    {
        public string? QRCode { get; set; }
    }
}