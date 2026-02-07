using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace HuyPhanApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class LoginController : ControllerBase
{
    private readonly string _connectionString;

    // Inject IConfiguration vào constructor
    public LoginController(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Không tìm thấy connection string 'Default'");
    }
    [HttpPost]
public async Task<IActionResult> Login([FromBody] LoginRequest request)
{
    if (string.IsNullOrWhiteSpace(request.ClerkID) || string.IsNullOrWhiteSpace(request.SecurityCode))
    {
        return BadRequest(new { success = false, message = "Vui lòng nhập đầy đủ ClerkID và Security Code" });
    }

    try
    {
        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        // Kiểm tra đăng nhập
        var query = "SELECT COUNT(1) FROM Clerk WHERE ClerkID = @ClerkID AND SecurityCode = @SecurityCode";
        using var command = new SqlCommand(query, connection);
        command.Parameters.AddWithValue("@ClerkID", request.ClerkID.Trim());
        command.Parameters.AddWithValue("@SecurityCode", request.SecurityCode);

        var count = Convert.ToInt32(await command.ExecuteScalarAsync());

        if (count <= 0)
        {
            return Unauthorized(new { success = false, message = "Sai ClerkID hoặc Security Code" });
        }

        // ĐĂNG NHẬP THÀNH CÔNG → TẠO BẢNG NẾU CHƯA CÓ
        await CreateTablesIfNotExists(connection);

        return Ok(new { success = true, message = "Đăng nhập thành công!" });
    }
    catch (Exception ex)
    {
        return StatusCode(500, new { success = false, message = "Lỗi kết nối database: " + ex.Message });
    }
}
// Phương thức mới: Tạo bảng nếu chưa tồn tại
private async Task CreateTablesIfNotExists(SqlConnection connection)
{
    var tables = new[]
    {
        // 1. QRAssetPhisical
        @"
            IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[QRAssetPhisical]') AND type in (N'U'))
            BEGIN
                CREATE TABLE [dbo].[QRAssetPhisical](
                    [Id] [bigint] IDENTITY(1,1) NOT NULL,
                    [AssetClassCode] [nvarchar](50) NOT NULL,
                    [AssetItemCode] [nvarchar](50) NOT NULL,
                    [Vend] [decimal](18, 4) NULL DEFAULT (0),
                    [Vphis] [decimal](18, 4) NULL DEFAULT (0),
                    [LocationCode] [nvarchar](50) NULL,
                    [DepartmentCode] [nvarchar](50) NULL,
                    [Vperiod] [nvarchar](20) NULL,
                    [CreatedDate] [datetime] NULL DEFAULT (getdate()),
                    [CreatedBy] [nvarchar](100) NULL,
                    [IsActive] [bit] NULL DEFAULT (1),
                    PRIMARY KEY CLUSTERED ([Id] ASC)
                ) ON [PRIMARY]
            END
        ",

        // 2. QRInvPhisical
        @"
            IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[QRInvPhisical]') AND type in (N'U'))
            BEGIN
                CREATE TABLE [dbo].[QRInvPhisical](
                    [Id] [int] IDENTITY(1,1) NOT NULL,
                    [Ivcode] [nvarchar](50) NOT NULL,
                    [Vend] [decimal](18, 3) NULL,
                    [Vphis] [decimal](18, 3) NULL,
                    [RVC] [nvarchar](50) NOT NULL,
                    [Vperiod] [nvarchar](10) NOT NULL,
                    [CreatedDate] [datetime] NOT NULL DEFAULT (getdate()),
                    [CreatedBy] [nvarchar](100) NULL,
                    [IsActive] [bit] NOT NULL DEFAULT (1),
                    PRIMARY KEY CLUSTERED ([Id] ASC)
                ) ON [PRIMARY]
            END
        ",

        // 3. QRAsset
        @"
            IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[QRAsset]') AND type in (N'U'))
            BEGIN
                CREATE TABLE [dbo].[QRAsset](
                    [Id] [int] IDENTITY(1,1) NOT NULL,
                    [AssetClassCode] [nvarchar](50) NOT NULL,
                    [AssetItemCode] [nvarchar](50) NOT NULL,
                    [LocationCode] [nvarchar](50) NULL,
                    [DepartmentCode] [nvarchar](50) NULL,
                    [QRCode] [nvarchar](200) NOT NULL,
                    [ImagePath] [nvarchar](500) NULL,
                    [CreatedBy] [nvarchar](100) NULL,
                    [CreatedDate] [datetime] NULL DEFAULT (getdate()),
                    [IsActive] [bit] NULL DEFAULT (1),
                    PRIMARY KEY CLUSTERED ([Id] ASC),
                    CONSTRAINT [UK_QRAsset_AssetCode] UNIQUE NONCLUSTERED ([AssetClassCode] ASC)
                ) ON [PRIMARY]
            END
        ",

        // 4. QRInventory
        @"
            IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[QRInventory]') AND type in (N'U'))
            BEGIN
                CREATE TABLE [dbo].[QRInventory](
                    [Id] [int] IDENTITY(1,1) NOT NULL,
                    [Ivcode] [nvarchar](50) NOT NULL,
                    [QRCode] [nvarchar](255) NOT NULL,
                    [CreatedDate] [datetime] NULL DEFAULT (getdate()),
                    [CreatedBy] [nvarchar](50) NULL,
                    [IsActive] [bit] NULL DEFAULT (1),
                    [ImagePath] [nvarchar](255) NULL,
                    PRIMARY KEY CLUSTERED ([Id] ASC)
                ) ON [PRIMARY]
            END
        "
    };

    foreach (var createScript in tables)
    {
        try
        {
            using var cmd = new SqlCommand(createScript, connection);
            await cmd.ExecuteNonQueryAsync();
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Lỗi tạo bảng: {ex.Message}");
            // Không throw để tránh làm hỏng login
        }
    }
}
}
// Class nhận JSON – tên property khớp đúng với DB và query
public class LoginRequest
{
    public string ClerkID { get; set; } = string.Empty;
    public string SecurityCode { get; set; } = string.Empty; // Có chữ 'r' như trong bảng Clerk
}