using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace HuyPhanApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class InventoryController : ControllerBase
{
    private readonly string _connectionString =
        "Server=.;Database=SMILE_BO;User Id=Smile;Password=AnhMinh167TruongDinh;TrustServerCertificate=True;";

    // GET: api/inventory?vperiod=...&search=...
    [HttpGet("")]
    public async Task<IActionResult> Get([FromQuery] string? vperiod, [FromQuery] string? search)
    {
        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var sql = @"
                -- 1. Vật tư tồn kho (Inventory)
                SELECT 
                    i.VICode AS code,
                    dbo.fTCVNToUnicode(id.IName) AS name,
                    ISNULL(u.UnitName, 'Cái') AS unit,
                    i.VEnd AS quantity,
                    i.VPeriod AS period,
                    i.RVC AS locationCode,
                    dbo.fTCVNToUnicode(de.RVCName) AS locationName,
                    q.ImagePath,
                    'Inventory' AS itemType,
                    q.QRCode  -- Để lấy QR nếu cần
                FROM Inventory i
                LEFT JOIN Itemdef id ON LTRIM(RTRIM(i.VICode)) = LTRIM(RTRIM(id.Icode))
                LEFT JOIN IUnitDef u ON id.IUnit = u.UnitCode
                LEFT JOIN QRInventory q ON LTRIM(RTRIM(i.VICode)) = q.Ivcode
                LEFT JOIN DefRVCList de ON de.RVCNo = i.RVC
                WHERE 1=1 {0}

                UNION ALL

                -- 2. Tài sản cố định (AssetItem)
                SELECT 
                    A.AssetClassCode AS code,
                    dbo.fTCVNToUnicode(COALESCE(f.IName, A.AssetClassName)) AS name,
                    dbo.fTCVNToUnicode(ISNULL(u.UnitName, 'Cái')) AS unit,
                    A.SlvgQty AS quantity,
                    A.StartPeriod AS period,
                    A.DepartmentCode AS locationCode,
                    dbo.fTCVNToUnicode(d.DepartmentName) AS locationName,
                    q.ImagePath,
                    'Asset' AS itemType,
                    q.QRCode
                FROM AssetItem A
                LEFT JOIN Department d ON d.DepartmentCode = A.DepartmentCode
                LEFT JOIN ItemDef f ON f.ICode = A.AssetClassCode
                LEFT JOIN IUnitDef u ON u.UnitCode = f.IUnit
                LEFT JOIN QRInventory q ON LTRIM(RTRIM(A.AssetClassCode)) = q.Ivcode
                WHERE 1=1 {1}

                ORDER BY code";

            string inventoryFilter = "";
            string assetFilter = "";

            if (!string.IsNullOrEmpty(vperiod))
            {
                inventoryFilter += " AND i.VPeriod = @VPeriod";
                assetFilter += " AND A.StartPeriod = @VPeriod";
            }

            if (!string.IsNullOrEmpty(search))
            {
                string searchPattern = $"%{search}%";
                inventoryFilter += @" AND (i.VICode LIKE @Search OR dbo.fTCVNToUnicode(id.IName) LIKE @Search)";
                assetFilter += @" AND (A.AssetClassCode LIKE @Search 
                                      OR dbo.fTCVNToUnicode(COALESCE(f.IName, A.AssetClassName)) LIKE @Search)";
            }

            sql = string.Format(sql, inventoryFilter, assetFilter);

            await using var command = new SqlCommand(sql, connection);

            if (!string.IsNullOrEmpty(vperiod))
                command.Parameters.AddWithValue("@VPeriod", vperiod);

            if (!string.IsNullOrEmpty(search))
                command.Parameters.AddWithValue("@Search", $"%{search}%");

            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<object>();
            while (await reader.ReadAsync())
            {
                string itemType = reader["itemType"]?.ToString() ?? "Inventory";
                string prefix = itemType == "Asset" ? "HPASSET:" : "HPAPP:";

                list.Add(new
                {
                    code = reader["code"]?.ToString()?.Trim() ?? "",
                    name = reader["name"]?.ToString()?.Trim() ?? "",
                    unit = reader["unit"]?.ToString()?.Trim() ?? "Cái",
                    quantity = ((decimal)reader["quantity"]).ToString(System.Globalization.CultureInfo.InvariantCulture),
                    period = reader["period"]?.ToString() ?? "",
                    locationCode = reader["locationCode"]?.ToString()?.Trim() ?? "",
                    locationName = reader["locationName"]?.ToString()?.Trim() ?? "",
                    imagePath = reader["ImagePath"]?.ToString()?.Trim() ?? "",
                    itemType,  // Inventory hoặc Asset
                    qrCode = reader["QRCode"]?.ToString()?.Trim() ?? $"{prefix}{reader["code"]}"
                });
            }

            return Ok(list);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }

    // POST: api/inventory/search (Quét QR - hỗ trợ cả vật tư và tài sản)
    [HttpPost("search")]
    public async Task<IActionResult> SearchByQR([FromBody] QRRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.QRCode))
            return BadRequest(new { success = false, message = "Vui lòng quét QR" });

        string qrInput = request.QRCode.Trim();

        // Xử lý tiền tố
        bool isAsset = qrInput.StartsWith("HPASSET:", StringComparison.OrdinalIgnoreCase);
        bool isInventory = qrInput.StartsWith("HPAPP:", StringComparison.OrdinalIgnoreCase);

        string code = qrInput;
        if (isAsset) code = qrInput.Substring(8);
        else if (isInventory) code = qrInput.Substring(6);

        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            string query = isAsset ? @"
                -- Tìm tài sản
                SELECT 
                    A.AssetClassCode AS code,
                    dbo.fTCVNToUnicode(COALESCE(f.IName, A.AssetClassName)) AS name,
                    dbo.fTCVNToUnicode(ISNULL(u.UnitName, 'Cái')) AS unit,
                    A.SlvgQty AS quantity,
                    A.StartPeriod AS period,
                    A.DepartmentCode AS locationCode,
                    dbo.fTCVNToUnicode(d.DepartmentName) AS locationName,
                    q.ImagePath,
                    'Asset' AS itemType
                FROM AssetItem A
                LEFT JOIN Department d ON d.DepartmentCode = A.DepartmentCode
                LEFT JOIN ItemDef f ON f.ICode = A.AssetClassCode
                LEFT JOIN IUnitDef u ON u.UnitCode = f.IUnit
                LEFT JOIN QRInventory q ON LTRIM(RTRIM(A.AssetClassCode)) = q.Ivcode
                WHERE LTRIM(RTRIM(A.AssetClassCode)) = @Code"

                : @"
                -- Tìm vật tư
                SELECT 
                    i.VICode AS code,
                    dbo.fTCVNToUnicode(id.IName) AS name,
                    ISNULL(u.UnitName, 'Cái') AS unit,
                    i.VEnd AS quantity,
                    i.VPeriod AS period,
                    i.RVC AS locationCode,
                    dbo.fTCVNToUnicode(de.RVCName) AS locationName,
                    q.ImagePath,
                    'Inventory' AS itemType
                FROM Inventory i
                LEFT JOIN Itemdef id ON LTRIM(RTRIM(i.VICode)) = LTRIM(RTRIM(id.Icode))
                LEFT JOIN IUnitDef u ON id.IUnit = u.UnitCode
                LEFT JOIN DefRVCList de ON de.RVCNo = i.RVC
                LEFT JOIN QRInventory q ON LTRIM(RTRIM(i.VICode)) = q.Ivcode
                WHERE LTRIM(RTRIM(i.VICode)) = @Code";

            await using var command = new SqlCommand(query, connection);
            command.Parameters.AddWithValue("@Code", code.Trim());

            await using var reader = await command.ExecuteReaderAsync();

            var results = new List<object>();
            while (await reader.ReadAsync())
            {
                string itemType = reader["itemType"]?.ToString() ?? "Inventory";
                string prefix = itemType == "Asset" ? "HPASSET:" : "HPAPP:";

                results.Add(new
                {
                    code = reader["code"]?.ToString()?.Trim() ?? "",
                    name = reader["name"]?.ToString()?.Trim() ?? "",
                    unit = reader["unit"]?.ToString()?.Trim() ?? "Cái",
                    quantity = ((decimal)reader["quantity"]).ToString(System.Globalization.CultureInfo.InvariantCulture),
                    period = reader["period"]?.ToString() ?? "",
                    locationCode = reader["locationCode"]?.ToString()?.Trim() ?? "",
                    locationName = reader["locationName"]?.ToString()?.Trim() ?? "",
                    imagePath = reader["ImagePath"]?.ToString()?.Trim() ?? "",
                    itemType,
                    qrCode = $"{prefix}{reader["code"]}"
                });
            }

            if (results.Any())
                return Ok(new { success = true, count = results.Count, data = results });

            return NotFound(new { success = false, message = "Không tìm thấy mã này" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }

    // POST: api/inventory/generate-batch (hỗ trợ cả vật tư và tài sản)
    [HttpPost("generate-batch")]
public async Task<IActionResult> GenerateBatchQR([FromBody] GenerateBatchRequest request)
{
    if (request?.Codes == null || !request.Codes.Any())
        return BadRequest(new { success = false, message = "Danh sách mã trống" });

    try
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();
        await using var transaction = await connection.BeginTransactionAsync();;

        // Câu SQL chuẩn, rõ ràng, đảm bảo tất cả các trường được gán giá trị đúng
        const string sql = @"
            MERGE QRInventory AS target
            USING (SELECT @Code AS Ivcode, @QRCode AS QRCode) AS source
            ON target.Ivcode = source.Ivcode
            WHEN MATCHED THEN
                UPDATE SET 
                    QRCode = source.QRCode,
                    CreatedDate = GETDATE(),
                    CreatedBy = @CreatedBy,
                    IsActive = 1
            WHEN NOT MATCHED THEN
                INSERT (Ivcode, QRCode, CreatedBy, CreatedDate, IsActive, ImagePath)
                VALUES (source.Ivcode, source.QRCode, @CreatedBy, GETDATE(), 1, NULL);";

        int count = 0;
        foreach (var item in request.Codes)
        {
            string code = item.Code.Trim();
            if (string.IsNullOrEmpty(code)) continue;

            string prefix = item.Type == "Asset" ? "HPASSET:" : "HPAPP:";
            string qrData = $"{prefix}{code}";

            await using var cmd = new SqlCommand(sql, connection, (SqlTransaction)transaction);
            cmd.Parameters.AddWithValue("@Code", code);
            cmd.Parameters.AddWithValue("@QRCode", qrData);
            cmd.Parameters.AddWithValue("@CreatedBy", request.CreatedBy ?? "MobileApp");

            await cmd.ExecuteNonQueryAsync();
            count++;
        }

        await transaction.CommitAsync();

        return Ok(new
        {
            success = true,
            message = $"Đã tạo/cập nhật QR cho {count} mục thành công!"
        });
    }
    catch (Exception ex)
    {
        return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
    }
}

    // POST: api/inventory/upload-image
    [HttpPost("upload-image")]
public async Task<IActionResult> UploadImage([FromForm] IFormFile file, [FromForm] string code, [FromForm] string type = "Inventory")
{
    if (file == null || file.Length == 0)
        return BadRequest(new { success = false, message = "Chưa chọn ảnh" });

    if (string.IsNullOrWhiteSpace(code))
        return BadRequest(new { success = false, message = "Thiếu mã hàng" });

    try
    {
        var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", "products");
        Directory.CreateDirectory(uploadsFolder);

        var fileName = $"{code.Trim()}_{DateTime.Now:yyyyMMddHHmmss}{Path.GetExtension(file.FileName)}";
        var filePath = Path.Combine(uploadsFolder, fileName);

        await using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        var imageUrl = $"/images/products/{fileName}";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        await using var transaction = await connection.BeginTransactionAsync();

string prefix = type == "Asset" ? "HPASSET:" : "HPAPP:";
string qrData = $"{prefix}{code.Trim()}";

const string sql = @"
    MERGE QRInventory AS target
    USING (SELECT @Code AS Ivcode) AS source
    ON target.Ivcode = source.Ivcode
    WHEN MATCHED THEN
        UPDATE SET 
            ImagePath = @ImagePath,
            CreatedDate = GETDATE(),
            CreatedBy = 'MobileApp',
            IsActive = 1
    WHEN NOT MATCHED THEN
        INSERT (Ivcode, QRCode, ImagePath, CreatedBy, CreatedDate, IsActive)
        VALUES (@Code, @QRCode, @ImagePath, 'MobileApp', GETDATE(), 1);";

await using var cmd = new SqlCommand(sql, connection, (SqlTransaction)transaction);
cmd.Parameters.AddWithValue("@Code", code.Trim());
cmd.Parameters.AddWithValue("@ImagePath", imageUrl);
cmd.Parameters.AddWithValue("@QRCode", qrData);

await cmd.ExecuteNonQueryAsync();
await transaction.CommitAsync();

        return Ok(new { success = true, message = "Tải ảnh thành công!", imageUrl });
    }
    catch (Exception ex)
    {
        return StatusCode(500, new { success = false, message = "Lỗi: " + ex.Message });
    }
}

    // ------------------ Models ------------------
    public class QRRequest
    {
        public string QRCode { get; set; } = string.Empty;
    }

    public class GenerateBatchItem
    {
        public string Code { get; set; } = string.Empty;
        public string Type { get; set; } = "Inventory"; // "Inventory" hoặc "Asset"
    }

    public class GenerateBatchRequest
    {
        public List<GenerateBatchItem> Codes { get; set; } = new();
        public string? CreatedBy { get; set; }
    }
}