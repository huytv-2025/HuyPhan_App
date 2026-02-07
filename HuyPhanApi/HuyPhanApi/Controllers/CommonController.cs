using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Threading.Tasks;
using HuyPhanApi.Extensions; // nếu bạn có extension GetSafeString, etc.

namespace HuyPhanApi.Controllers
{
    [ApiController]
    [Route("api/common")]
    public class CommonController : ControllerBase
    {
        private readonly string _connectionString;

        public CommonController(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("Default")
                ?? throw new InvalidOperationException("Không tìm thấy connection string 'Default'.");
        }

        // Lấy kỳ kế toán gần nhất (GLPeriod)
        [HttpGet("latest-gl-period")]
        public async Task<IActionResult> GetLatestGLPeriod()
        {
            try
            {
                await using var conn = new SqlConnection(_connectionString);
                await conn.OpenAsync();

                const string sql = @"
                    SELECT TOP 1 ParaStr 
                    FROM GlobPara 
                    WHERE ParaName = 'GLPeriod'";

                await using var cmd = new SqlCommand(sql, conn);
                var result = await cmd.ExecuteScalarAsync();

                return Ok(new 
                { 
                    success = true, 
                    glPeriod = result?.ToString()?.Trim() ?? DateTime.Now.ToString("yyyyMM") 
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        // Lấy kỳ tồn kho gần nhất (INVPeriod)
        [HttpGet("latest-inv-period")]
        public async Task<IActionResult> GetLatestInvPeriod()
        {
            try
            {
                await using var conn = new SqlConnection(_connectionString);
                await conn.OpenAsync();

                const string sql = @"
                    SELECT TOP 1 ParaStr 
                    FROM GlobPara 
                    WHERE ParaName = 'INVPeriod'";

                await using var cmd = new SqlCommand(sql, conn);
                var result = await cmd.ExecuteScalarAsync();

                return Ok(new 
                { 
                    success = true, 
                    invPeriod = result?.ToString()?.Trim() ?? DateTime.Now.ToString("yyyyMM") 
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }
}