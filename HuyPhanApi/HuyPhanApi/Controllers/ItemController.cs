using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace HuyPhanApi.Controllers
{
    [ApiController]
    [Route("api/item")]
    public class ItemController : ControllerBase
    {
        private readonly string _connectionString;

        public ItemController(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("Default")
                ?? throw new InvalidOperationException("Không tìm thấy connection string 'Default'.");
        }

        [HttpGet("qr-list")]
public async Task<IActionResult> GetQrList(
    [FromQuery] string? vperiod = null,
    [FromQuery] string? fromIcode = null,
    [FromQuery] string? toIcode = null,
    [FromQuery] string? name = null)
{
    try
    {
        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync();

        var sql = @"
            SELECT Icode, Iname
            FROM ItemDef
            WHERE 1 = 1";

        var parameters = new List<SqlParameter>();

        // Lọc kỳ (nếu có)
        if (!string.IsNullOrWhiteSpace(vperiod))
        {
            sql += " AND Vperiod = @Vperiod";
            parameters.Add(new SqlParameter("@Vperiod", vperiod.Trim()));
        }

        // Xử lý from/to theo kiểu prefix khi bằng nhau
        string from = fromIcode?.Trim();
        string to = toIcode?.Trim();

        if (!string.IsNullOrWhiteSpace(from) || !string.IsNullOrWhiteSpace(to))
        {
            if (string.Equals(from, to, StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(from))
            {
                // Trường hợp "từ 10 đến 10" → tìm tất cả mã bắt đầu bằng "10"
                sql += " AND Icode LIKE @Prefix + '%'";
                parameters.Add(new SqlParameter("@Prefix", from));
            }
            else
            {
                // Range bình thường
                if (!string.IsNullOrWhiteSpace(from))
                {
                    sql += " AND Icode >= @FromIcode";
                    parameters.Add(new SqlParameter("@FromIcode", from));
                }

                if (!string.IsNullOrWhiteSpace(to))
                {
                    sql += " AND Icode <= @ToIcode";
                    parameters.Add(new SqlParameter("@ToIcode", to));
                }
            }
        }

        // Tìm theo tên
        if (!string.IsNullOrWhiteSpace(name))
        {
            sql += " AND Iname LIKE @Name";
            parameters.Add(new SqlParameter("@Name", "%" + name.Trim() + "%"));
        }

        sql += " ORDER BY Icode";

        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddRange(parameters.ToArray());

        await using var reader = await cmd.ExecuteReaderAsync();

        var results = new List<Dictionary<string, object>>();

        while (await reader.ReadAsync())
        {
            results.Add(new Dictionary<string, object>
            {
                ["Icode"] = reader["Icode"]?.ToString()?.Trim() ?? "",
                ["Iname"] = reader["Iname"]?.ToString()?.Trim() ?? "Không tên"
            });
        }

        return Ok(results);
    }
    catch (Exception ex)
    {
        Console.WriteLine("Lỗi GetQrList: " + ex.ToString());
        return StatusCode(500, new { success = false, message = ex.Message });
    }
}

        [HttpPost("generate-batch-qr")]
        public async Task<IActionResult> GenerateBatchQR([FromBody] GenerateBatchRequest request)
        {
            if (request?.Codes == null || request.Codes.Count == 0)
                return BadRequest(new { success = false, message = "Danh sách mã rỗng" });

            try
            {
                await using var conn = new SqlConnection(_connectionString);
                await conn.OpenAsync();

                int processed = 0;
                var errors = new List<string>();

                // Kiểm tra mã có tồn tại trong ItemDef
                const string checkExists = @"
                    SELECT COUNT(*) FROM ItemDef WHERE Icode = @Ivcode";

                // UPSERT vào bảng QRItem
                const string upsertSql = @"
                    MERGE INTO QRItem AS target
                    USING (VALUES (@Ivcode, @QRCode, @CreatedBy, GETDATE(), 1, NULL)) AS source 
                        (Ivcode, QRCode, CreatedBy, CreatedDate, IsActive, ImagePath)
                    ON target.Ivcode = source.Ivcode
                    WHEN MATCHED THEN
                        UPDATE SET 
                            target.QRCode     = source.QRCode,
                            target.CreatedBy  = source.CreatedBy,
                            target.CreatedDate = source.CreatedDate,
                            target.IsActive   = source.IsActive,
                            target.ImagePath  = source.ImagePath
                    WHEN NOT MATCHED THEN
                        INSERT (Ivcode, QRCode, CreatedBy, CreatedDate, IsActive, ImagePath)
                        VALUES (source.Ivcode, source.QRCode, source.CreatedBy, source.CreatedDate, source.IsActive, source.ImagePath);";

                foreach (var rawCode in request.Codes.Distinct())
                {
                    if (string.IsNullOrWhiteSpace(rawCode)) continue;
                    var ivcode = rawCode.Trim();

                    // Kiểm tra tồn tại
                    await using var checkCmd = new SqlCommand(checkExists, conn);
                    checkCmd.Parameters.AddWithValue("@Ivcode", ivcode);
                    int count = Convert.ToInt32(await checkCmd.ExecuteScalarAsync());

                    if (count == 0)
                    {
                        errors.Add($"Mã {ivcode} không tồn tại trong ItemDef");
                        continue;
                    }

                    var qrValue = $"HPAPP:{ivcode}";

                    await using var cmd = new SqlCommand(upsertSql, conn);
                    cmd.Parameters.AddWithValue("@Ivcode", ivcode);
                    cmd.Parameters.AddWithValue("@QRCode", qrValue);
                    cmd.Parameters.AddWithValue("@CreatedBy", request.CreatedBy ?? "MobileApp");

                    int rows = await cmd.ExecuteNonQueryAsync();
                    if (rows > 0)
                    {
                        processed++;
                    }
                }

                string message = $"Đã xử lý thành công {processed} mã QR.";
                if (errors.Count > 0)
                    message += $"\nLỗi: {string.Join("; ", errors)}";

                return Ok(new
                {
                    success = true,
                    message,
                    processed,
                    failed = errors.Count
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine("Lỗi GenerateBatchQR: " + ex.ToString());
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }

    // Model (nếu chưa di chuyển ra Models folder thì giữ ở đây)
    public class GenerateBatchRequest
    {
        public List<string> Codes { get; set; } = new();
        public string? CreatedBy { get; set; }
    }
}