import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // Thêm package này vào pubspec.yaml: mobile_scanner: ^5.1.1

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
  final _ipController = TextEditingController(text: '10.0.2.2');
  final _portController = TextEditingController(text: '5107');

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
    final port = _portController.text.trim();
    if (ip.isNotEmpty && port.isNotEmpty) {
      apiUrl = 'http://$ip:$port/api/login';
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
        // Lưu base URL để dùng cho các API khác
        AppConfig.baseUrl = 'http://${_ipController.text.trim()}:${_portController.text.trim()}';

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
            'Kiểm tra:\n'
            '- IP và Port đúng chưa?\n'
            '- Server .NET đang chạy?\n'
            '- Mạng ổn định?\n'
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
              shadowColor: Colors.black45,
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
                      'HuyPhan App',
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
                        hintText: 'Ví dụ: 5107',
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
        ],
      ),
    );
  }
}

// ================== TRANG QUÉT QR - ĐÃ HOÀN CHỈNH VỚI CHUYỂN CAMERA ==================
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
          final item = data['data'];
          setState(() {
            _scanResult = 
                'Mã hàng: ${item['ivcode']}\n'
                'Tên SP: ${item['iname']}\n'
                'Tên SP: ${item['IName'] ?? 'Không có tên'}\n'
                'Tồn kho: ${item['vend']} cái';
          });
        } else {
          setState(() {
            _scanResult = data['message'] ?? 'Không tìm thấy sản phẩm';
          });
        }
      } else {
        setState(() {
          _scanResult = 'Lỗi server: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _scanResult = 'Lỗi kết nối: $e';
      });
    }
  } else {
    setState(() {
      _scanResult = 'QR không hợp lệ\n(Yêu cầu định dạng: HPAPP:mã_hàng)';
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_scanResult != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(
                        _scanResult!,
                        style: const TextStyle(fontSize: 18, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isScanning = true;
                        _scanResult = null;
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

// ================== TRANG CẬP NHẬT QR - MỚI ==================
class QRUpdateScreen extends StatefulWidget {
  const QRUpdateScreen({super.key});

  @override
  State<QRUpdateScreen> createState() => _QRUpdateScreenState();
}

class _QRUpdateScreenState extends State<QRUpdateScreen> {
  List<Map<String, dynamic>> inventoryList = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _vperiodController = TextEditingController(); // Thêm controller cho Vperiod

  String get baseUrl => AppConfig.baseUrl;

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

    debugPrint('>>> GỌI API INVENTORY: $url');

    EasyLoading.show(status: 'Đang tải dữ liệu tồn kho...');
    setState(() => isLoading = true);

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      debugPrint('>>> STATUS CODE: ${response.statusCode}');    
      debugPrint('>>> RESPONSE BODY: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        setState(() {
          inventoryList = rawData.map((item) => {
            'Ivcode': item['ivcode']?.toString().trim() ?? '',
            'iname': item['iname']?.toString().trim() ?? 'Sản phẩm ${item['ivcode']?.toString().trim() ?? 'Unknown'}',
            'Vend': item['vend']?.toString() ?? '0',
            'QRBarcode': '',
            'Vperiod': item['vperiod']?.toString() ?? '', // Thêm Vperiod nếu có từ server
          }).toList();

          // Lọc tồn kho > 0
          inventoryList = inventoryList.where((item) {
            final double vend = double.tryParse(item['Vend'] ?? '0') ?? 0;
            return vend > 0;
          }).toList();
        });
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('>>> LỖI KHI GỌI API: $e');
      EasyLoading.showError('Không thể tải dữ liệu: $e');
      // Dữ liệu mẫu
      setState(() {
        inventoryList = [
          {'Ivcode': 'IV001', 'Iname': 'iPhone 15 Pro Max', 'Vend': '25', 'QRBarcode': '', 'Vperiod': '2023-01'},
          {'Ivcode': 'IV002', 'Iname': 'MacBook Pro M3', 'Vend': '8', 'QRBarcode': '', 'Vperiod': '2023-02'},
          {'Ivcode': 'IV003', 'Iname': 'Apple Watch Ultra 2', 'Vend': '15', 'QRBarcode': '', 'Vperiod': '2023-03'},
          {'Ivcode': 'IV004', 'Iname': 'AirPods Pro 2', 'Vend': '42', 'QRBarcode': '', 'Vperiod': '2023-04'},
          {'Ivcode': 'IV005', 'Iname': 'Luxury Leather Bag', 'Vend': '3', 'QRBarcode': '', 'Vperiod': '2023-05'},
        ];
      });
    } finally {
      EasyLoading.dismiss();
      setState(() => isLoading = false);
    }
  }

  void _showQRDialog(String ivcode, String iname, String vend) {
    final String qrData = 'HPAPP:$ivcode'; // Giữ nguyên format

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
    final filteredList = inventoryList.where((item) {
  final query = _searchController.text.toLowerCase().trim();
  final String ivcode = (item['Ivcode'] as String?)?.toLowerCase() ?? '';
  final String iname = (item['iname'] as String?)?.toLowerCase() ?? ''; // ← sửa ở đây
  return ivcode.contains(query) || iname.contains(query);
}).toList();

    return Column(
      children: [
        // Search + Vperiod + Refresh
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
                label: const Text('Làm mới'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
            ],
          ),
        ),

        // Bảng dữ liệu
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredList.isEmpty
                  ? const Center(child: Text('Không có dữ liệu', style: TextStyle(fontSize: 18)))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                        columns: const [
                          DataColumn(label: Text('Ivcode', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Iname', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Vend (Tồn)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Vperiod', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('QR/Barcode', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredList.map((item) {
                          final String ivcode = item['Ivcode'] ?? '';
                          final String iname = item['iname'] ?? 'Sản phẩm $ivcode';
                          final String vend = item['Vend'] ?? '0';
                          final String vperiod = item['Vperiod'] ?? '';

                          return DataRow(
                            cells: [
                              DataCell(Text(ivcode)),
                              DataCell(Text(iname)),
                              DataCell(Text(vend, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                              DataCell(Text(vperiod)),
                              DataCell(
                                GestureDetector(
                                  onTap: () => _showQRDialog(ivcode, item['iname']?.toString().trim() ?? iname, vend),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.teal),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.qr_code, color: Colors.teal, size: 20),
                                        SizedBox(width: 8),
                                        Text('Tạo QR', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
        ),
      ],
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