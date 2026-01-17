namespace HuyPhanApi.Models;  // ← namespace riêng, tránh trùng Controllers

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