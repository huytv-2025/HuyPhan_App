using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace HuyPhanApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class RvcController : ControllerBase
    {
        private readonly string _connectionString =
            "Server=.;Database=SMILE_BO;User Id=Smile;Password=AnhMinh167TruongDinh;TrustServerCertificate=True;";

        // GET: api/rvc
        // hoặc api/rvcdeftlist nếu bạn muốn tên cũ
        [HttpGet]
        public async Task<IActionResult> Get()
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                const string query = @"
                    SELECT 
                        RVCNo, 
                        RVCName 
                    FROM DefRVCList 
                    ORDER BY RVCName";

                await using var command = new SqlCommand(query, connection);
                await using var reader = await command.ExecuteReaderAsync();

                var rvcList = new List<object>();

                while (await reader.ReadAsync())
                {
                    rvcList.Add(new
                    {
                        RVCno = reader["RVCNo"]?.ToString()?.Trim() ?? "",
                        RVCname = reader["RVCName"]?.ToString()?.Trim() ?? "Kho không tên"
                    });
                }

                return Ok(rvcList);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { 
                    success = false, 
                    message = "Lỗi khi lấy danh sách kho: " + ex.Message 
                });
            }
        }
    }
}