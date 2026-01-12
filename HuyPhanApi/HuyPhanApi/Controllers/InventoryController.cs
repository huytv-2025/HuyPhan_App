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
                SELECT 
                    i.VICode AS code,
                    dbo.fTCVNToUnicode(id.IName) AS name,
                    dbo.fTCVNToUnicode(ISNULL(u.UnitName, 'Cái')) AS unit,
                    i.VEnd AS quantity,
                    i.VPeriod AS period,
                    i.RVC AS locationCode,
                    dbo.fTCVNToUnicode(de.RVCName) AS locationName,
                    q.ImagePath,
                    'Inventory' AS itemType,
                    q.QRCode
                FROM Inventory i
                LEFT JOIN Itemdef id ON LTRIM(RTRIM(i.VICode)) = LTRIM(RTRIM(id.Icode))
                LEFT JOIN IUnitDef u ON id.IUnit = u.UnitCode
                LEFT JOIN QRInventory q ON LTRIM(RTRIM(i.VICode)) = q.Ivcode
                LEFT JOIN DefRVCList de ON de.RVCNo = i.RVC
                WHERE 1=1 {0}
                ORDER BY code";

            string filter = "";

            if (!string.IsNullOrEmpty(vperiod))
            {
                filter += " AND i.VPeriod = @VPeriod";
            }

            if (!string.IsNullOrEmpty(search))
            {
                filter += @" AND (i.VICode LIKE @Search OR dbo.fTCVNToUnicode(id.IName) LIKE @Search)";
            }

            sql = string.Format(sql, filter);

            await using var command = new SqlCommand(sql, connection);

            if (!string.IsNullOrEmpty(vperiod))
                command.Parameters.AddWithValue("@VPeriod", vperiod);

            if (!string.IsNullOrEmpty(search))
                command.Parameters.AddWithValue("@Search", $"%{search}%");

            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<object>();
            while (await reader.ReadAsync())
            {
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
                    itemType = "Inventory",
                    qrCode = reader["QRCode"]?.ToString()?.Trim() ?? $"HPAPP:{reader["code"]}"
                });
            }

            return Ok(list);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }

    // POST: api/inventory/search (Chỉ hỗ trợ quét QR vật tư)
    [HttpPost("search")]
    public async Task<IActionResult> SearchByQR([FromBody] QRRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.QRCode))
            return BadRequest(new { success = false, message = "Vui lòng quét QR" });

        string qrInput = request.QRCode.Trim();

        // Bỏ tiền tố nếu có
        if (qrInput.StartsWith("HPAPP:", StringComparison.OrdinalIgnoreCase))
            qrInput = qrInput.Substring(6);

        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            const string query = @"
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
            command.Parameters.AddWithValue("@Code", qrInput.Trim());

            await using var reader = await command.ExecuteReaderAsync();

            var results = new List<object>();
            while (await reader.ReadAsync())
            {
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
                    itemType = "Inventory",
                    qrCode = $"HPAPP:{reader["code"]}"
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

    // POST: api/inventory/generate-batch (Chỉ hỗ trợ vật tư)
    [HttpPost("generate-batch")]
    public async Task<IActionResult> GenerateBatchQR([FromBody] GenerateBatchRequest request)
    {
        if (request?.Codes == null || !request.Codes.Any())
            return BadRequest(new { success = false, message = "Danh sách mã trống" });

        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

            const string sql = @"
                IF EXISTS (SELECT 1 FROM QRInventory WHERE Ivcode = @Code)
                    UPDATE QRInventory SET QRCode = @QRCode, CreatedDate = GETDATE(), CreatedBy = @CreatedBy
                    WHERE Ivcode = @Code
                ELSE
                    INSERT INTO QRInventory (Ivcode, QRCode, CreatedBy, CreatedDate, IsActive)
                    VALUES (@Code, @QRCode, @CreatedBy, GETDATE(), 1)";

            int count = 0;
            foreach (var code in request.Codes)
            {
                string trimmedCode = code.Trim();
                string qrData = $"HPAPP:{trimmedCode}";

                await using var cmd = new SqlCommand(sql, connection, transaction);
                cmd.Parameters.AddWithValue("@Code", trimmedCode);
                cmd.Parameters.AddWithValue("@QRCode", qrData);
                cmd.Parameters.AddWithValue("@CreatedBy", request.CreatedBy ?? "System");

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
public async Task<IActionResult> UploadImage([FromForm] IFormFile file, [FromForm] string ivcode)  // ← đã đổi thành ivcode
{
    if (file == null || file.Length == 0)
        return BadRequest(new { success = false, message = "Chưa chọn ảnh" });

    if (string.IsNullOrWhiteSpace(ivcode))  // ← sửa: code → ivcode
        return BadRequest(new { success = false, message = "Thiếu mã hàng" });

    try
    {
        var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", "products");
        Directory.CreateDirectory(uploadsFolder);

        var fileName = $"{ivcode.Trim()}_{DateTime.Now:yyyyMMddHHmmss}{Path.GetExtension(file.FileName)}";  // ← sửa: code → ivcode
        var filePath = Path.Combine(uploadsFolder, fileName);

        await using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        var imageUrl = $"/images/products/{fileName}";

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        const string sql = @"
            IF EXISTS (SELECT 1 FROM QRInventory WHERE Ivcode = @Ivcode)
                UPDATE QRInventory SET ImagePath = @ImagePath WHERE Ivcode = @Ivcode
            ELSE
                INSERT INTO QRInventory (Ivcode, QRCode, ImagePath, CreatedBy, CreatedDate, IsActive)
                VALUES (@Ivcode, 'HPAPP:' + @Ivcode, @ImagePath, 'App', GETDATE(), 1)";

        await using var cmd = new SqlCommand(sql, connection);
        cmd.Parameters.AddWithValue("@Ivcode", ivcode.Trim());  // ← sửa: @Code → @Ivcode, code → ivcode
        cmd.Parameters.AddWithValue("@ImagePath", imageUrl);

        await cmd.ExecuteNonQueryAsync();

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

    public class GenerateBatchRequest
    {
        public List<string> Codes { get; set; } = new();
        public string? CreatedBy { get; set; }
    }
}