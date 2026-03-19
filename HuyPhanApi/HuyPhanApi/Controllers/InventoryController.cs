using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace HuyPhanApi.Controllers  // giữ nguyên namespace của bạn
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
                        Vicode          AS ivcode,          -- alias để Flutter dùng 'ivcode' hoặc 'code'
                        RVC             AS rvc,             -- giữ thêm key 'rvc' để an toàn
                        vEnd             AS quantity,        -- tồn hệ thống (Flutter dùng 'quantity' hoặc 'vend')
                        Vperiod         AS period
                        
                    FROM Inventory
                    WHERE 1=1";

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

                sql += " ORDER BY Vicode";

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
                        var key = reader.GetName(i).ToLowerInvariant();  // tất cả key lowercase để Flutter dễ dùng
                        row[key] = reader.IsDBNull(i) ? null : reader.GetValue(i);
                    }
                    list.Add(row);
                }

                return Ok(list);
            }
            catch (Exception ex)
            {
                // Log lỗi để debug (có thể thêm logger sau)
                Console.WriteLine($"Lỗi API Inventory: {ex.Message}\n{ex.StackTrace}");
                return StatusCode(500, new { success = false, message = $"Lỗi server: {ex.Message}" });
            }
        }
    }
}