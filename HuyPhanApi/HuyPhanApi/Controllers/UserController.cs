using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Threading.Tasks;

namespace HuyPhanApi.Controllers // ← thay bằng namespace thật của bạn nếu khác
{
    [ApiController]
    [Route("api/[controller]")]  // hoặc api/[controller] nếu bạn dùng convention
    public class UserController : ControllerBase
    {
        private readonly string _connectionString;

        public UserController(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("Default") 
                ?? throw new InvalidOperationException("Connection string 'Default' not found.");
        }

        [HttpPost("save-fcm-token")]
        public async Task<IActionResult> SaveFcmToken([FromBody] SaveTokenRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.ClerkID) || string.IsNullOrWhiteSpace(request.FcmToken))
            {
                return BadRequest(new { success = false, message = "ClerkID và FcmToken là bắt buộc" });
            }

            try
            {
                await using var conn = new SqlConnection(_connectionString);
                await conn.OpenAsync();

                const string sql = @"
                    MERGE INTO UserDevices AS target
                    USING (VALUES (@ClerkID, @FcmToken, GETDATE(), @DeviceType)) AS source (ClerkID, FcmToken, LastUpdated, DeviceType)
                    ON target.ClerkID = source.ClerkID
                    WHEN MATCHED THEN
                        UPDATE SET 
                            FcmToken = source.FcmToken,
                            LastUpdated = source.LastUpdated,
                            DeviceType = source.DeviceType  -- cập nhật luôn loại thiết bị nếu thay đổi
                    WHEN NOT MATCHED THEN
                        INSERT (ClerkID, FcmToken, LastUpdated, DeviceType)
                        VALUES (source.ClerkID, source.FcmToken, source.LastUpdated, source.DeviceType);";

                await using var cmd = new SqlCommand(sql, conn);
                cmd.Parameters.AddWithValue("@ClerkID", request.ClerkID.Trim());
                cmd.Parameters.AddWithValue("@FcmToken", request.FcmToken.Trim());
                cmd.Parameters.AddWithValue("@DeviceType", request.DeviceType ?? "mobile");  // mặc định nếu Flutter không gửi

                int rowsAffected = await cmd.ExecuteNonQueryAsync();

                return Ok(new 
                { 
                    success = true, 
                    message = $"Đã lưu/cập nhật FCM token cho ClerkID {request.ClerkID}",
                    rowsAffected 
                });
            }
            catch (SqlException ex)
            {
                // Log chi tiết hơn cho lỗi SQL
                return StatusCode(500, new 
                { 
                    success = false, 
                    message = "Lỗi cơ sở dữ liệu", 
                    detail = ex.Message,
                    number = ex.Number  // ví dụ: 2627 = duplicate key, rất hữu ích khi debug
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new 
                { 
                    success = false, 
                    message = "Lỗi server nội bộ", 
                    detail = ex.Message 
                });
            }
        }
    }

    // Model request – nên đặt trong folder Models hoặc ngay trong controller cũng được
    public class SaveTokenRequest
    {
        public string ClerkID { get; set; } = string.Empty;
        public string FcmToken { get; set; } = string.Empty;
        public string? DeviceType { get; set; }  // "android", "ios", "mobile"...
    }
}