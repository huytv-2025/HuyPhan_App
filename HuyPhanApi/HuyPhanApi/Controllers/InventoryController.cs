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

            var query = @"
                SELECT 
                    i.VICode, 
                    i.VEnd, 
                    i.RVC,                    -- Thêm cột RVC gốc
                    i.VPeriod, 
                    dbo.fTCVNToUnicode(id.IName) AS IName,
                    ISNULL(u.UnitName, 'Cái') AS UnitName,
                    dbo.fTCVNToUnicode(de.RVCName) AS RVCName,  -- ← THÊM RVCName
                    q.ImagePath
                FROM Inventory i
                LEFT JOIN Itemdef id ON LTRIM(RTRIM(i.VICode)) = LTRIM(RTRIM(id.Icode))
                LEFT JOIN IUnitDef u ON id.IUnit = u.UnitCode
                LEFT JOIN QRInventory q ON LTRIM(RTRIM(i.VICode)) = q.Ivcode
                LEFT JOIN DefRVCList de ON de.RVCNo = i.RVC     -- ← JOIN DefRVCList
                WHERE 1 = 1";

            if (!string.IsNullOrEmpty(vperiod))
                query += " AND i.VPeriod = @VPeriod";

            if (!string.IsNullOrEmpty(search))
                query += " AND (i.VICode LIKE '%' + @Search + '%' OR dbo.fTCVNToUnicode(id.IName) LIKE '%' + @Search + '%')";

            query += " ORDER BY i.VICode";

            await using var command = new SqlCommand(query, connection);

            if (!string.IsNullOrEmpty(vperiod))
                command.Parameters.AddWithValue("@VPeriod", vperiod);

            if (!string.IsNullOrEmpty(search))
                command.Parameters.AddWithValue("@Search", search);

            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<object>();
            while (await reader.ReadAsync())
            {
                list.Add(new
                {
                    ivcode = reader["VICode"]?.ToString()?.Trim() ?? "",
                    rvc = reader["RVC"]?.ToString()?.Trim() ?? "",       // ← THÊM RVC
                    rvcname = reader["RVCName"]?.ToString()?.Trim() ?? "", // ← THÊM RVCName
                    vend = ((decimal)reader["VEnd"]).ToString(System.Globalization.CultureInfo.InvariantCulture),
                    vperiod = reader["VPeriod"]?.ToString() ?? "",
                    iname = reader["IName"]?.ToString()?.Trim() ?? "",
                    unit = reader["UnitName"]?.ToString()?.Trim() ?? "Cái",
                    imagePath = reader["ImagePath"]?.ToString()?.Trim() ?? ""
                });
            }

            return Ok(list);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }

    // POST: api/inventory/search (Quét QR - thêm RVCName)
    [HttpPost("search")]
public async Task<IActionResult> SearchByQR([FromBody] QRRequest request)
{
    Console.WriteLine($">>> RECEIVED QRCode: '{request?.QRCode}'");

    if (string.IsNullOrWhiteSpace(request?.QRCode))
    {
        return BadRequest(new { success = false, message = "Vui lòng nhập hoặc quét QR/Barcode" });
    }

    string qrInput = request.QRCode.Trim();

    // Trích xuất Ivcode từ QR: nếu có tiền tố "HPAPP:", bỏ đi
    string ivcode = qrInput.StartsWith("HPAPP:", StringComparison.OrdinalIgnoreCase)
        ? qrInput.Substring(6).Trim()
        : qrInput;

    try
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        var query = @"
            SELECT 
                i.VICode, 
                i.RVC,
                dbo.fTCVNToUnicode(de.RVCName) AS RVCName,
                i.VEnd, 
                dbo.fTCVNToUnicode(id.IName) AS IName,
                ISNULL(u.UnitName, 'Cái') AS UnitName,
                q.ImagePath  
            FROM Inventory i
            LEFT JOIN Itemdef id ON LTRIM(RTRIM(i.VICode)) = LTRIM(RTRIM(id.Icode))
            LEFT JOIN IUnitDef u ON id.IUnit = u.UnitCode
            LEFT JOIN DefRVCList de ON de.RVCNo = i.RVC
            LEFT JOIN QRInventory q ON LTRIM(RTRIM(i.VICode)) = q.Ivcode
            WHERE LTRIM(RTRIM(i.VICode)) = @Ivcode
            ORDER BY i.RVC";

        await using var command = new SqlCommand(query, connection);
        command.Parameters.AddWithValue("@Ivcode", ivcode);

        await using var reader = await command.ExecuteReaderAsync();

        var results = new List<object>();

        while (await reader.ReadAsync())
        {
            results.Add(new
            {
                ivcode = reader["VICode"]?.ToString()?.Trim() ?? "",
                rvc = reader["RVC"]?.ToString()?.Trim() ?? "",
                rvcname = reader["RVCName"]?.ToString()?.Trim() ?? "Không có RVC",
                vend = ((decimal)reader["VEnd"]).ToString(System.Globalization.CultureInfo.InvariantCulture),
                iname = reader["IName"]?.ToString()?.Trim() ?? "Không có tên",
                unit = reader["UnitName"]?.ToString()?.Trim() ?? "Cái",
                imagePath = reader["ImagePath"]?.ToString()?.Trim() ?? ""
            });
        }

        if (results.Any())
        {
            return Ok(new
            {
                success = true,
                count = results.Count,           // Thêm số lượng RVC tìm được
                data = results                  // Trả về array (có thể 1 hoặc nhiều item)
            });
        }

        return NotFound(new { success = false, message = "Không tìm thấy sản phẩm với mã này" });
    }
    catch (Exception ex)
    {
        return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
    }
}

    // POST: api/inventory/generate-batch
    [HttpPost("generate-batch")]
    public async Task<IActionResult> GenerateBatchQR([FromBody] GenerateBatchRequest request)
    {
        if (request == null || request.Ivcodes == null || !request.Ivcodes.Any())
        {
            return BadRequest(new { success = false, message = "Danh sách mã hàng trống" });
        }

        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

            const string sql = @"
                IF EXISTS (SELECT 1 FROM QRInventory WHERE Ivcode = @Ivcode)
                BEGIN
                    UPDATE QRInventory
                    SET QRCode = @QRCode, CreatedDate = GETDATE(), CreatedBy = @CreatedBy
                    WHERE Ivcode = @Ivcode
                END
                ELSE
                BEGIN
                    INSERT INTO QRInventory (Ivcode, QRCode, CreatedBy, CreatedDate)
                    VALUES (@Ivcode, @QRCode, @CreatedBy, GETDATE())
                END";

            foreach (var ivcode in request.Ivcodes)
            {
                var qrData = $"HPAPP:{ivcode.Trim()}";

                await using var cmd = new SqlCommand(sql, connection, transaction);
                cmd.Parameters.AddWithValue("@Ivcode", ivcode.Trim());
                cmd.Parameters.AddWithValue("@QRCode", qrData);
                cmd.Parameters.AddWithValue("@CreatedBy", request.CreatedBy ?? "System");

                await cmd.ExecuteNonQueryAsync();
            }

            await transaction.CommitAsync();

            return Ok(new
            {
                success = true,
                message = $"Đã tạo/cập nhật QR cho {request.Ivcodes.Count} sản phẩm thành công!"
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }

    // POST: api/inventory/upload-image
    [HttpPost("upload-image")]
    public async Task<IActionResult> UploadImage([FromForm] IFormFile file, [FromForm] string ivcode)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new { success = false, message = "Chưa chọn ảnh" });

        if (string.IsNullOrWhiteSpace(ivcode))
            return BadRequest(new { success = false, message = "Thiếu mã hàng" });

        try
        {
            // Tạo thư mục lưu ảnh nếu chưa có
            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", "products");
            Directory.CreateDirectory(uploadsFolder);

            // Đặt tên file duy nhất để tránh trùng
            var fileName = $"{ivcode.Trim()}_{DateTime.Now:yyyyMMddHHmmss}{Path.GetExtension(file.FileName)}";
            var filePath = Path.Combine(uploadsFolder, fileName);

            // Lưu file vào server
            await using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            var imageUrl = $"/images/products/{fileName}";

            // Cập nhật đường dẫn ảnh vào bảng QRInventory
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            var sql = @"
                IF EXISTS (SELECT 1 FROM QRInventory WHERE Ivcode = @Ivcode)
                    UPDATE QRInventory SET ImagePath = @ImagePath WHERE Ivcode = @Ivcode
                ELSE
                    INSERT INTO QRInventory (Ivcode, QRCode, ImagePath, CreatedBy, CreatedDate, IsActive)
                    VALUES (@Ivcode, 'HPAPP:' + @Ivcode, @ImagePath, 'App', GETDATE(), 1)";

            await using var cmd = new SqlCommand(sql, connection);
            cmd.Parameters.AddWithValue("@Ivcode", ivcode.Trim());
            cmd.Parameters.AddWithValue("@ImagePath", imageUrl);

            await cmd.ExecuteNonQueryAsync();

            return Ok(new 
            { 
                success = true, 
                message = "Tải ảnh lên thành công!", 
                imageUrl 
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = "Lỗi khi tải ảnh: " + ex.Message });
        }
    }

    // ------------------ Model Classes (nested) ------------------
    public class QRRequest
    {
        public string QRCode { get; set; } = string.Empty;
    }

    public class GenerateBatchRequest
    {
        public List<string> Ivcodes { get; set; } = new();
        public string? CreatedBy { get; set; }
    }
}