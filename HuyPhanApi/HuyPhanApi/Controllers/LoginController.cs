using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace HuyPhanApi.Controllers;

[ApiController]
[Route("api/login")]
public class LoginController : ControllerBase
{
    private readonly string _connectionString = 
        "Server=.;Database=SMILE_BO;User Id=Smile;Password=AnhMinh167TruongDinh;TrustServerCertificate=True;";

    [HttpPost]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        // Kiểm tra nhập đầy đủ – dùng đúng tên property SecurityCode
        if (string.IsNullOrWhiteSpace(request.ClerkID) || string.IsNullOrWhiteSpace(request.SecurityCode))
        {
            return BadRequest(new { success = false, message = "Vui lòng nhập đầy đủ ClerkID và Security Code" });
        }

        try
        {
            using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            // Query đúng tên cột trong bảng: SecurityCode (có chữ 'r')
            var query = "SELECT COUNT(1) FROM Clerk WHERE ClerkID = @ClerkID AND SecurityCode = @SecurityCode";

            using var command = new SqlCommand(query, connection);
            command.Parameters.AddWithValue("@ClerkID", request.ClerkID.Trim());
            command.Parameters.AddWithValue("@SecurityCode", request.SecurityCode); // Đúng tên

            var count = (int)await command.ExecuteScalarAsync();

            if (count > 0)
            {
                return Ok(new { success = true, message = "Đăng nhập thành công!" });
            }
            else
            {
                return Unauthorized(new { success = false, message = "Sai ClerkID hoặc Security Code" });
            }
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi kết nối database: " + ex.Message });
        }
    }
}

// Class nhận JSON – tên property khớp đúng với DB và query
public class LoginRequest
{
    public string ClerkID { get; set; } = string.Empty;
    public string SecurityCode { get; set; } = string.Empty; // Có chữ 'r' như trong bảng Clerk
}