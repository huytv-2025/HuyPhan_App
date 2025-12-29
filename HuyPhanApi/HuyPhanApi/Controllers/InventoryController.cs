using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace HuyPhanApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class InventoryController : ControllerBase
{
    private readonly string _connectionString = 
        "Server=.;Database=SMILE_BO;Trusted_Connection=True;TrustServerCertificate=True;";

    [HttpGet("")]
    public async Task<IActionResult> Get([FromQuery] string? vperiod, [FromQuery] string? search)
    {
        try
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var query = @"SELECT i.VICode, i.VEnd, i.VPeriod, dbo.fTCVNToUnicode(id.IName) as IName
                          FROM Inventory i
                          LEFT JOIN Itemdef id ON LTRIM(RTRIM(i.VICode)) = LTRIM(RTRIM(id.Icode))
                          WHERE 1=1";

            if (!string.IsNullOrEmpty(vperiod))
            {
                query += " AND i.VPeriod = @VPeriod";
            }

            if (!string.IsNullOrEmpty(search))
            {
                query += " AND (i.VICode LIKE '%' + @Search + '%' OR dbo.fTCVNToUnicode(id.IName) LIKE '%' + @Search + '%')";
            }

            query += " ORDER BY i.VICode";

            using var command = new SqlCommand(query, connection);
            if (!string.IsNullOrEmpty(vperiod))
            {
                command.Parameters.AddWithValue("@VPeriod", vperiod);
            }
            if (!string.IsNullOrEmpty(search))
            {
                command.Parameters.AddWithValue("@Search", search);
            }

            using var reader = await command.ExecuteReaderAsync();

            var list = new List<object>();
            while (await reader.ReadAsync())
            {
                list.Add(new
                {
                    ivcode = reader["VICode"]?.ToString()?.Trim() ?? "",
                    vend = reader["VEnd"]?.ToString() ?? "0",
                    vperiod = reader["VPeriod"]?.ToString() ?? "",
                    iname = reader["IName"]?.ToString()?.Trim() ?? ""  // ✅ Đúng tên alias
                });
            }

            return Ok(list);  // ✅ Trả về trực tiếp list (không cần {success: true})
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }

    [HttpPost("search")]
    public async Task<IActionResult> SearchByQR([FromBody] QRRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.QRCode))
        {
            return BadRequest(new { success = false, message = "Vui lòng nhập hoặc quét QR/Barcode" });
        }

        try
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var query = @"SELECT i.VICode, i.VEnd, dbo.fTCVNToUnicode(id.IName) as IName
                          FROM Inventory i
                          LEFT JOIN Itemdef id ON LTRIM(RTRIM(i.VICode)) = LTRIM(RTRIM(id.Icode))
                          WHERE LTRIM(RTRIM(i.VICode)) = @QRCode";

            using var command = new SqlCommand(query, connection);
            command.Parameters.AddWithValue("@QRCode", request.QRCode.Trim());

            using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                return Ok(new
                {
                    success = true,
                    data = new
                    {
                        ivcode = reader["VICode"]?.ToString()?.Trim() ?? "",
                        vend = reader["VEnd"]?.ToString() ?? "0",
                        iname = reader["iName"]?.ToString()?.Trim() ?? "Không có tên"  // ✅ Sửa Iname → IName
                    }
                });
            }
            else
            {
                return NotFound(new { success = false, message = "Không tìm thấy sản phẩm với QR/Barcode này" });
            }
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }
}

public class QRRequest
{
    public string QRCode { get; set; } = string.Empty;
}