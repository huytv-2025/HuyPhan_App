using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using HuyPhanApi.Services;
using HuyPhanApi.Models;
using System.Data.Common;  // Để dùng DbTransaction
using HuyPhanApi.Extensions;

namespace HuyPhanApi.Controllers
{
    [ApiController]
    [Route("api/asset-physical")]
    public class AssetPhysicalController : ControllerBase
    {
        private readonly string _connectionString;
        private readonly FcmService? _fcmService;

        public AssetPhysicalController(IConfiguration configuration, FcmService? fcmService = null)
        {
            _connectionString = configuration.GetConnectionString("Default")
                ?? throw new InvalidOperationException("Không tìm thấy connection string 'Default' trong configuration.");

            _fcmService = fcmService;
        }

            // GET: api/asset-physical/get
           [HttpGet("get")]
public async Task<IActionResult> GetAssetPhysical(
    [FromQuery] string? assetClassName = null,
    [FromQuery] string? locationCode = null)
{
    try
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var sql = @"
            SET NOCOUNT ON;
            SELECT 
                a.AssetClassCode,
                LTRIM(RTRIM(a.AssetClassName)) AS AssetClassName,
                LTRIM(RTRIM(a.DepartmentCode)) AS DepartmentCode,
                LTRIM(RTRIM(a.LocationCode)) AS LocationCode,
                dbo.fTCVNToUnicode(d.RVCName) AS LocationName, 
                ISNULL(a.SlvgQty, 0) AS SlvgQty,
                LTRIM(RTRIM(a.PhisLoc)) AS PhisLoc,
                LTRIM(RTRIM(a.PhisUser)) AS PhisUser
            FROM AssetItem a
            LEFT JOIN DefRVCList d ON a.LocationCode = d.RVCNo   -- ← Join bảng DeftRVC theo mã vị trí
            WHERE 1 = 1";

        if (!string.IsNullOrWhiteSpace(assetClassName))
            sql += " AND a.AssetClassName LIKE @AssetClassName";

        if (!string.IsNullOrWhiteSpace(locationCode))
            sql += " AND a.LocationCode = @LocationCode";

        sql += " ORDER BY a.AssetClassName, a.AssetClassCode";

        await using var command = new SqlCommand(sql, connection);

        if (!string.IsNullOrWhiteSpace(assetClassName))
            command.Parameters.AddWithValue("@AssetClassName", "%" + assetClassName.Trim() + "%");

        if (!string.IsNullOrWhiteSpace(locationCode))
            command.Parameters.AddWithValue("@LocationCode", locationCode.Trim());

        await using var reader = await command.ExecuteReaderAsync();

        var results = new List<Dictionary<string, object>>();

        while (await reader.ReadAsync())
        {
            results.Add(new Dictionary<string, object>
            {
                ["AssetClassCode"]  = reader.GetSafeString("AssetClassCode"),
                ["AssetClassName"]  = reader.GetSafeString("AssetClassName") ?? "Không tên",
                ["DepartmentCode"] = reader.GetSafeString("DepartmentCode"),
                ["LocationCode"]   = reader.GetSafeString("LocationCode"),
                ["LocationName"]   = reader.GetSafeString("LocationName") ?? "Không tên",  // ← Thêm trường này
                ["SlvgQty"]        = reader.GetSafeDecimal("SlvgQty"),
                ["PhisLoc"]        = reader.GetSafeString("PhisLoc"),
                ["PhisUser"]       = reader.GetSafeString("PhisUser")
            });
        }

        Console.WriteLine($"GetAssetPhysical trả về {results.Count} dòng");
        return Ok(results);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Lỗi GetAssetPhysical: {ex.Message}\n{ex.StackTrace}");
        return StatusCode(500, new { success = false, message = $"Lỗi server: {ex.Message}" });
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

            DbTransaction dbTransaction = await connection.BeginTransactionAsync();
            SqlTransaction? transaction = dbTransaction as SqlTransaction;

            try
            {
                int affectedRows = 0;

                const string sql = @"
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
                            AND ISNULL(LocationCode, '') = ISNULL(@LocationCode, '')
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
                Console.WriteLine($"Lỗi SaveAssetPhysical: {ex.Message}\n{ex.StackTrace}");
                return StatusCode(500, new { success = false, message = $"Lỗi server: {ex.Message}" });
            }
            finally
            {
                transaction?.Dispose();
            }
        }

        // POST: api/asset-physical/search
        [HttpPost("search")]
        public async Task<IActionResult> SearchAsset([FromBody] SearchAssetRequest request)
        {
            if (string.IsNullOrWhiteSpace(request?.AssetCode))
                return BadRequest(new { success = false, message = "Thiếu mã tài sản" });

            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                const string sql = @"
                    SELECT 
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

                var results = new List<object>();

                while (await reader.ReadAsync())
                {
                    results.Add(new
                    {
                        assetClassCode  = reader.GetSafeString("AssetClassCode"),
                        assetClassName  = reader.GetSafeString("AssetClassName") ?? "Không tên",
                        departmentCode  = reader.GetSafeString("DepartmentCode"),
                        locationCode    = reader.GetSafeString("LocationCode"),
                        slvgQty         = reader.GetSafeDecimal("SlvgQty"),
                        phisLoc         = reader.GetSafeString("PhisLoc"),
                        phisUser        = reader.GetSafeString("PhisUser"),
                        imagePath       = reader.GetSafeString("ImagePath")
                    });
                }

                if (results.Count == 0)
                    return Ok(new { success = false, message = "Không tìm thấy tài sản", data = new List<object>() });

                return Ok(new { success = true, data = results });
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
            const string sql = @"SELECT COUNT(*) FROM QRAssetPhisical WHERE CreatedDate > DATEADD(minute, -60, GETDATE())";
            await using var cmd = new SqlCommand(sql, conn);
            var count = await cmd.ExecuteScalarAsync();
            return Convert.ToInt32(count ?? 0);
        }

        // HÀM TẠO QR HÀNG LOẠT - Đã đặt đúng vị trí BÊN TRONG CLASS
        [HttpPost("generate-batch")]
        public async Task<IActionResult> GenerateBatchQR([FromBody] GenerateBatchRequest request)
        {
            if (request?.Codes == null || request.Codes.Count == 0)
                return BadRequest(new { success = false, message = "Danh sách mã tài sản rỗng" });

            try
            {
                await using var connection = new SqlConnection(_connectionString);
                await connection.OpenAsync();

                int insertedCount = 0;

                const string sql = @"
                    IF NOT EXISTS (SELECT 1 FROM QRAsset WHERE AssetClassCode = @AssetClassCode)
                    BEGIN
                        INSERT INTO QRAsset (
                            AssetClassCode, 
                            QRCode,
                            CreatedDate, 
                            CreatedBy,
                            ImagePath
                        )
                        VALUES (
                            @AssetClassCode,
                            @QRCode,
                            GETDATE(),
                            @CreatedBy,
                            NULL
                        );
                    END";

                foreach (var code in request.Codes)
                {
                    if (string.IsNullOrWhiteSpace(code)) continue;

                    await using var cmd = new SqlCommand(sql, connection);

                    cmd.Parameters.AddWithValue("@AssetClassCode", code.Trim());
                    cmd.Parameters.AddWithValue("@QRCode", $"HPAPP:{code.Trim()}");
                    cmd.Parameters.AddWithValue("@CreatedBy", request.CreatedBy ?? "MobileApp");

                    insertedCount += await cmd.ExecuteNonQueryAsync();
                }

                return Ok(new 
                { 
                    success = true, 
                    message = $"Đã tạo/cập nhật {insertedCount} QR code",
                    count = insertedCount 
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Lỗi GenerateBatchQR: {ex.Message}\n{ex.StackTrace}");
                return StatusCode(500, new { success = false, message = $"Lỗi server: {ex.Message}" });
            }
        }
    }

    // Extension methods để đọc an toàn
    internal static class SqlDataReaderExtensions
    {
        public static string GetSafeString(this SqlDataReader reader, string columnName)
        {
            int ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? "" : reader.GetString(ordinal).Trim();
        }

        public static decimal GetSafeDecimal(this SqlDataReader reader, string columnName)
        {
            int ordinal = reader.GetOrdinal(columnName);
            return reader.IsDBNull(ordinal) ? 0m : reader.GetDecimal(ordinal);
        }
    }

    // Các model (đặt ngoài class, trong namespace)
    public class SaveAssetPhysicalRequest
    {
        public List<AssetPhysicalItem> Items { get; set; } = new();
    }

    public class AssetPhysicalItem
    {
        public string AssetClassCode { get; set; } = string.Empty;
        public decimal Vend { get; set; }
        public decimal Vphis { get; set; }
        public string? LocationCode { get; set; }
        public string? DepartmentCode { get; set; }
        public string Vperiod { get; set; } = string.Empty;
        public string? CreatedBy { get; set; }
    }

    public class SearchAssetRequest
    {
        public string? AssetCode { get; set; }
    }

    public class GenerateBatchRequest
    {
        public List<string> Codes { get; set; } = new();
        public string? CreatedBy { get; set; }
    }
}