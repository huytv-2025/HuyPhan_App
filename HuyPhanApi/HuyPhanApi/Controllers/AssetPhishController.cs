using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using HuyPhanApi.Services;
using HuyPhanApi.Models;
using System.Data.Common;
using HuyPhanApi.Extensions;

namespace HuyPhanApi.Controllers
{
    [ApiController]
    [Route("api/asset-phish")]
    public class AssetPhishController : ControllerBase
    {
        private readonly string _connectionString;
        private readonly FcmService? _fcmService;

        public AssetPhishController(
            IConfiguration configuration,
            FcmService? fcmService = null)
        {
            _connectionString = configuration.GetConnectionString("Default")
                ?? throw new InvalidOperationException("Không tìm thấy connection string 'Default'.");

            _fcmService = fcmService;
        }

        // CHỈ GIỮ MỘT ACTION NÀY - XÓA HẾT PHẦN LẶP LẠI
        [HttpGet("get")]
        public async Task<IActionResult> GetAssetPhysical(
            [FromQuery] string? vperiod = null,
            [FromQuery] string? locationCode = null,
            [FromQuery] string? departmentCode = null,
            [FromQuery] string? assetClassName = null)
        {
            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                string filterVPeriod;
if (string.IsNullOrWhiteSpace(vperiod))
{
    const string getLatestSql = @"
        SELECT TOP 1 ParaStr 
        FROM GlobPara 
        WHERE ParaName = 'GLPeriod'";

    await using var cmdLatest = new SqlCommand(getLatestSql, connection);
    var latest = await cmdLatest.ExecuteScalarAsync();
    filterVPeriod = latest?.ToString()?.Trim() ?? DateTime.Now.ToString("yyyyMM");
}
else
{
    filterVPeriod = vperiod.Trim();
}

                var sql = @"
                    SET NOCOUNT ON;

                    WITH LatestPhis AS (
                        SELECT 
                            AssetClassCode,
                            AssetItemCode,
                            Vphis,
                            Vend,
                            Vperiod,
                            LocationCode,
                            DepartmentCode,
                            CreatedDate,
                            CreatedBy,
                            ROW_NUMBER() OVER (PARTITION BY AssetClassCode, AssetItemCode ORDER BY CreatedDate DESC) AS rn
                        FROM QRAssetPhisical
                        WHERE IsActive = 1 AND Vperiod = @Vperiod
                    )
                    SELECT 
                        a.AssetClassCode,
                        a.AssetItemCode,
                        LTRIM(RTRIM(a.AssetClassName)) AS AssetClassName,
                        LTRIM(RTRIM(a.DepartmentCode)) AS DepartmentCode,
                        LTRIM(RTRIM(a.LocationCode)) AS LocationCode,
                        ISNULL(a.SlvgQty, 0) AS SlvgQty,
                        LTRIM(RTRIM(a.PhisLoc)) AS PhisLoc,
                        LTRIM(RTRIM(a.PhisUser)) AS PhisUser,
                        ISNULL(l.Vphis, 0) AS Vphis,
                        ISNULL(l.Vend, ISNULL(a.SlvgQty, 0)) AS Vend,
                        @Vperiod AS Vperiod,
                        l.CreatedDate,
                        l.CreatedBy,
                        LTRIM(RTRIM(d.DepartmentName)) AS DepartmentName
                    FROM AssetItem a
                    LEFT JOIN LatestPhis l 
                        ON a.AssetClassCode = l.AssetClassCode 
                        AND a.AssetItemCode = l.AssetItemCode
                        AND l.rn = 1
                    LEFT JOIN Department d ON a.DepartmentCode = d.DepartmentCode
                    WHERE 1 = 1";

                if (!string.IsNullOrWhiteSpace(locationCode))
                    sql += " AND a.LocationCode = @LocationCode";

                if (!string.IsNullOrWhiteSpace(departmentCode))
                    sql += " AND a.DepartmentCode = @DepartmentCode";

                if (!string.IsNullOrWhiteSpace(assetClassName))
                    sql += " AND a.AssetClassCode LIKE '%' + @AssetClassName + '%'";

                sql += " ORDER BY a.AssetClassName, a.AssetClassCode";

                await using var command = new SqlCommand(sql, connection);
                command.Parameters.AddWithValue("@Vperiod", filterVPeriod);

                if (!string.IsNullOrWhiteSpace(locationCode))
                    command.Parameters.AddWithValue("@LocationCode", locationCode.Trim());

                if (!string.IsNullOrWhiteSpace(departmentCode))
                    command.Parameters.AddWithValue("@DepartmentCode", departmentCode.Trim());

                if (!string.IsNullOrWhiteSpace(assetClassName))
                    command.Parameters.AddWithValue("@AssetClassName", assetClassName.Trim());

                await using var reader = await command.ExecuteReaderAsync();

                var results = new List<Dictionary<string, object>>();

                while (await reader.ReadAsync())
                {
                    results.Add(new Dictionary<string, object>
                    {
                        ["AssetClassCode"] = reader.GetSafeString("AssetClassCode") ?? "",
                        ["AssetItemCode"] = reader.GetSafeString("AssetItemCode") ?? "",
                        ["AssetClassName"] = reader.GetSafeString("AssetClassName") ?? "Không tên",
                        ["DepartmentCode"] = reader.GetSafeString("DepartmentCode") ?? "",
                        ["LocationCode"] = reader.GetSafeString("LocationCode") ?? "",
                        ["SlvgQty"] = reader.GetSafeDecimal("SlvgQty"),
                        ["PhisLoc"] = reader.GetSafeString("PhisLoc") ?? "",
                        ["PhisUser"] = reader.GetSafeString("PhisUser") ?? "Chưa có",
                        ["Vphis"] = reader.GetSafeDecimal("Vphis"),
                        ["Vend"] = reader.GetSafeDecimal("Vend"),
                        ["Vperiod"] = reader.GetSafeString("Vperiod") ?? filterVPeriod,
                        ["CreatedDate"] = reader["CreatedDate"] is DateTime dt 
                            ? dt.ToString("dd/MM/yyyy HH:mm:ss") 
                            : "Chưa kiểm kê",
                        ["CreatedBy"] = reader.GetSafeString("CreatedBy") ?? ""
                    });
                }

                return Ok(results);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Lỗi GetAssetPhysical: {ex.Message}\nStackTrace: {ex.StackTrace}");
                return StatusCode(500, new { success = false, message = $"Lỗi server: {ex.Message}" });
            }
        }

        // Giữ nguyên phần [HttpPost("save")] và [HttpPost("search")] như cũ

        [HttpGet("latest-period")]
        public async Task<IActionResult> GetLatestPeriod()
        {
            try
            {
                await using var conn = new SqlConnection(_connectionString);
                await conn.OpenAsync();

                var glCmd = new SqlCommand("SELECT TOP 1 GLPeriod FROM GlobPara ORDER BY GLPeriod DESC", conn);
                var glPeriod = (await glCmd.ExecuteScalarAsync())?.ToString()?.Trim() ?? DateTime.Now.ToString("yyyyMM");

                return Ok(new { glPeriod });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }

        private async Task<int> CalculateBadgeCount()
        {
            await using var conn = new SqlConnection(_connectionString);
            await conn.OpenAsync();
            const string sql = @"
                SET NOCOUNT ON;
                SELECT COUNT(*) FROM QRAssetPhisical 
                WHERE CreatedDate > DATEADD(minute, -60, GETDATE())";
            await using var cmd = new SqlCommand(sql, conn);
            var count = await cmd.ExecuteScalarAsync();
            return Convert.ToInt32(count ?? 0);
        }
    }
}