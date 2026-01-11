using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Data;

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
        await connection.OpenAsync();  // Bắt buộc: Mở connection trước khi transaction

        // Cast an toàn về SqlTransaction
        SqlTransaction? transaction = await connection.BeginTransactionAsync() as SqlTransaction;
        if (transaction == null)
        {
            throw new InvalidOperationException("Không thể bắt đầu transaction SQL.");
        }

        // Không dùng await using cho transaction ở đây, vì chúng ta cần commit/rollback thủ công
        try
        {
            const string sql = @"
                IF NOT EXISTS (
    SELECT 1 FROM QRInvPhisical 
    WHERE Ivcode = @Ivcode 
      AND RVC = @RVC 
      AND Vperiod = @Vperiod
      AND Vphis= @Vphis
)
BEGIN
    INSERT INTO QRInvPhisical 
    (
        Ivcode, Vend, Vphis, RVC, Vperiod,
        CreatedDate, CreatedBy, IsActive
    )
    VALUES 
    (
        @Ivcode, @Vend, @Vphis, @RVC, @Vperiod,
        GETDATE(), @CreatedBy, 1
    );
END
ELSE
BEGIN
    UPDATE QRInvPhisical
    SET Vphis = @Vphis,
        Vend = @Vend,
        CreatedDate = GETDATE(),
        CreatedBy = @CreatedBy
    WHERE Ivcode = @Ivcode 
      AND RVC = @RVC 
      AND Vperiod = @Vperiod
       AND Vphis= @Vphis;
END";

            int insertedCount = 0;

            foreach (var item in request.Items)
            {
                if (string.IsNullOrWhiteSpace(item.Ivcode) || 
                    string.IsNullOrWhiteSpace(item.RVC) || 
                    string.IsNullOrWhiteSpace(item.Vperiod))
                    continue;

                await using var cmd = new SqlCommand(sql, connection, transaction);  // transaction giờ đúng kiểu SqlTransaction
                cmd.Parameters.AddWithValue("@Ivcode", item.Ivcode.Trim());
                cmd.Parameters.Add(new SqlParameter("@Vend", SqlDbType.Decimal) { Value = item.Vend });

                cmd.Parameters.Add(new SqlParameter("@Vphis", SqlDbType.Decimal) { Value = item.Vphis });
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
        catch
        {
            await transaction.RollbackAsync();  // Rollback nếu có lỗi
            throw;  // Ném lại exception để catch ngoài xử lý
        }
        finally
        {
            transaction.Dispose();  // Dispose thủ công
        }
    }
    catch (Exception ex)
    {
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