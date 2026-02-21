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
    [FromQuery] string? locationCode = null,
    [FromQuery] string? departmentCode = null,
    [FromQuery] string? vperiod = null)  // ← Thêm param vperiod để filter kỳ chính xác
{
    try
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        // Xác định kỳ kiểm kê (ưu tiên query string, fallback GlobPara)
        string filterVPeriod;
        if (!string.IsNullOrWhiteSpace(vperiod))
        {
            filterVPeriod = vperiod.Trim();
        }
        else
        {
            const string getLatestSql = @"
                SELECT TOP 1 ParaStr 
                FROM GlobPara 
                WHERE ParaName = 'GLPeriod'";
            await using var cmdLatest = new SqlCommand(getLatestSql, connection);
            var latest = await cmdLatest.ExecuteScalarAsync();
            filterVPeriod = latest?.ToString()?.Trim() ?? DateTime.Now.ToString("yyyyMM");
        }

        var sql = @"
            SET NOCOUNT ON;

            WITH LatestPhis AS (
                SELECT 
                    AssetClassCode,
                    Vend,
                    Vphis,
                    LocationCode,
                    DepartmentCode,
                    CreatedDate,
                    CreatedBy,
                    ROW_NUMBER() OVER (PARTITION BY AssetClassCode, 
                                                     ISNULL(DepartmentCode, ''), 
                                                     ISNULL(LocationCode, '') 
                                       ORDER BY CreatedDate DESC) AS rn
                FROM QRAssetPhisical
                WHERE IsActive = 1 
                  AND Vperiod = @Vperiod
            )
            SELECT 
                a.AssetClassCode,
                a.AssetItemCode,
                dbo.fTCVNToUnicode(LTRIM(RTRIM(a.AssetClassName))) AS AssetClassName,
                LTRIM(RTRIM(a.DepartmentCode)) AS DepartmentCode,
                dbo.fTCVNToUnicode(dt.DepartmentName) AS DepartmentName,
                LTRIM(RTRIM(a.LocationCode)) AS LocationCode,
                dbo.fTCVNToUnicode(d.RVCName) AS LocationName,
                ISNULL(a.Quantity, 0) AS Quantity,
                LTRIM(RTRIM(a.PhisLoc)) AS PhisLoc,
                LTRIM(RTRIM(a.PhisUser)) AS PhisUser,
                ISNULL(l.Vphis, 0) AS Vphis,                -- ← Lấy Vphis từ kiểm kê mới nhất
                ISNULL(l.Vend, ISNULL(a.Quantity, 0)) AS Vend,
                l.CreatedDate,                              -- ← Lấy ngày kiểm kê
                l.CreatedBy
            FROM AssetItem a
            LEFT JOIN DefRVCList d ON a.LocationCode = d.RVCNo
            LEFT JOIN Department dt ON a.DepartmentCode = dt.DepartmentCode
            LEFT JOIN LatestPhis l 
                ON a.AssetClassCode = l.AssetClassCode
                AND ISNULL(a.DepartmentCode, '') = ISNULL(l.DepartmentCode, '')
                AND ISNULL(a.LocationCode, '') = ISNULL(l.LocationCode, '')
                AND l.rn = 1
            WHERE 1 = 1";

        if (!string.IsNullOrWhiteSpace(assetClassName))
            sql += " AND a.AssetClassName LIKE @AssetClassName";

        if (!string.IsNullOrWhiteSpace(locationCode))
            sql += " AND a.LocationCode = @LocationCode";

        if (!string.IsNullOrWhiteSpace(departmentCode))
            sql += " AND a.DepartmentCode = @DepartmentCode";

        sql += " ORDER BY a.AssetClassName, a.AssetClassCode";

        await using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@Vperiod", filterVPeriod);

        if (!string.IsNullOrWhiteSpace(assetClassName))
            command.Parameters.AddWithValue("@AssetClassName", "%" + assetClassName.Trim() + "%");

        if (!string.IsNullOrWhiteSpace(locationCode))
            command.Parameters.AddWithValue("@LocationCode", locationCode.Trim());

        if (!string.IsNullOrWhiteSpace(departmentCode))
            command.Parameters.AddWithValue("@DepartmentCode", departmentCode.Trim());

        await using var reader = await command.ExecuteReaderAsync();

        var results = new List<Dictionary<string, object>>();

        while (await reader.ReadAsync())
        {
            results.Add(new Dictionary<string, object>
            {
                ["AssetClassCode"]  = reader.GetSafeString("AssetClassCode"),
                ["AssetItemCode"]   = reader.GetSafeString("AssetItemCode"),
                ["AssetClassName"]  = reader.GetSafeString("AssetClassName") ?? "Không tên",
                ["DepartmentCode"]  = reader.GetSafeString("DepartmentCode"),
                ["DepartmentName"]  = reader.GetSafeString("DepartmentName") ?? "Chưa có",
                ["LocationCode"]    = reader.GetSafeString("LocationCode"),
                ["LocationName"]    = reader.GetSafeString("LocationName") ?? "Không tên",
                ["quantity"]        = reader.GetSafeDecimal("Quantity"),  // dùng key 'quantity' để khớp frontend
                ["PhisLoc"]         = reader.GetSafeString("PhisLoc"),
                ["PhisUser"]        = reader.GetSafeString("PhisUser"),
                ["Vphis"]           = reader.GetSafeDecimal("Vphis"),     // ← Thêm trường này
                ["Vend"]            = reader.GetSafeDecimal("Vend"),
                ["CreatedDate"]     = reader["CreatedDate"] is DateTime dt 
                    ? dt.ToString("yyyy-MM-dd HH:mm:ss") 
                    : "Chưa kiểm kê",                                 // ← Thêm ngày kiểm kê
                ["CreatedBy"]       = reader.GetSafeString("CreatedBy")
            });
        }

        Console.WriteLine($"GetAssetPhysical trả về {results.Count} dòng cho kỳ {filterVPeriod}");
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

        // Logic mới: kiểm tra trùng dựa trên AssetClassCode + Vperiod + DepartmentCode + LocationCode
        // KHÔNG dùng AssetItemCode nữa (vì đang NULL và không đáng tin cậy)
        const string sql = @"
            IF EXISTS (
                SELECT 1 FROM QRAssetPhisical 
                WHERE AssetClassCode = @AssetClassCode
                  AND Vperiod = @Vperiod
                  AND ISNULL(DepartmentCode, '') = ISNULL(@DepartmentCode, '')
                  AND ISNULL(LocationCode, '') = ISNULL(@LocationCode, '')
            )
            BEGIN
                UPDATE QRAssetPhisical
                SET 
                    Vend = @Vend,
                    Vphis = @Vphis,
                    LocationCode   = @LocationCode,
                    DepartmentCode = @DepartmentCode,
                    CreatedDate    = GETDATE(),
                    CreatedBy      = @CreatedBy,
                    IsActive       = 1
                WHERE 
                    AssetClassCode = @AssetClassCode
                    AND Vperiod = @Vperiod
                    AND ISNULL(DepartmentCode, '') = ISNULL(@DepartmentCode, '')
                    AND ISNULL(LocationCode, '') = ISNULL(@LocationCode, '')
            END
            ELSE
            BEGIN
                INSERT INTO QRAssetPhisical (
                    AssetClassCode, AssetItemCode, Vend, Vphis, LocationCode, DepartmentCode, 
                    Vperiod, CreatedDate, CreatedBy, IsActive
                )
                VALUES (
                    @AssetClassCode, NULL, @Vend, @Vphis, @LocationCode, @DepartmentCode,
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

            // AssetItemCode luôn lưu NULL (theo tình trạng hiện tại)
            // cmd.Parameters.AddWithValue("@AssetItemCode", item.AssetItemCode?.Trim() ?? (object)DBNull.Value); // không cần nữa

            affectedRows += await cmd.ExecuteNonQueryAsync();
        }

        await transaction.CommitAsync();

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
        await transaction.RollbackAsync();
        Console.WriteLine($"Lỗi SaveAssetPhysical: {ex.Message}\n{ex.StackTrace}");
        return StatusCode(500, new { success = false, message = $"Lỗi server: {ex.Message}" });
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
                        dbo.fTCVNToUnicode(LTRIM(RTRIM(a.AssetClassName))() AS AssetClassName,
                        dbo.fTCVNToUnicode(LTRIM(RTRIM(a.DepartmentCode))) AS DepartmentCode,
                        LTRIM(RTRIM(a.LocationCode)) AS LocationCode,
                        ISNULL(a.SlvgQty, 0) AS SlvgQty,
                        LTRIM(RTRIM(a.PhisLoc)) AS PhisLoc,
                        LTRIM(RTRIM(a.PhisUser)) AS PhisUser,
                        q.ImagePath
                    FROM AssetItem a
                    LEFT JOIN QRAsset q ON a.AssetClassCode = q.AssetClassCode and a.AssetItemCode=q.AssetItemCode
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
        return BadRequest(new { success = false, message = "Danh sách mã rỗng" });

    try
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        int created = 0;
        int updated = 0;
        var errors = new List<string>();

        const string sql = @"
            MERGE INTO QRAsset AS target
            USING (
                SELECT 
                    a.AssetClassCode,
                    a.AssetItemCode,
                    a.DepartmentCode,
                    a.LocationCode,
                    CONCAT('HPAPP:', a.AssetItemCode) AS QRCode,
                    GETDATE() AS CreatedDate,
                    @CreatedBy AS CreatedBy,
                    NULL AS ImagePath
                FROM AssetItem a
                WHERE a.AssetClassCode = @AssetClassCode
                  AND a.AssetItemCode IS NOT NULL
            ) AS source
            ON target.AssetItemCode = source.AssetItemCode

            WHEN MATCHED THEN
                UPDATE SET 
                    target.QRCode          = source.QRCode,
                    target.CreatedDate     = source.CreatedDate,
                    target.CreatedBy       = source.CreatedBy,
                    target.DepartmentCode  = source.DepartmentCode,
                    target.LocationCode    = source.LocationCode

            WHEN NOT MATCHED BY TARGET THEN
                INSERT (
                    AssetClassCode, AssetItemCode, DepartmentCode, LocationCode,
                    QRCode, CreatedDate, CreatedBy, ImagePath
                )
                VALUES (
                    source.AssetClassCode, source.AssetItemCode, source.DepartmentCode, source.LocationCode,
                    source.QRCode, source.CreatedDate, source.CreatedBy, source.ImagePath
                );

            SELECT 
                source.AssetItemCode,
                CASE WHEN EXISTS (SELECT 1 FROM QRAsset q WHERE q.AssetItemCode = source.AssetItemCode)
                     THEN 'updated' ELSE 'created' END AS Action
            FROM (
                SELECT @AssetClassCode AS AssetClassCode
            ) dummy
            CROSS APPLY (
                SELECT AssetItemCode FROM AssetItem WHERE AssetClassCode = @AssetClassCode
            ) source;
        ";

        foreach (var code in request.Codes.Distinct())
        {
            if (string.IsNullOrWhiteSpace(code)) continue;

            string assetClassCode = code.Trim();

            await using var cmd = new SqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("@AssetClassCode", assetClassCode);
            cmd.Parameters.AddWithValue("@CreatedBy", request.CreatedBy ?? "MobileApp");

            using var reader = await cmd.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                string action = reader["Action"]?.ToString() ?? "";
                if (action == "created") created++;
                else if (action == "updated") updated++;
            }

            // Nếu không có dòng nào đọc được → có thể class code không tồn tại hoặc không có item nào
            if (created + updated == 0)
            {
                await using var check = new SqlCommand(
                    "SELECT COUNT(*) FROM AssetItem WHERE AssetClassCode = @code", 
                    connection);
                check.Parameters.AddWithValue("@code", assetClassCode);
                int itemCount = Convert.ToInt32(await check.ExecuteScalarAsync());

                if (itemCount == 0)
                    errors.Add($"Mã lớp {assetClassCode} không tồn tại hoặc không có tài sản con");
                else
                    errors.Add($"Mã lớp {assetClassCode} có {itemCount} tài sản nhưng không tạo/cập nhật được QR");
            }
        }

        string message = $"Xử lý thành công {created + updated} mã QR. " +
                         (created > 0 ? $"Tạo mới: {created}. " : "") +
                         (updated > 0 ? $"Cập nhật: {updated}. " : "");

        if (errors.Count > 0)
            message += $"\nLỗi: {string.Join("; ", errors)}";

        return Ok(new
        {
            success = true,
            message,
            created,
            updated,
            failed = errors.Count,
            totalProcessed = created + updated
        });
    }
    catch (Exception ex)
    {
        return StatusCode(500, new { success = false, message = ex.Message });
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
        public string? AssetItemCode { get; set; }
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