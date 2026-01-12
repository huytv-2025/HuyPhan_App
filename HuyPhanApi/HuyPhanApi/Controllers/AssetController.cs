using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace HuyPhanApi.Controllers;

[ApiController]
[Route("api/asset")]
public class AssetUploadController : ControllerBase
{
    private readonly IWebHostEnvironment _env;
    private readonly string _connectionString =
        "Server=.;Database=SMILE_BO;User Id=Smile;Password=AnhMinh167TruongDinh;TrustServerCertificate=True;";

    public AssetUploadController(IWebHostEnvironment env)
    {
        _env = env;
    }

    // GET: api/asset
    [HttpGet]
    public async Task<IActionResult> Get()
    {
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
                    q.QRCode,
                    q.ImagePath
                FROM AssetItem a
                LEFT JOIN QRAsset q ON LTRIM(RTRIM(a.AssetClassCode)) = LTRIM(RTRIM(q.AssetClassCode))
                ORDER BY a.AssetClassCode";

            await using var command = new SqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync();

            var list = new List<object>();

            while (await reader.ReadAsync())
            {
                string code = reader["AssetClassCode"]?.ToString()?.Trim() ?? "";
                string qrCodeFromDb = reader["QRCode"]?.ToString()?.Trim();

                list.Add(new
                {
                    assetClassCode = code,
                    assetClassName = reader["AssetClassName"]?.ToString()?.Trim() ?? "Không tên",
                    departmentCode = reader["DepartmentCode"]?.ToString()?.Trim() ?? "",
                    locationCode = reader["LocationCode"]?.ToString()?.Trim() ?? "",
                    slvgQty = reader["SlvgQty"]?.ToString() ?? "0",
                    phisLoc = reader["PhisLoc"]?.ToString()?.Trim() ?? "",
                    phisUser = reader["PhisUser"]?.ToString()?.Trim() ?? "",
                    qrCode = !string.IsNullOrEmpty(qrCodeFromDb) ? qrCodeFromDb : $"HPAPP:{code}",
                    imagePath = reader["ImagePath"]?.ToString()?.Trim() ?? ""
                });
            }

            return Ok(list);
        }
        catch (Exception ex)
        {
            Console.WriteLine("Lỗi Asset API: " + ex.Message);
            return StatusCode(500, new { success = false, message = "Lỗi server: " + ex.Message });
        }
    }

    // POST: api/asset/generate-batch
    [HttpPost("generate-batch")]
    public async Task<IActionResult> GenerateBatch([FromBody] GenerateQrRequest request)
    {
        if (request?.Codes == null || request.Codes.Count == 0)
            return BadRequest(new { success = false, message = "Danh sách mã tài sản trống" });

        try
        {
            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();

            int count = 0;
            foreach (var code in request.Codes)
            {
                string trimmedCode = code.Trim();
                string qrData = $"HPAPP:{trimmedCode}";

                var sql = @"
                    IF EXISTS (SELECT 1 FROM QRAsset WHERE AssetClassCode = @Code)
                        UPDATE QRAsset 
                        SET QRCode = @QRCode, CreatedDate = GETDATE(), CreatedBy = @CreatedBy, IsActive = 1
                        WHERE AssetClassCode = @Code
                    ELSE
                        INSERT INTO QRAsset (AssetClassCode, QRCode, CreatedDate, CreatedBy, IsActive, ImagePath)
                        VALUES (@Code, @QRCode, GETDATE(), @CreatedBy, 1, NULL)";

                await using var cmd = new SqlCommand(sql, connection);
                cmd.Parameters.AddWithValue("@Code", trimmedCode);
                cmd.Parameters.AddWithValue("@QRCode", qrData);
                cmd.Parameters.AddWithValue("@CreatedBy", request.CreatedBy ?? "MobileApp");

                int rows = await cmd.ExecuteNonQueryAsync();
                if (rows > 0) count++;
            }

            return Ok(new { success = true, count = count, message = $"Đã tạo QR cho {count} tài sản thành công!" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, message = ex.Message });
        }
    }

    // POST: api/asset/upload-image
    [HttpPost("upload-image")]
    public async Task<IActionResult> UploadImage([FromForm] IFormFile file, [FromForm] string assetClassCode)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new { success = false, message = "Chưa chọn file ảnh" });

        if (string.IsNullOrWhiteSpace(assetClassCode))
            return BadRequest(new { success = false, message = "Thiếu mã tài sản (AssetClassCode)" });

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png" };
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();

        if (!allowedExtensions.Contains(extension))
            return BadRequest(new { success = false, message = "Chỉ chấp nhận file .jpg, .jpeg, .png" });

        if (file.Length > 5 * 1024 * 1024)
            return BadRequest(new { success = false, message = "File quá lớn (tối đa 5MB)" });

        if (!file.ContentType.StartsWith("image/"))
            return BadRequest(new { success = false, message = "File không phải định dạng ảnh" });

        try
        {
            // Dùng đường dẫn tuyệt đối giống Inventory để tránh lỗi _env.WebRootPath
            var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "images", "assets");
            Console.WriteLine($"Thư mục lưu ảnh Asset: {uploadsFolder}");

            Directory.CreateDirectory(uploadsFolder);

            var safeCode = assetClassCode.Trim().Replace("/", "-").Replace("\\", "-");
            var uniqueFileName = $"{safeCode}_{DateTime.Now:yyyyMMddHHmmssfff}{extension}";
            var filePath = Path.Combine(uploadsFolder, uniqueFileName);

            // Lưu file ảnh
            await using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }
            Console.WriteLine($"Đã lưu ảnh: {filePath}");

            var imageUrl = $"/images/assets/{uniqueFileName}";

            string? oldImagePath = null;

            await using var connection = new SqlConnection(_connectionString);
            await connection.OpenAsync();
            await using var transaction = connection.BeginTransaction();

            // Sửa: Lấy ảnh cũ với xử lý DBNull đúng scope
            const string getOldImageSql = "SELECT ImagePath FROM QRAsset WHERE AssetClassCode = @AssetClassCode";
            await using (var cmdGet = new SqlCommand(getOldImageSql, connection, transaction))
            {
                cmdGet.Parameters.AddWithValue("@AssetClassCode", assetClassCode.Trim());

                var result = await cmdGet.ExecuteScalarAsync();  // Biến result được khai báo ở đây

                // Xử lý DBNull an toàn
                if (result != DBNull.Value && result != null)
                {
                    oldImagePath = result.ToString();
                }
            }

            // Cập nhật hoặc insert
            const string sql = @"
                IF EXISTS (SELECT 1 FROM QRAsset WHERE AssetClassCode = @AssetClassCode)
                    UPDATE QRAsset
                    SET ImagePath = @ImagePath,
                        CreatedDate = GETDATE(),
                        CreatedBy = @CreatedBy,
                        IsActive = 1
                    WHERE AssetClassCode = @AssetClassCode
                ELSE
                    INSERT INTO QRAsset
                    (AssetClassCode, QRCode, ImagePath, CreatedDate, CreatedBy, IsActive)
                    VALUES
                    (@AssetClassCode, 'HPAPP:' + @AssetClassCode, @ImagePath, GETDATE(), @CreatedBy, 1)";

            await using var cmd = new SqlCommand(sql, connection, transaction);
            cmd.Parameters.AddWithValue("@AssetClassCode", assetClassCode.Trim());
            cmd.Parameters.AddWithValue("@ImagePath", imageUrl);
            cmd.Parameters.AddWithValue("@CreatedBy", "MobileApp");

            await cmd.ExecuteNonQueryAsync();

            await transaction.CommitAsync();

            // Xóa file ảnh cũ nếu tồn tại
            if (!string.IsNullOrEmpty(oldImagePath))
            {
                var oldPhysicalPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", oldImagePath.TrimStart('/'));
                if (System.IO.File.Exists(oldPhysicalPath))
                {
                    try { System.IO.File.Delete(oldPhysicalPath); } catch { }
                }
            }

            return Ok(new { success = true, message = "Đã tải ảnh lên thành công!", imageUrl });
        }
        catch (Exception ex)
        {
            Console.WriteLine("=== LỖI UPLOAD ASSET ===");
            Console.WriteLine($"AssetClassCode: {assetClassCode}");
            Console.WriteLine($"Message: {ex.Message}");
            Console.WriteLine($"StackTrace: {ex.StackTrace}");

            return StatusCode(500, new
            {
                success = false,
                message = "Lỗi server khi upload ảnh",
                errorDetail = ex.Message
            });
        }
    }
}

// Model nằm ngoài class controller
public class GenerateQrRequest
{
    public List<string>? Codes { get; set; }
    public string? CreatedBy { get; set; }
}