using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace HuyPhanApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class InventoryController : ControllerBase
{
    private readonly string _connectionString = 
        "Server=.;Database=SMILE_BO;Trusted_Connection=True;TrustServerCertificate=True;";

    // GET: api/inventory?vperiod=...&search=...
    [HttpGet("")]
    public async Task<IActionResult> Get([FromQuery] string? vperiod, [FromQuery] string? search)
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var query = @"
                SELECT 
                    i.VICode, 
                    i.VEnd, 
                    i.VPeriod, 
                    dbo.fTCVNToUnicode(id.IName) AS IName
                FROM Inventory i
                LEFT JOIN Itemdef id ON LTRIM(RTRIM(i.VICode)) = LTRIM(RTRIM(id.Icode))
                WHERE 1 = 1";

            if (!string.IsNullOrEmpty(vperiod))
                query += " AND i.VPeriod = @VPeriod";

            if (!string.IsNullOrEmpty(search))
                query += " AND (i.VICode LIKE '%' + @Search + '%' OR dbo.fTCVNToUnicode(id.IName) LIKE '%' + @Search + '%')";

            query += " ORDER BY i.VICode";

            await using var command = new SqlCommand(query, connection);

            if (!string.IsNullOrEmpty(vperiod))
                command.Parameters.AddWithValue("@VPeriod", vperiod);

            if (!string.IsNullOrEmpty(search))
                command.Parameters.AddWithValue("@Search", search);

            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<object>();
            while (await reader.ReadAsync())
            {
                list.Add(new
                {
                    ivcode = reader["VICode"]?.ToString()?.Trim() ?? "",
                    vend = reader["VEnd"]?.ToString() ?? "0",
                    vperiod = reader["VPeriod"]?.ToString() ?? "",
                    iname = reader["IName"]?.ToString()?.Trim() ?? ""
                });
            }

            return Ok(list);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }

    // POST: api/inventory/search
    [HttpPost("search")]
    public async Task<IActionResult> SearchByQR([FromBody] QRRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.QRCode))
        {
            return BadRequest(new { success = false, message = "Vui lòng nhập hoặc quét QR/Barcode" });
        }

        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var query = @"
                SELECT 
                    i.VICode, 
                    i.VEnd, 
                    dbo.fTCVNToUnicode(id.IName) AS IName
                FROM Inventory i
                LEFT JOIN Itemdef id ON LTRIM(RTRIM(i.VICode)) = LTRIM(RTRIM(id.Icode))
                WHERE LTRIM(RTRIM(i.VICode)) = @QRCode";

            await using var command = new SqlCommand(query, connection);
            command.Parameters.AddWithValue("@QRCode", request.QRCode.Trim());

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return Ok(new
                {
                    success = true,
                    data = new
                    {
                        ivcode = reader["VICode"]?.ToString()?.Trim() ?? "",
                        vend = reader["VEnd"]?.ToString() ?? "0",
                        iname = reader["IName"]?.ToString()?.Trim() ?? "Không có tên"
                    }
                });
            }

            return NotFound(new { success = false, message = "Không tìm thấy sản phẩm với QR/Barcode này" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }

    // POST: api/inventory/generate-batch
    [HttpPost("generate-batch")]
    public async Task<IActionResult> GenerateBatchQR([FromBody] GenerateBatchRequest request)
    {
        if (request == null || request.Ivcodes == null || !request.Ivcodes.Any())
        {
            return BadRequest(new { success = false, message = "Danh sách mã hàng trống" });
        }

        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

            const string sql = @"
                IF EXISTS (SELECT 1 FROM QRInventory WHERE Ivcode = @Ivcode)
                BEGIN
                    UPDATE QRInventory
                    SET QRCode = @QRCode, CreatedDate = GETDATE(), CreatedBy = @CreatedBy
                    WHERE Ivcode = @Ivcode
                END
                ELSE
                BEGIN
                    INSERT INTO QRInventory (Ivcode, QRCode, CreatedBy, CreatedDate)
                    VALUES (@Ivcode, @QRCode, @CreatedBy, GETDATE())
                END";

            foreach (var ivcode in request.Ivcodes)
            {
                var qrData = $"HPAPP:{ivcode.Trim()}";

                await using var cmd = new SqlCommand(sql, connection, transaction);
                cmd.Parameters.AddWithValue("@Ivcode", ivcode.Trim());
                cmd.Parameters.AddWithValue("@QRCode", qrData);
                cmd.Parameters.AddWithValue("@CreatedBy", request.CreatedBy ?? "System");

                await cmd.ExecuteNonQueryAsync();
            }

            await transaction.CommitAsync();

            return Ok(new
            {
                success = true,
                message = $"Đã tạo/cập nhật QR cho {request.Ivcodes.Count} sản phẩm thành công!"
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }
}

// Model classes - đặt ngoài controller
public class QRRequest
{
    public string QRCode { get; set; } = string.Empty;
}

public class GenerateBatchRequest
{
    public List<string> Ivcodes { get; set; } = new();
    public string? CreatedBy { get; set; }
}