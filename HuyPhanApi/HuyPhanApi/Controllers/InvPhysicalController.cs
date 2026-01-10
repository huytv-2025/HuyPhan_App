using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace HuyPhanApi.Controllers
{
    [ApiController]
    [Route("api/invphysical")]
    public class InvPhysicalController : ControllerBase
    {
        private readonly string _connectionString =
            "Server=.;Database=SMILE_BO;User Id=Smile;Password=AnhMinh167TruongDinh;TrustServerCertificate=True;";

        [HttpPost("save")]
        public async Task<IActionResult> SavePhysicalInventory([FromBody] SavePhysicalRequest request)
        {
            if (request == null)
    {
        return BadRequest(new { success = false, message = "Không thể parse body JSON. Kiểm tra format hoặc tên property." });
    }

    if (request.Items == null || request.Items.Count == 0)
    {
        return BadRequest(new { success = false, message = "Danh sách mục kiểm kê rỗng" });
    }

            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                var dbTx = await connection.BeginTransactionAsync();
                await using SqlTransaction transaction = (SqlTransaction)dbTx;

                const string sql = @"
                    IF NOT EXISTS (
                        SELECT 1 FROM QRInvPhisical 
                        WHERE Ivcode = @Ivcode AND RVC = @RVC AND Vperiod = @Vperiod
                    )
                    BEGIN
                        INSERT INTO QRInvPhisical 
                        (
                            Ivcode, 
                            Vend,      
                            Vphis,     
                            RVC, 
                            Vperiod,
                            CreatedDate, 
                            CreatedBy,
                            IsActive
                        )
                        VALUES 
                        (
                            @Ivcode, 
                            @Vend, 
                            ISNULL(@Vphis, @Vend),   -- nếu không gửi Vphis thì dùng Vend
                            @RVC, 
                            @Vperiod,
                            GETDATE(), 
                            @CreatedBy,
                            1
                        )
                    END";

                int insertedCount = 0;

                foreach (var item in request.Items)
                {
                    if (string.IsNullOrWhiteSpace(item.Ivcode) || 
                        string.IsNullOrWhiteSpace(item.RVC) || 
                        string.IsNullOrWhiteSpace(item.Vperiod))
                        continue;

                    await using var cmd = new SqlCommand(sql, connection, transaction); // ← transaction giờ đúng kiểu
                    cmd.Parameters.AddWithValue("@Ivcode", item.Ivcode.Trim());
                    cmd.Parameters.AddWithValue("@Vend", item.Vend);
                    cmd.Parameters.AddWithValue("@Vphis", item.Vphis);
                    cmd.Parameters.AddWithValue("@RVC", item.RVC.Trim());
                    cmd.Parameters.AddWithValue("@Vperiod", item.Vperiod.Trim());
                    cmd.Parameters.AddWithValue("@CreatedBy", item.CreatedBy ?? "MobileApp");

                    await cmd.ExecuteNonQueryAsync();
                    insertedCount++;
                }

                await transaction.CommitAsync();

                return Ok(new 
                { 
                    success = true, 
                    message = $"Đã lưu thành công {insertedCount} dòng kiểm kê vật lý",
                    count = insertedCount 
                });
            }
            catch (Exception ex)
            {
                // Nên rollback trong catch nếu transaction còn sống (tránh lỗi "zombie transaction")
                // Nhưng vì dùng await using → transaction tự động dispose (rollback nếu chưa commit)
                return StatusCode(500, new 
                { 
                    success = false, 
                    message = $"Lỗi server: {ex.Message}" 
                });
            }
        }
    }

    // Model không cần sửa
    public class SavePhysicalRequest
    {
        public List<PhysicalItem> Items { get; set; } = new();
    }

    public class PhysicalItem
            {
                public string Ivcode     { get; set; } = string.Empty;
                public int    Vend       { get; set; }
                public int?   Vphis      { get; set; }   // ← nullable
                public string RVC        { get; set; } = string.Empty;
                public string Vperiod    { get; set; } = string.Empty;
                public string? CreatedBy { get; set; }
            }
}