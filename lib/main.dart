  import 'package:flutter/material.dart';
  import 'package:http/http.dart' as http;
  import 'dart:convert';
  import 'package:flutter_easyloading/flutter_easyloading.dart';
  import 'package:qr_flutter/qr_flutter.dart';
  import 'package:mobile_scanner/mobile_scanner.dart'; // Thêm package này vào pubspec.yaml: mobile_scanner: ^5.1.1
  import 'package:image_picker/image_picker.dart';

  // Global lưu base URL sau khi login thành công
  class AppConfig {
    static String baseUrl = '';
  }

  void main() {
    runApp(const MyApp());
  }

  class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        title: 'HuyPhan',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          fontFamily: 'Roboto',
        ),
        home: const LoginScreen(),
        debugShowCheckedModeBanner: false,
        builder: EasyLoading.init(),
      );
    }
  }

  // ================== TRANG ĐĂNG NHẬP (GIỮ NGUYÊN ĐẸP) ==================
  class LoginScreen extends StatefulWidget {
    const LoginScreen({super.key});

    @override
    State<LoginScreen> createState() => _LoginScreenState();
  }

  class _LoginScreenState extends State<LoginScreen> {
    final _clerkIdController = TextEditingController();
    final _securityCodeController = TextEditingController();
    final _ipController = TextEditingController(text: 'https://overtimidly-ungoggled-isaura.ngrok-free.dev');
    final _portController = TextEditingController();

    String _errorMessage = '';
    bool _isLoading = false;
    late String apiUrl;

    @override
    void initState() {
      super.initState();
      _updateApiUrl();
      _ipController.addListener(_updateApiUrl);
      _portController.addListener(_updateApiUrl);
    }

    void _updateApiUrl() {
  final ip = _ipController.text.trim();
  final portText = _portController.text.trim();

  if (ip.isNotEmpty) {
    String base;
    if (portText.isNotEmpty) {
      base = 'http://$ip:$portText';
    } else {
      // Ngrok luôn dùng HTTPS → ép dùng https khi port trống
      base = ip.startsWith('http') ? ip : 'https://$ip';
    }
    apiUrl = '$base/api/login';
    AppConfig.baseUrl = base;
  }
}

    Future<void> _login() async {
      _updateApiUrl();

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final clerkId = _clerkIdController.text.trim();
      final securityCode = _securityCodeController.text;

      if (clerkId.isEmpty || securityCode.isEmpty) {
        setState(() {
          _errorMessage = 'Vui lòng nhập đầy đủ ClerkID và Security Code';
          _isLoading = false;
        });
        return;
      }

      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
          'ClerkID': clerkId,           // Viết hoa C và I
          'SecurityCode': securityCode, // Có chữ 'r' và viết hoa S
        }),
        ).timeout(const Duration(seconds: 15));

        final data = jsonDecode(response.body);

        if (response.statusCode == 200 && data['success'] == true) {
          
          

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainMenuScreen()),
            );
          }
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Đăng nhập thất bại (mã: ${response.statusCode})';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Không kết nối được server.\n'
                  'Lỗi: $e';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF80deea), Color(0xFF26c6da), Color(0xFF00acc1)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Card(
                elevation: 20,
                shadowColor: const Color.fromARGB(115, 0, 0, 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ====================== LOGO ĐẸP MỚI ======================
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_icon.png', // ← Đặt ảnh logo thật của bạn vào đây
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Nếu không load được ảnh → fallback icon cũ
                              return const Icon(Icons.lock_person_rounded, size: 80, color: Colors.teal);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      const Text(
                        'Huy Phan',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Text(
                        'Đăng Nhập Hệ Thống',
                        style: TextStyle(fontSize: 20, color: Colors.teal, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 40),

                      // Các TextField giữ nguyên như cũ
                      TextField(
                        controller: _ipController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'IP Server',
                          hintText: 'Ví dụ: 192.168.1.100 hoặc 10.0.2.2',
                          prefixIcon: const Icon(Icons.computer),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Port',
                          hintText: 'Có thể để trống nếu ko dùng port',
                          prefixIcon: const Icon(Icons.settings_ethernet),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _clerkIdController,
                        decoration: InputDecoration(
                          labelText: 'ClerkID',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _securityCodeController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Security Code',
                          prefixIcon: const Icon(Icons.vpn_key),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 12,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('ĐĂNG NHẬP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
    @override
    void dispose() {
      _clerkIdController.dispose();
      _securityCodeController.dispose();
      _ipController.dispose();
      _portController.dispose();
      super.dispose();
    }
  }
  // ================== TRANG HOME ĐẸP & SANG TRỌNG ==================
  class HomeScreen extends StatelessWidget {
    const HomeScreen({super.key});

    @override
    Widget build(BuildContext context) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00acc1), Color(0xFF26c6da), Color(0xFF80deea)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 8),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0, 15))],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront_rounded, size: 90, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              const Text('Chào mừng trở lại!', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              const Text('Huy Phan App', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(offset: Offset(0, 4), blurRadius: 12, color: Colors.black38)])),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text('Hệ thống quản lý hàng hóa bằng QR Code', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, color: Colors.white, height: 1.6)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    Text('Phiên bản 1.0', style: TextStyle(fontSize: 15, color: Colors.white.withAlpha(230))),
                    const SizedBox(height: 8),
                    Text('© 2025 Huy Phan.', style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(170))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
  // ================== MENU CHÍNH (GIỮ NGUYÊN ICON ĐẸP) ==================
  class MainMenuScreen extends StatefulWidget {
    const MainMenuScreen({super.key});

    @override
    State<MainMenuScreen> createState() => _MainMenuScreenState();
  }

  class _MainMenuScreenState extends State<MainMenuScreen> {
    int _selectedIndex = 0;
    late List<Widget> _pages;

    @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),           // ← Trang Home đẹp mới ở vị trí đầu tiên
      const SaleOrderScreen(),
      const QRScanScreen(),
      const QRUpdateScreen(),
      const ImageManagerScreen(),
    ];
  }

    void _onItemTapped(int index) {
      setState(() {
        _selectedIndex = index;
      });
    }

    void _logout() {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('HuyPhan App'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Đăng xuất',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Đăng xuất'),
                    content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _logout();
                        },
                        child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Saleorder'),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Quét QR'),
            BottomNavigationBarItem(icon: Icon(Icons.sync), label: 'Cập nhật QR'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Thiết lập'),
          ],
        ),
      );
    }
  }

  // ================== TRANG QUÉT QR - HOÀN CHỈNH VỚI ẢNH SẢN PHẨM ==================
class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  MobileScannerController cameraController = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isScanning = true;
  String? _scanResult;
  Map<String, dynamic>? itemData; // ← Biến lưu toàn bộ data từ API (bao gồm imagePath)

  String get baseUrl => AppConfig.baseUrl;

  Future<void> _searchInventory(String qrData) async {
  if (qrData.startsWith('HPAPP:')) {
    final ivcode = qrData.substring(6).trim();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/inventory/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'QRCode': ivcode}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          var rawData = data['data'];

          if (rawData == null || (rawData is List && rawData.isEmpty)) {
            setState(() {
              _scanResult = 'Không tìm thấy sản phẩm';
              itemData = null;
            });
            return;
          }

          late Map<String, dynamic> item;
          if (rawData is List) {
            item = rawData[0] as Map<String, dynamic>;
          } else if (rawData is Map<String, dynamic>) {
            item = rawData;
          } else {
            setState(() {
              _scanResult = 'Dữ liệu từ server không hợp lệ';
              itemData = null;
            });
            return;
          }

          itemData = item;

          setState(() {
  String rvcDisplay = item['rvcname'] ?? item['rvc'] ?? 'Không có';
  int totalCount = rawData is List ? rawData.length : 1;

  String resultText =
      'Mã hàng: ${item['ivcode']}\n'
      'RVC: $rvcDisplay\n'
      'Tên SP: ${item['iname'] ?? 'Không có tên'}\n'
      'Tồn kho: ${item['vend']} cái';

  if (totalCount > 1) {
    resultText += '\n\n(Có $totalCount kho chứa sản phẩm này)';
  }

  _scanResult = resultText;
});
        } else {
          setState(() {
            _scanResult = data['message'] ?? 'Không tìm thấy sản phẩm';
            itemData = null;
          });
        }
      } else {
        setState(() {
          _scanResult = 'Lỗi server: ${response.statusCode}';
          itemData = null;
        });
      }
    } catch (e) {
      setState(() {
        _scanResult = 'Lỗi kết nối: $e';
        itemData = null;
      });
    }
  } else {
    setState(() {
      _scanResult = 'QR không hợp lệ\n(Yêu cầu định dạng: HPAPP:mã_hàng)';
      itemData = null;
    });
  }
}

  void _switchCamera() {
    cameraController.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét QR Code'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _switchCamera,
            tooltip: 'Chuyển camera trước/sau',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (_isScanning && barcodes.isNotEmpty) {
                  final qrData = barcodes.first.rawValue ?? '';
                  if (qrData.isNotEmpty) {
                    setState(() {
                      _isScanning = false;
                    });
                    _searchInventory(qrData);
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_scanResult != null)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                            children: [
    // === ẢNH SẢN PHẨM - FIX TRIỆT ĐỂ NULL SAFETY ===
Builder(builder: (context) {
  // Copy itemData vào biến local để Dart cho phép promotion
  final Map<String, dynamic>? localItemData = itemData;

  if (localItemData == null) {
    return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
  }

  // Bây giờ Dart sẽ promotion localItemData thành non-null
  final dynamic imagePathValue = localItemData['imagePath'];

  if (imagePathValue is! String || imagePathValue.toString().trim().isEmpty) {
    return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
  }

  final String imageUrl = '${AppConfig.baseUrl}${imagePathValue.toString().trim()}';

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      imageUrl,
      width: 200,
      height: 200,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.teal),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
      },
    ),
  );
}),
    const SizedBox(height: 20),

                                // === THÔNG TIN TEXT ===
                                SelectableText(
                                  _scanResult!,
                                  style: const TextStyle(fontSize: 18, color: Colors.black87),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isScanning = true;
                          _scanResult = null;
                          itemData = null; // Reset ảnh
                        });
                        cameraController.start();
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Quét lại', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

  // ================== TRANG CẬP NHẬT QR - CHỈ XEM TỒN KHO, ẢNH & XEM QR ==================
class QRUpdateScreen extends StatefulWidget {
  const QRUpdateScreen({super.key});

  @override
  State<QRUpdateScreen> createState() => _QRUpdateScreenState();
}

class _QRUpdateScreenState extends State<QRUpdateScreen> {
  List<Map<String, String>> inventoryList = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _vperiodController = TextEditingController();

  String get baseUrl => AppConfig.baseUrl;

  List<Map<String, String>> get filteredList {
    final query = _searchController.text.toLowerCase().trim();
    return inventoryList.where((item) {
      final String ivcode = item['Ivcode'] ?? '';
      final String iname = item['iname'] ?? '';
      return ivcode.toLowerCase().contains(query) || iname.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    if (baseUrl.isEmpty) {
      EasyLoading.showError('Chưa đăng nhập hoặc mất kết nối server');
      return;
    }

    final vperiod = _vperiodController.text.trim();
    final search = _searchController.text.trim();

    var url = '$baseUrl/api/inventory';
    if (vperiod.isNotEmpty || search.isNotEmpty) {
      final uri = Uri.parse(url).replace(queryParameters: {
        if (vperiod.isNotEmpty) 'vperiod': vperiod,
        if (search.isNotEmpty) 'search': search,
      });
      url = uri.toString();
    }

    EasyLoading.show(status: 'Đang tải dữ liệu tồn kho...');
    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        setState(() {
          inventoryList = rawData.map<Map<String, String>>((item) => {
                'Ivcode': item['ivcode']?.toString().trim() ?? '',
                'rvc': item['rvc']?.toString().trim() ?? '',
                'rvcname': item['rvcname']?.toString().trim() ?? '',
                'iname': item['iname']?.toString().trim() ?? 'Sản phẩm ${item['ivcode']}',
                'Vend': item['vend']?.toString() ?? '0',
                'Vperiod': item['vperiod']?.toString() ?? '',
                'unit': item['unit']?.toString().trim() ?? 'Cái',
                'imagePath': item['imagePath']?.toString().trim() ?? '',
              }).toList();

          // Tự động điền kỳ mới nhất nếu chưa có
          if (inventoryList.isNotEmpty && _vperiodController.text.trim().isEmpty) {
            final validPeriods = inventoryList
                .map((e) => e['Vperiod']?.trim())
                .where((p) => p != null && p.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();

            if (validPeriods.isNotEmpty) {
              validPeriods.sort((a, b) => b.compareTo(a));
              _vperiodController.text = validPeriods.first;
            }
          }
        });
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      EasyLoading.showError('Không thể tải dữ liệu: $e');
      // Dữ liệu mẫu khi lỗi
      setState(() {
        inventoryList = [
          {'Ivcode': 'IV001', 'iname': 'iPhone 15 Pro Max', 'Vend': '25', 'unit': 'Cái', 'rvcname': 'Kho Hà Nội', 'imagePath': ''},
          {'Ivcode': 'IV002', 'iname': 'MacBook Pro M3', 'Vend': '8', 'unit': 'Cái', 'rvcname': 'Kho TP.HCM', 'imagePath': ''},
        ];
      });
    } finally {
      EasyLoading.dismiss();
      setState(() => isLoading = false);
    }
  }

  void _showQRDialog(String ivcode, String iname, String vend) {
    final String qrData = 'HPAPP:$ivcode';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mã QR - $iname'),
        content: SizedBox(
          width: 300,
          height: 420,
          child: Column(
            children: [
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
              const SizedBox(height: 20),
              Text('Mã hàng: $ivcode', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Tồn kho: $vend cái', style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 10),
              const Text('Quét bằng bất kỳ ứng dụng QR nào', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xem tồn kho & Ảnh sản phẩm'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm Ivcode hoặc tên sản phẩm...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _vperiodController,
                        decoration: InputDecoration(
                          hintText: 'Vperiod',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _loadInventory,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới danh sách'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size.fromHeight(50)),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? const Center(child: Text('Không có dữ liệu', style: TextStyle(fontSize: 18)))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                          dataRowMinHeight: 80,
                          dataRowMaxHeight: 80,
                          columns: const [
                            DataColumn(label: Text('Mã hàng', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Tên sản phẩm', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Đơn vị', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Tồn kho', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Ảnh', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('QR', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: () {
                            final Map<String, List<Map<String, String>>> groupedByRvc = {};
                            for (var item in filteredList) {
                              final rvcKey = item['rvcname']?.trim().isNotEmpty == true
                                  ? item['rvcname']!.trim()
                                  : (item['rvc']?.trim() ?? 'Kho không xác định');
                              groupedByRvc.putIfAbsent(rvcKey, () => []);
                              groupedByRvc[rvcKey]!.add(item);
                            }

                            final sortedKeys = groupedByRvc.keys.toList()..sort();
                            List<DataRow> allRows = [];

                            for (var rvcName in sortedKeys) {
                              final items = groupedByRvc[rvcName]!;

                              allRows.add(
                                DataRow(
                                  color: WidgetStateProperty.all(Colors.teal.shade700),
                                  cells: [
                                    DataCell(Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Text('KHO: $rvcName',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white)),
                                    )),
                                    const DataCell(SizedBox()),
                                    const DataCell(SizedBox()),
                                    DataCell(Text(
                                      'Tổng tồn: ${items.fold<int>(0, (sum, e) => sum + (int.tryParse(e['Vend'] ?? '0') ?? 0))} cái',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                    )),
                                    const DataCell(SizedBox()),
                                    const DataCell(SizedBox()),
                                  ],
                                ),
                              );

                              for (var item in items) {
                                final String ivcode = item['Ivcode'] ?? '';
                                final String iname = item['iname'] ?? 'Sản phẩm $ivcode';
                                final String vend = item['Vend'] ?? '0';

                                allRows.add(
                                  DataRow(
                                    cells: [
                                      DataCell(Text(ivcode)),
                                      DataCell(Text(iname)),
                                      DataCell(Text(item['unit'] ?? 'Cái',
                                          style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600))),
                                      DataCell(Text(vend, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                      DataCell(
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade400),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: item['imagePath']?.isNotEmpty == true
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(
                                                    '${AppConfig.baseUrl}${item['imagePath']}',
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context, child, progress) => progress == null
                                                        ? child
                                                        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                    errorBuilder: (_, _, _) => const Icon(Icons.image, size: 40, color: Colors.grey),
                                                  ),
                                                )
                                              : const Center(
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                                      Text('Chưa có', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      ),
                                      DataCell(
                                        GestureDetector(
                                          onTap: () => _showQRDialog(ivcode, iname, vend),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade100,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.teal),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.qr_code_scanner, color: Colors.teal, size: 20),
                                                SizedBox(width: 8),
                                                Text('Xem QR', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            }
                            return allRows;
                          }(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vperiodController.dispose();
    super.dispose();
  }
}
  // ================== TRANG SALE ORDER (GIỮ NGUYÊN ĐẸP, CÓ ẢNH) ==================
  class SaleOrderScreen extends StatefulWidget {
    const SaleOrderScreen({super.key});

    @override
    State<SaleOrderScreen> createState() => _SaleOrderScreenState();
  }

  class _SaleOrderScreenState extends State<SaleOrderScreen> {
    final List<Map<String, dynamic>> products = [
      {
        'name': 'iPhone 15 Pro Max',
        'price': 34990000,
        'description': 'Thiết kế titanium cao cấp, chip A17 Pro mạnh mẽ, camera 48MP với zoom quang học 5x. Màn hình Super Retina XDR 6.7 inch.',
        'imagePath': 'assets/images/hp123.jpg', // Đổi thành tên file ảnh thật của bạn
      },
      {
        'name': 'MacBook Pro M3',
        'price': 52990000,
        'description': 'Màn hình Liquid Retina XDR 14 inch, chip M3 Pro siêu nhanh, pin lên đến 22 giờ sử dụng. Thiết kế nhôm nguyên khối.',
        'imagePath': 'assets/images/hp123.jpg',
      },
      {
        'name': 'Apple Watch Ultra 2',
        'price': 21990000,
        'description': 'Vỏ titanium cao cấp, màn hình sáng nhất từ trước đến nay, tính năng lặn sâu chuyên nghiệp, GPS chính xác cao.',
        'imagePath': 'assets/images/hp123.jpg',
      },
      {
        'name': 'AirPods Pro 2',
        'price': 6990000,
        'description': 'Chống ồn chủ động tốt nhất thế giới, âm thanh không gian cá nhân hóa, chip H2 thế hệ mới, sạc không dây.',
        'imagePath': 'assets/images/hp123.jpg',
      },
      {
        'name': 'Luxury Leather Bag',
        'price': 15900000,
        'description': 'Túi xách da thật 100% cao cấp, thiết kế sang trọng tinh tế, phù hợp mọi dịp từ công sở đến dạo phố.',
        'imagePath': 'assets/images/hp123.jpg',
      },
      {
        'name': 'Premium Sunglasses',
        'price': 8900000,
        'description': 'Kính râm polarized chống tia UV 100%, khung titanium siêu nhẹ và bền bỉ, thiết kế thời trang cao cấp.',
        'imagePath': 'assets/images/hp123.jpg',
      },
    ];

    late Map<String, dynamic> selectedProduct;

    @override
    void initState() {
      super.initState();
      selectedProduct = products[0];
    }

    void _selectProduct(Map<String, dynamic> product) {
      setState(() {
        selectedProduct = product;
      });
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: Column(
          children: [
            Expanded(
              flex: 7,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                        child: Image.asset(
                          selectedProduct['imagePath'],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
                                  Text('Không tìm thấy ảnh', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedProduct['name'],
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${selectedProduct['price'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} ₫',
                              style: const TextStyle(fontSize: 28, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  selectedProduct['description'],
                                  style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black87),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected = product == selectedProduct;

                    return GestureDetector(
                      onTap: () => _selectProduct(product),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.teal : Colors.transparent,
                            width: isSelected ? 4 : 2,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            product['imagePath'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(child: Icon(Icons.error, color: Colors.red));
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
 // ================== TRANG THIẾT LẬP - QUẢN LÝ ẢNH + TẠO QR ==================
class ImageManagerScreen extends StatefulWidget {
  const ImageManagerScreen({super.key});

  @override
  State<ImageManagerScreen> createState() => _ImageManagerScreenState();
}

class _ImageManagerScreenState extends State<ImageManagerScreen> {
  List<Map<String, String>> inventoryList = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _vperiodController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    if (baseUrl.isEmpty) {
      EasyLoading.showError('Chưa đăng nhập');
      return;
    }

    final vperiod = _vperiodController.text.trim();
    final search = _searchController.text.trim();

    var url = '$baseUrl/api/inventory';
    if (vperiod.isNotEmpty || search.isNotEmpty) {
      final uri = Uri.parse(url).replace(queryParameters: {
        if (vperiod.isNotEmpty) 'vperiod': vperiod,
        if (search.isNotEmpty) 'search': search,
      });
      url = uri.toString();
    }

    EasyLoading.show(status: 'Đang tải...');
    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        setState(() {
          inventoryList = rawData.map<Map<String, String>>((item) => {
                'Ivcode': item['ivcode']?.toString().trim() ?? '',
                'iname': item['iname']?.toString().trim() ?? 'Sản phẩm ${item['ivcode']}',
                'Vend': item['vend']?.toString() ?? '0',
                'imagePath': item['imagePath']?.toString().trim() ?? '',
                'Vperiod': item['vperiod']?.toString() ?? '',
              }).toList();

          if (inventoryList.isNotEmpty && _vperiodController.text.trim().isEmpty) {
            final periods = inventoryList
                .map((e) => e['Vperiod']?.trim())
                .where((p) => p != null && p.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();
            if (periods.isNotEmpty) {
              periods.sort((a, b) => b.compareTo(a));
              _vperiodController.text = periods.first;
            }
          }
        });
      }
    } catch (e) {
      EasyLoading.showError('Lỗi tải dữ liệu: $e');
    } finally {
      EasyLoading.dismiss();
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(String ivcode) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    EasyLoading.show(status: 'Đang tải ảnh lên...');

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/inventory/upload-image'));
      request.fields['ivcode'] = ivcode;
      request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      EasyLoading.dismiss();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _loadInventory(); // Refresh lại danh sách
          EasyLoading.showSuccess('Upload ảnh thành công cho $ivcode!');
        } else {
          EasyLoading.showError(data['message'] ?? 'Upload thất bại');
        }
      } else {
        EasyLoading.showError('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('Lỗi: $e');
    }
  }

  void _showQRDialog(String ivcode, String iname, String vend) {
    final String qrData = 'HPAPP:$ivcode';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mã QR - $iname'),
        content: SizedBox(
          width: 300,
          height: 420,
          child: Column(
            children: [
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
              const SizedBox(height: 20),
              Text('Mã hàng: $ivcode', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Tồn kho: $vend cái', style: const TextStyle(color: Colors.green)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }

  Future<void> _generateBatchQR() async {
  // Sửa phần parse tồn kho: loại bỏ dấu chấm
  final ivcodes = inventoryList.where((item) {
    String vendStr = item['Vend'] ?? '0';
    vendStr = vendStr.replaceAll('.', '').replaceAll(',', ''); // Loại bỏ dấu . và ,
    final vend = int.tryParse(vendStr) ?? 0;
    return vend > 0;
  }).map((item) => item['Ivcode']!).toList();

  if (ivcodes.isEmpty) {
    EasyLoading.showInfo('Không có sản phẩm nào có tồn kho > 0');
    return;
  }

  // Thêm xác nhận để chắc chắn
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tạo QR hàng loạt'),
      content: Text('Tạo QR cho ${ivcodes.length} sản phẩm có tồn kho?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Tạo ngay', style: TextStyle(color: Colors.teal)),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  EasyLoading.show(status: 'Đang tạo QR hàng loạt...');

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/inventory/generate-batch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'ivcodes': ivcodes,
        'createdBy': 'MobileApp',
      }),
    );

    final data = jsonDecode(response.body);
    EasyLoading.dismiss();

    if (response.statusCode == 200 && data['success'] == true) {
      final count = data['count'] ?? ivcodes.length;
      EasyLoading.showSuccess('Tạo thành công $count QR code!');
    } else {
      EasyLoading.showError(data['message'] ?? 'Tạo QR thất bại');
    }
  } catch (e) {
    EasyLoading.dismiss();
    EasyLoading.showError('Lỗi: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết lập: Ảnh & QR'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2, size: 28),
            tooltip: 'Tạo QR hàng loạt',
            onPressed: _generateBatchQR,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm mã hàng hoặc tên SP...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (_) => _loadInventory(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadInventory,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : inventoryList.isEmpty
                    ? const Center(child: Text('Không có dữ liệu', style: TextStyle(fontSize: 18)))
                    : ListView.builder(
                        itemCount: inventoryList.length,
                        itemBuilder: (context, index) {
                          final item = inventoryList[index];
                          final ivcode = item['Ivcode'] ?? '';
                          final iname = item['iname'] ?? '';
                          final vend = item['Vend'] ?? '0';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 6,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Ảnh hiện tại
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: item['imagePath']?.isNotEmpty == true
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              '${AppConfig.baseUrl}${item['imagePath']}',
                                              fit: BoxFit.cover,
                                              loadingBuilder: (_, child, progress) => progress == null
                                                  ? child
                                                  : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                              errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                            ),
                                          )
                                        : const Center(
                                            child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Thông tin
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ivcode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        Text(iname, style: const TextStyle(fontSize: 16)),
                                        Text('Tồn kho: $vend cái', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  // Các nút hành động
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => _pickAndUploadImage(ivcode),
                                        icon: const Icon(Icons.upload, size: 18),
                                        label: const Text('Ảnh'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          minimumSize: const Size(100, 40),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => _showQRDialog(ivcode, iname, vend),
                                        icon: const Icon(Icons.qr_code, size: 18),
                                        label: const Text('QR'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(100, 40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _vperiodController.dispose();
    super.dispose();
  }
}