using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Threading.Tasks;

namespace HuyPhanApi.Services
{
    public class FcmService
    {
        private readonly ILogger<FcmService> _logger;

        public FcmService(ILogger<FcmService> logger)
        {
            _logger = logger;

            if (FirebaseApp.DefaultInstance == null)
            {
                try
                {
                    string credentialPath = Path.Combine(Directory.GetCurrentDirectory(), "firebase-adminsdk.json");

                    if (!File.Exists(credentialPath))
                    {
                        throw new FileNotFoundException("Không tìm thấy file firebase-adminsdk.json trong thư mục gốc dự án.");
                    }

                    FirebaseApp.Create(new AppOptions
                    {
                        Credential = GoogleCredential.FromFile(credentialPath)
                    });

                    _logger.LogInformation("Firebase Admin SDK khởi tạo thành công.");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Khởi tạo Firebase Admin SDK thất bại.");
                    throw; // Để biết lỗi ngay khi app start
                }
            }
        }

        public async Task SendSilentBadgeUpdate(int badgeCount)
        {
            if (badgeCount <= 0) return;

            var message = new Message
            {
                Topic = "inventory_updates",
                Data = new Dictionary<string, string>
                {
                    { "type", "inventory_changed" },
                    { "badge", badgeCount.ToString() }
                },
                Apns = new ApnsConfig
                {
                    Aps = new Aps
                    {
                        Badge = badgeCount,
                        ContentAvailable = true  // Silent push cho iOS
                    }
                },
                Android = new AndroidConfig
                {
                    Priority = Priority.Normal
                }
            };

            try
            {
                string response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                _logger.LogInformation($"Gửi silent badge update thành công: {response} (badge: {badgeCount})");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi gửi FCM silent push");
            }
        }

        // Tùy chọn: Gửi đến token cụ thể (nếu sau này cần push cá nhân hóa)
        public async Task SendToUser(string token, int badgeCount)
        {
            if (string.IsNullOrEmpty(token) || badgeCount <= 0) return;

            var message = new Message
            {
                Token = token,
                Data = new Dictionary<string, string> { { "badge", badgeCount.ToString() } },
                Apns = new ApnsConfig { Aps = new Aps { Badge = badgeCount, ContentAvailable = true } }
            };

            try
            {
                string response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                _logger.LogInformation($"Gửi push đến token {token}: {response}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi gửi FCM đến user");
            }
        }
    }
}