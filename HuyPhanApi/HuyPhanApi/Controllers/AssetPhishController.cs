using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using HuyPhanApi.Services;
using HuyPhanApi.Models;
using System.Data.Common;  // ← THÊM DÒNG NÀY để dùng DbTransaction
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
                ?? throw new InvalidOperationException("Không tìm thấy connection string 'Default' trong configuration.");

            _fcmService = fcmService;
        }

        // GET: api/asset-physical/get
        [HttpGet("get")]
public async Task<IActionResult> GetAssetPhysical(
    [FromQuery] string? vperiod = "DEFAULT",
    [FromQuery] string? locationCode = null,
    [FromQuery] string? departmentCode = null, // Thêm nếu cần lọc phòng ban
    [FromQuery] string? assetClassName = null) // Thêm nếu cần lọc mã tài sản
{
    try
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var sql = @"
            SET NOCOUNT ON;
            WITH LatestPhis AS (
                SELECT 
                    AssetClassCode,
                    Vphis,
                    Vend,
                    Vperiod,
                    LocationCode,
                    DepartmentCode,
                    CreatedDate,
                    CreatedBy,
                    ROW_NUMBER() OVER (PARTITION BY AssetClassCode ORDER BY CreatedDate DESC) AS rn
                FROM QRAssetPhisical
                WHERE IsActive = 1 
                 
            )
            SELECT 
                a.AssetClassCode,
                LTRIM(RTRIM(a.AssetClassName)) AS AssetClassName,
                LTRIM(RTRIM(a.DepartmentCode)) AS DepartmentCode,
                LTRIM(RTRIM(a.LocationCode)) AS LocationCode,
                ISNULL(a.SlvgQty, 0) AS SlvgQty,
                LTRIM(RTRIM(a.PhisLoc)) AS PhisLoc,
                LTRIM(RTRIM(a.PhisUser)) AS PhisUser,
                ISNULL(l.Vphis, 0) AS Vphis,
                ISNULL(l.Vend, ISNULL(a.SlvgQty, 0)) AS Vend,
                ISNULL(l.Vperiod, @Vperiod) AS Vperiod,
                l.CreatedDate,
                l.CreatedBy
            FROM AssetItem a
            LEFT JOIN LatestPhis l 
                ON a.AssetClassCode = l.AssetClassCode 
                AND l.rn = 1  -- Chỉ lấy bản ghi mới nhất
            WHERE 1 = 1";

        if (!string.IsNullOrWhiteSpace(locationCode))
            sql += " AND a.LocationCode = @LocationCode";

        if (!string.IsNullOrWhiteSpace(departmentCode))
            sql += " AND a.DepartmentCode = @DepartmentCode";

        if (!string.IsNullOrWhiteSpace(assetClassName))
            sql += " AND a.AssetClassCode LIKE '%' + @AssetClassName + '%'";

        sql += " ORDER BY a.AssetClassName, a.AssetClassCode";

        await using var command = new SqlCommand(sql, connection);

        command.Parameters.AddWithValue("@Vperiod", vperiod?.Trim() ?? "DEFAULT");

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
                ["AssetClassCode"]   = reader.GetSafeString("AssetClassCode") ?? "",
                ["AssetClassName"]   = reader.GetSafeString("AssetClassName") ?? "Không tên",
                ["DepartmentCode"]   = reader.GetSafeString("DepartmentCode") ?? "",
                ["LocationCode"]     = reader.GetSafeString("LocationCode") ?? "",
                ["SlvgQty"]          = reader.GetSafeDecimal("SlvgQty"),
                ["PhisLoc"]          = reader.GetSafeString("PhisLoc") ?? "",
                ["PhisUser"]         = reader.GetSafeString("PhisUser") ?? "Chưa có",
                ["Vphis"]            = reader.GetSafeDecimal("Vphis"),
                ["Vend"]             = reader.GetSafeDecimal("Vend"),
                ["Vperiod"]          = reader.GetSafeString("Vperiod") ?? vperiod,
                ["CreatedDate"]      = reader["CreatedDate"] is DateTime dt 
                    ? dt.ToString("dd/MM/yyyy HH:mm:ss") 
                    : "Chưa kiểm kê",
                ["CreatedBy"]        = reader.GetSafeString("CreatedBy") ?? ""
            });
        }

        return Ok(results);
    }
    catch (Exception ex)
    {
        return StatusCode(500, new { success = false, message = $"Lỗi: {ex.Message}" });
    }
}
        // POST: api/asset-physical/save
        [HttpPost("save")]
        public async Task<IActionResult> SaveAssetPhysical([FromBody] SaveAssetPhysicalRequest request)
        {
            if (request?.Items == null || request.Items.Count == 0)
                return BadRequest(new { success = false, message = "Dữ liệu không hợp lệ hoặc trống" });

            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            // Sửa lỗi CS0246 & CS1503: dùng DbTransaction rồi cast
            DbTransaction dbTransaction = await connection.BeginTransactionAsync();
            SqlTransaction? transaction = dbTransaction as SqlTransaction;

            try
            {
                int affectedRows = 0;

                const string sql = @"
                    SET NOCOUNT ON;
                    IF EXISTS (
                        SELECT 1 FROM QRAssetPhisical 
                        WHERE AssetClassCode = @AssetClassCode 
                          AND Vperiod = @Vperiod 
                          AND ISNULL(LocationCode, '') = ISNULL(@LocationCode, '')
                    )
                    BEGIN
                        UPDATE QRAssetPhisical
                        SET 
                            Vend = @Vend,
                            Vphis = @Vphis,
                            DepartmentCode = @DepartmentCode,
                            CreatedDate = GETDATE(),
                            CreatedBy = @CreatedBy,
                            IsActive = 1
                        WHERE 
                            AssetClassCode = @AssetClassCode 
                            AND Vperiod = @Vperiod 
                            AND ISNULL(LocationCode, '') = ISNULL(@LocationCode, '');
                    END
                    ELSE
                    BEGIN
                        INSERT INTO QRAssetPhisical (
                            AssetClassCode, Vend, Vphis, LocationCode, DepartmentCode, 
                            Vperiod, CreatedDate, CreatedBy, IsActive
                        )
                        VALUES (
                            @AssetClassCode, @Vend, @Vphis, @LocationCode, @DepartmentCode,
                            @Vperiod, GETDATE(), @CreatedBy, 1
                        );
                    END";

                foreach (var item in request.Items)
                {
                    if (string.IsNullOrWhiteSpace(item.AssetClassCode) || string.IsNullOrWhiteSpace(item.Vperiod))
                        continue;

                    await using var cmd = new SqlCommand(sql, connection, transaction);

                    cmd.Parameters.AddWithValue("@AssetClassCode", item.AssetClassCode.Trim());
                    cmd.Parameters.AddWithValue("@Vend", item.Vend);
                    cmd.Parameters.AddWithValue("@Vphis", item.Vphis);
                    cmd.Parameters.AddWithValue("@LocationCode", item.LocationCode?.Trim() ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@DepartmentCode", item.DepartmentCode?.Trim() ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@Vperiod", item.Vperiod.Trim());
                    cmd.Parameters.AddWithValue("@CreatedBy", item.CreatedBy ?? "MobileApp");

                    affectedRows += await cmd.ExecuteNonQueryAsync();
                }

                transaction?.Commit();

                if (_fcmService != null)
                {
                    int badgeCount = await CalculateBadgeCount();
                    if (badgeCount > 0)
                        await _fcmService.SendSilentBadgeUpdate(badgeCount);
                }

                return Ok(new 
                { 
                    success = true, 
                    message = $"Đã lưu/cập nhật {affectedRows} dòng kiểm kê tài sản",
                    count = affectedRows 
                });
            }
            catch (Exception ex)
            {
                transaction?.Rollback();
                return StatusCode(500, new { success = false, message = $"Lỗi server: {ex.Message}" });
            }
            finally
            {
                transaction?.Dispose();
            }
        }

        // POST: api/asset-physical/search
        [HttpPost("search")]
        public async Task<IActionResult> SearchAssetByQr([FromBody] SearchAssetRequest request)
        {
            if (string.IsNullOrWhiteSpace(request?.AssetCode))
                return BadRequest(new { success = false, message = "Thiếu mã tài sản (AssetClassCode)" });

            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                const string sql = @"
                    SET NOCOUNT ON;
                    SELECT TOP 1
                        a.AssetClassCode,
                        LTRIM(RTRIM(a.AssetClassName)) AS AssetClassName,
                        LTRIM(RTRIM(a.DepartmentCode)) AS DepartmentCode,
                        LTRIM(RTRIM(a.LocationCode)) AS LocationCode,
                        ISNULL(a.SlvgQty, 0) AS SlvgQty,
                        LTRIM(RTRIM(a.PhisLoc)) AS PhisLoc,
                        LTRIM(RTRIM(a.PhisUser)) AS PhisUser,
                        q.ImagePath
                    FROM AssetItem a
                    LEFT JOIN QRAsset q ON a.AssetClassCode = q.AssetClassCode
                    WHERE a.AssetClassCode = @AssetClassCode";

                await using var cmd = new SqlCommand(sql, connection);
                cmd.Parameters.AddWithValue("@AssetClassCode", request.AssetCode.Trim());

                await using var reader = await cmd.ExecuteReaderAsync();

                if (await reader.ReadAsync())
                {
                    var result = new
                    {
                        // Sửa lỗi CS0746 & CS0131: Dùng cú pháp đúng cho anonymous type (key = value, KHÔNG dùng ["key"] = )
                        assetClassCode  = reader.GetSafeString("AssetClassCode"),
                        assetClassName  = reader.GetSafeString("AssetClassName") ?? "Không tên",
                        departmentCode  = reader.GetSafeString("DepartmentCode"),
                        locationCode    = reader.GetSafeString("LocationCode"),
                        slvgQty         = reader.GetSafeDecimal("SlvgQty"),
                        phisLoc         = reader.GetSafeString("PhisLoc"),
                        phisUser        = reader.GetSafeString("PhisUser"),
                        imagePath       = reader.GetSafeString("ImagePath")
                    };

                    return Ok(new { success = true, data = result });
                }

                return Ok(new { success = false, message = "Không tìm thấy tài sản", data = (object)null! });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = $"Lỗi tìm kiếm: {ex.Message}" });
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
