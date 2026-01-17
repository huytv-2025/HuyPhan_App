// Services/FcmService.cs
namespace HuyPhanApi.Services;

public class FcmService
{
    // Constructor nếu cần inject HttpClient, config, logger...
    public FcmService(/* các dependency nếu có */)
    {
    }

    public async Task SendSilentBadgeUpdate(int badgeCount)
    {
        // Logic gửi FCM silent notification để update badge trên mobile
        // Ví dụ: dùng FirebaseAdmin SDK hoặc HttpClient gửi đến FCM server
        // Hiện tại có thể để tạm trống hoặc throw nếu chưa implement
        Console.WriteLine($"[FCM] Cập nhật badge: {badgeCount}");
        await Task.CompletedTask;
    }
}