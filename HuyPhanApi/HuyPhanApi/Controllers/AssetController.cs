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
}
public class GenerateQrRequest
{
    public List<string>? Codes { get; set; }
    public string? CreatedBy { get; set; }
}