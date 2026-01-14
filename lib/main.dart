import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:async';





// Global lưu base URL sau khi login thành công
class AppConfig {
  static String baseUrl = '';
}

// ignore_for_file: avoid_print

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Bắt buộc cho async trong main

  

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

String buildImageUrl(String? imagePath) {
  if (imagePath == null || imagePath.trim().isEmpty) {
    return '';
  }
  String path = imagePath.trim();
  String base = AppConfig.baseUrl;
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  if (path.startsWith('/')) {
    return '$base$path';
  } else {
    return '$base/$path';
  }
}

// ================== TRANG ĐĂNG NHẬP ==================
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
    if (ip.isEmpty) return;
    String base;
    if (ip.startsWith('http://') || ip.startsWith('https://')) {
      base = ip;
    } else {
      if (ip == '10.0.2.2' ||
          ip == '127.0.0.1' ||
          ip == 'localhost' ||
          ip.contains('192.168.') ||
          ip.contains('172.') ||
          ip.contains('10.')) {
        base = portText.isNotEmpty ? 'http://$ip:$portText' : 'http://$ip:5167';
      } else {
        base = portText.isNotEmpty ? 'http://$ip:$portText' : 'https://$ip';
      }
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    apiUrl = '$base/api/login';
    AppConfig.baseUrl = base;
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
        'ClerkID': clerkId,
        'SecurityCode': securityCode,
      }),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      // Đảm bảo baseUrl đã được set (gọi lại để chắc chắn)
      _updateApiUrl();

      if (!mounted) return;  // Tránh dùng context khi widget đã dispose

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainMenuScreen()),
      );
    } else {
      setState(() {
        _errorMessage = data['message'] ?? 'Đăng nhập thất bại';
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Lỗi kết nối: $e';
    });
  } finally {
    if (mounted) {  // Chỉ setState nếu widget còn sống
      setState(() => _isLoading = false);
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
            colors: [Color.fromARGB(255, 184, 230, 236), Color.fromARGB(255, 191, 220, 224), Color.fromARGB(255, 193, 214, 217)],
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
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 6),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10)),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.lock_person_rounded, size: 80, color: Colors.teal);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text('Huy Phan', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.teal, letterSpacing: 1.2)),
                      const Text('Đăng Nhập Hệ Thống', style: TextStyle(fontSize: 20, color: Color.fromARGB(255, 173, 219, 214), fontWeight: FontWeight.w500)),
                      // ← THÊM NÚT NÀY
const SizedBox(height: 25),
SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    },
    icon: const Icon(Icons.sports_soccer, size: 28, color: Colors.white),
    label: const Text(
      '🎮 Chơi Ném Bóng Vào Ly Để Vào App!',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.orangeAccent.shade700,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      elevation: 10,
    ),
  ),
),
// Trong build() của LoginScreen, thêm nút này (ví dụ ngay dưới nút ném bóng)
const SizedBox(height: 16),
SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MazeGameScreen()),
      );
    },
    icon: const Icon(Icons.route, size: 28, color: Colors.white),
    label: const Text(
      '🎮 Chơi Mê Cung Để Vào App!',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.purpleAccent.shade700,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      elevation: 10,
    ),
  ),
),
                      const SizedBox(height: 40),
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
                        style: const TextStyle(color: Color.fromARGB(255, 219, 152, 152), fontSize: 16),
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

// ================== TRANG HOME ==================
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
                child: Image.asset('assets/images/app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront_rounded, size: 90, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 50),
            const Text('Chào mừng trở lại!', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            const Text('Huy Phan App',
                style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(offset: Offset(0, 4), blurRadius: 12, color: Colors.black38)])),
            const SizedBox(height: 20),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text('Hệ thống quản lý hàng hóa bằng QR Code',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 19, color: Colors.white, height: 1.6))),
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

// ================== MENU CHÍNH VỚI SUBMENU ==================
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
      const HomeScreen(),
      const SaleOrderScreen(),
      const QRScanScreen(),
      const QRUpdateMenuScreen(),
      const ImageManagerScreen(),
      const PhysicalInventoryScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
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
                        child: const Text('Đăng xuất', style: TextStyle(color: Colors.red))),
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
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Kiểm kê VL'),
        ],
      ),
    );
  }
}

// ================== MÀN HÌNH CẬP NHẬT QR - BÂY GIỜ DÙNG TAB GIỐNG THIẾT LẬP ==================
class QRUpdateMenuScreen extends StatefulWidget {
  const QRUpdateMenuScreen({super.key});

  @override
  State<QRUpdateMenuScreen> createState() => _QRUpdateMenuScreenState();
}

class _QRUpdateMenuScreenState extends State<QRUpdateMenuScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cập nhật QR'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Hàng hóa'),
            Tab(icon: Icon(Icons.account_balance), text: 'Tài sản & CCDC'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          InventoryCheckScreen(),  // Tab 1: Kiểm kê Hàng hóa
          AssetCheckScreen(),      // Tab 2: Kiểm kê Tài sản & CCDC
        ],
      ),
    );
  }
}

// ================== KIỂM KÊ HÀNG HÓA ==================
class InventoryCheckScreen extends StatefulWidget {
  const InventoryCheckScreen({super.key});

  @override
  State<InventoryCheckScreen> createState() => _InventoryCheckScreenState();
}

class _InventoryCheckScreenState extends State<InventoryCheckScreen> {
  List<Map<String, String>> inventoryList = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _vperiodController = TextEditingController();
  String get baseUrl => AppConfig.baseUrl;
  
  Set<String> _viewedIvCodes = {}; // Danh sách Ivcode đã xem

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
    _loadViewedCodes();
  }
// Load danh sách mã đã xem từ SharedPreferences
  Future<void> _loadViewedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final viewedList = prefs.getStringList('viewed_ivcodes') ?? [];
    setState(() {
      _viewedIvCodes = viewedList.toSet();
    });
  }
  Future<void> _markAsViewed(String ivcode) async {
    if (_viewedIvCodes.contains(ivcode)) return;

    setState(() {
      _viewedIvCodes.add(ivcode);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('viewed_ivcodes', _viewedIvCodes.toList());
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
                'Ivcode': item['code']?.toString().trim() ?? '',
                'iname': item['name']?.toString().trim() ?? 'Sản phẩm không tên',
                'Vend': item['quantity']?.toString() ?? '0',
                'rvc': item['locationCode']?.toString().trim() ?? '',
                'rvcname': item['locationName']?.toString().trim() ?? '',
                'unit': item['unit']?.toString().trim() ?? 'Cái',
                'imagePath': item['imagePath']?.toString().trim() ?? '',
                'Vperiod': item['period']?.toString() ?? '',
              }).toList();
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
              QrImageView(data: qrData, version: QrVersions.auto, size: 250, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.H),
              const SizedBox(height: 20),
              Text('Mã hàng: $ivcode', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Tồn kho: $vend cái', style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 10),
              const Text('Quét bằng bất kỳ ứng dụng QR nào', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
      ),
    );
  }
String formatCleanQty(dynamic qty) {
  if (qty == null || qty == 0) return '0';
  String str = qty.toString().replaceAll(',', ''); // Loại bỏ dấu phẩy cũ nếu có
  double? num = double.tryParse(str);
  if (num == null) return '0';
  if (num == num.round()) return num.round().toString(); // Nếu nguyên → không thập phân
  return num.toStringAsFixed(2).replaceAll('.', ','); // Hiển thị với dấu phẩy (Việt Nam)
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                            DataColumn(label: Text('VPeriod', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('LocationCode', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('LocationName', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Ảnh', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('QR', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filteredList.map((item) {
                            final String ivcode = item['Ivcode'] ?? '';
                            final String iname = item['iname'] ?? 'Sản phẩm $ivcode';
                            final String vend = item['Vend'] ?? '0';
                            // Kiểm tra xem mã này đã xem chưa
                            final bool isNew = !_viewedIvCodes.contains(ivcode);
                            return DataRow(
    // Khi tap dòng → đánh dấu đã xem
    onSelectChanged: (selected) {
      if (selected == true && isNew) {
        _markAsViewed(ivcode);
        setState(() {}); // Cập nhật UI ngay
      }
    },
    cells: [
      // Chỉ 1 cell cho cột "Mã hàng" (text + badge chồng lên)
      DataCell(
        Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              ivcode,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (isNew)
              Positioned(
                right: -12,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Mới',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
                                
                                DataCell(Text(iname)),
                                DataCell(Text(item['unit'] ?? 'Cái', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600))),
                                DataCell(Text(formatCleanQty(item['Vend']), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                DataCell(Text(item['Vperiod'] ?? '', style: const TextStyle(fontSize: 14))),
                                DataCell(Text(item['rvc'] ?? '', style: const TextStyle(fontSize: 14))),
                                DataCell(Text(item['rvcname'] ?? '', style: const TextStyle(fontSize: 14))),
                                DataCell(
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
                                    child: item['imagePath']?.isNotEmpty == true
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              buildImageUrl(item['imagePath']),
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                                      decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.teal)),
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
                            );
                          }).toList(),
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

// ================== KIỂM KÊ TÀI SẢN & CCDC ==================
class AssetCheckScreen extends StatefulWidget {
  const AssetCheckScreen({super.key});

  @override
  State<AssetCheckScreen> createState() => _AssetCheckScreenState();
}

class _AssetCheckScreenState extends State<AssetCheckScreen> {
  List<Map<String, String>> assetList = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String get baseUrl => AppConfig.baseUrl;

  List<Map<String, String>> get filteredList {
    final query = _searchController.text.toLowerCase().trim();
    return assetList.where((item) {
      final String code = item['AssetClassCode'] ?? '';
      final String name = item['AssetClassName'] ?? '';
      final String dept = item['DepartmentCode'] ?? '';
      return code.toLowerCase().contains(query) ||
             name.toLowerCase().contains(query) ||
             dept.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (baseUrl.isEmpty) {
      EasyLoading.showError('Chưa đăng nhập hoặc mất kết nối server');
      return;
    }
    EasyLoading.show(status: 'Đang tải dữ liệu tài sản...');
    setState(() => isLoading = true);
    try {
      print('URL gọi: $baseUrl/api/asset');
      final response = await http.get(Uri.parse('$baseUrl/api/asset')).timeout(const Duration(seconds: 30));
      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        print('Decoded type: ${decoded.runtimeType}');

        if (decoded is List) {
          final List<dynamic> rawData = decoded;
          if (rawData.isEmpty) {
            EasyLoading.showInfo('Danh sách tài sản rỗng');
          }
          setState(() {
            assetList = rawData.map<Map<String, String>>((item) => {
                  'AssetClassCode': item['assetClassCode']?.toString().trim() ?? '',
                  'AssetClassName': item['assetClassName']?.toString().trim() ?? 'Không tên',
                  'DepartmentCode': item['departmentCode']?.toString().trim() ?? '',
                  'LocationCode': item['locationCode']?.toString().trim() ?? '',
                  'SlvgQty': item['slvgQty']?.toString() ?? '0',
                  'PhisLoc': item['phisLoc']?.toString().trim() ?? '',
                  'PhisUser': item['phisUser']?.toString().trim() ?? '',
                  'imagePath': item['imagePath']?.toString().trim() ?? '',
                }).toList();
          });
        } else {
          throw Exception('Dữ liệu không phải danh sách');
        }
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      print('Lỗi catch: $e');
      EasyLoading.showError('Không thể tải dữ liệu: $e');
      setState(() {
        assetList = [];
      });
    } finally {
      EasyLoading.dismiss();
      setState(() => isLoading = false);
    }
  }

  void _showQRDialog(String code, String name, String qty) {
    final String qrData = 'HPAPP:$code';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mã QR - $name'),
        content: SizedBox(
          width: 300,
          height: 420,
          child: Column(
            children: [
              QrImageView(data: qrData, version: QrVersions.auto, size: 250, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.H),
              const SizedBox(height: 20),
              Text('Mã TS/CCDC: $code', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Số lượng: $qty', style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 10),
              const Text('Quét bằng bất kỳ ứng dụng QR nào', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
      ),
    );
  }
String formatCleanQty(dynamic qty) {
  if (qty == null || qty == 0) return '0';

  // Chuyển thành chuỗi, loại bỏ dấu phẩy (nếu có từ dữ liệu cũ)
  String str = qty.toString().replaceAll(',', '');

  // Nếu không có dấu chấm → trả về nguyên bản (số nguyên)
  if (!str.contains('.')) {
    return str;
  }

  // Tách phần nguyên và thập phân
  final parts = str.split('.');
  final integerPart = parts[0];
  String decimalPart = parts.length > 1 ? parts[1] : '';

  // Nếu phần thập phân toàn 0 → chỉ giữ phần nguyên
  if (decimalPart.replaceAll('0', '').isEmpty) {
    return integerPart;
  }

  // Nếu có thập phân thực → loại bỏ 0 thừa ở cuối, và loại bỏ dấu chấm nếu không còn thập phân
  decimalPart = decimalPart.replaceAll(RegExp(r'0+$'), '');
  if (decimalPart.isEmpty) {
    return integerPart;
  }

  return '$integerPart.$decimalPart';
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm mã, tên, phòng ban...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _loadAssets,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải lại dữ liệu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    minimumSize: const Size.fromHeight(50),
                  ),
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
                          headingRowColor: WidgetStateProperty.all(Colors.deepPurple.shade50),
                          dataRowMinHeight: 80,
                          dataRowMaxHeight: 100,
                          columns: const [
                            DataColumn(label: Text('Mã TS/CCDC', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Tên tài sản', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Phòng ban', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Vị trí', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Số lượng', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Người dùng', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('QR', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filteredList.map((item) {
                            final String code = item['AssetClassCode'] ?? '';
                            final String name = item['AssetClassName'] ?? '';
                            final String qty = item['SlvgQty'] ?? '0';
                            final String dept = item['DepartmentCode'] ?? '';
                            final String loc = item['LocationCode'] ?? item['PhisLoc'] ?? '';
                            final String user = item['PhisUser'] ?? '';
                            return DataRow(
                              cells: [
                                DataCell(Text(code, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(name)),
                                DataCell(Text(dept)),
                                DataCell(Text(loc)),
                                DataCell(Text(formatCleanQty(item['SlvgQty']), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                DataCell(Text(user)),
                                DataCell(
                                  GestureDetector(
                                    onTap: () => _showQRDialog(code, name, qty),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(color: Colors.deepPurple.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.deepPurple)),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.qr_code_scanner, color: Color.fromARGB(255, 141, 105, 202), size: 20),
                                          SizedBox(width: 8),
                                          Text('Xem QR', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ================== TRANG QUÉT QR ==================
class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}
String formatCleanQty(dynamic qty) {
  if (qty == null || qty == 0) return '0';

  // Chuyển thành chuỗi, loại bỏ dấu phẩy (nếu có từ dữ liệu cũ)
  String str = qty.toString().replaceAll(',', '');

  // Nếu không có dấu chấm → trả về nguyên bản (số nguyên)
  if (!str.contains('.')) {
    return str;
  }

  // Tách phần nguyên và thập phân
  final parts = str.split('.');
  final integerPart = parts[0];
  String decimalPart = parts.length > 1 ? parts[1] : '';

  // Nếu phần thập phân toàn 0 → chỉ giữ phần nguyên
  if (decimalPart.replaceAll('0', '').isEmpty) {
    return integerPart;
  }

  // Nếu có thập phân thực → loại bỏ 0 thừa ở cuối, và loại bỏ dấu chấm nếu không còn thập phân
  decimalPart = decimalPart.replaceAll(RegExp(r'0+$'), '');
  if (decimalPart.isEmpty) {
    return integerPart;
  }

  return '$integerPart.$decimalPart';
}
class _QRScanScreenState extends State<QRScanScreen> {
  MobileScannerController cameraController = MobileScannerController(facing: CameraFacing.back, torchEnabled: false);
  bool _isScanning = true;
  String? _scanResult;
  Map<String, dynamic>? itemData;
  String get baseUrl => AppConfig.baseUrl;
  List<Map<String, dynamic>> _multiLocationItems = [];
  String? _scanMessage;

  Future<void> _searchInventory(String qrData) async {
  if (!qrData.startsWith('HPAPP:')) {
    setState(() {
      _scanResult = 'QR không hợp lệ\n(Yêu cầu định dạng: HPAPP:mã_hàng)';
      itemData = null;  
      _multiLocationItems = []; // Thêm biến mới
    });
    return;
  }

  final ivcode = qrData.substring(6).trim();
  setState(() => _scanMessage = 'Đang xử lý mã: $ivcode...');

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/inventory/search'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'QRCode': ivcode}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final List<dynamic> rawList = (data['data'] as List?) ?? [];

        if (rawList.isEmpty) {
          setState(() {
            _scanResult = 'Không tìm thấy sản phẩm với mã $ivcode';
            itemData = null;
            _multiLocationItems = [];
          });
          return;
        }

        // Tính tổng tồn
        double totalQty = 0;
        for (var item in rawList) {
          totalQty += double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        }

        // Chuẩn bị danh sách chi tiết từng kho
        final List<Map<String, dynamic>> locations = rawList.map((item) {
          return {
            'locationCode': item['locationCode']?.toString().trim() ?? '',
            'locationName': item['locationName']?.toString().trim() ?? 'Không xác định',
            'quantity': item['quantity']?.toString() ?? '0',
            'imagePath': item['imagePath']?.toString().trim() ?? '',
          };
        }).toList();

        // Lấy thông tin chung (từ item đầu tiên)
        final firstItem = Map<String, dynamic>.from(rawList[0]);
        setState(() {
          itemData = firstItem;
          _multiLocationItems = locations; // Lưu danh sách kho để hiển thị ListView

          _scanResult = '''
          Mã hàng: ${firstItem['code'] ?? ivcode}
          Tên sản phẩm: ${firstItem['name'] ?? 'Không có tên'}
          TỔNG TỒN TẤT CẢ KHO: ${formatCleanQty(totalQty)}
          Có mặt tại ${rawList.length} kho:
                    '''.trim();

                    _scanMessage = null;
                  });
                } else {
        setState(() {
          _scanResult = data['message'] ?? 'Không tìm thấy sản phẩm';
          itemData = null;
          _multiLocationItems = [];
        });
      }
    } else {
      setState(() {
        _scanResult = 'Lỗi server: ${response.statusCode}';
        itemData = null;
        _multiLocationItems = [];
      });
    }
  } catch (e) {
    setState(() {
      _scanResult = 'Lỗi kết nối: $e';
      itemData = null;
      _multiLocationItems = [];
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
          IconButton(icon: const Icon(Icons.flip_camera_ios), onPressed: _switchCamera, tooltip: 'Chuyển camera'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (_isScanning && barcodes.isNotEmpty) {
                  final qrData = barcodes.first.rawValue ?? '';
                  if (qrData.isNotEmpty) {
                    setState(() => _isScanning = false);
                    _searchInventory(qrData);
                  }
                }
              },
            ),
          ),
          Expanded(
  flex: 3,
  child: SingleChildScrollView(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_scanMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _scanMessage!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (_scanResult != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ảnh sản phẩm (lấy từ item đầu tiên hoặc kho có ảnh)
                      if (itemData != null && itemData!['imagePath']?.toString().trim().isNotEmpty == true)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            buildImageUrl(itemData!['imagePath'].toString().trim()),
                            width: double.infinity,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 100),
                          ),
                        )
                      else
                        const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),

                      const SizedBox(height: 16),

                      // Thông tin chính + tổng tồn
                      SelectableText(
                        _scanResult!,
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),

                      const SizedBox(height: 16),

                      // ListView hiển thị chi tiết từng kho
                      if (_multiLocationItems.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(maxHeight: 180), // Giới hạn chiều cao nếu quá nhiều kho
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _multiLocationItems.length,
                            itemBuilder: (context, index) {
                              final loc = _multiLocationItems[index];
                              final qty = double.tryParse(loc['quantity'] ?? '0') ?? 0;
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.warehouse, color: Colors.teal, size: 28),
                                title: Text(
                                  loc['locationName'] ?? 'Kho không xác định',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                trailing: Text(
                                  '${formatCleanQty(qty)} cái',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: qty > 0 ? Colors.green.shade700 : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Nút quét lại
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isScanning = true;
                            _scanResult = null;
                            itemData = null;
                            _multiLocationItems = [];
                            _scanMessage = null;
                          });
                          cameraController.start();
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Quét lại', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

// ================== TRANG SALE ORDER ==================
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
      'imagePath': 'assets/images/hp123.jpg',
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
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
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
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selectedProduct['name'], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                        border: Border.all(color: isSelected ? Colors.teal : Colors.transparent, width: isSelected ? 4 : 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          product['imagePath'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error, color: Colors.red)),
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

// ================== TRANG THIẾT LẬP - GIỮ NGUYÊN NHƯ CŨ ==================
class ImageManagerScreen extends StatefulWidget {
  const ImageManagerScreen({super.key});

  @override
  State<ImageManagerScreen> createState() => _ImageManagerScreenState();
}

class _ImageManagerScreenState extends State<ImageManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết lập: Ảnh & QR'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Hàng hóa'),
            Tab(icon: Icon(Icons.account_balance), text: 'Tài sản & CCDC'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          InventoryImageManager(),
          AssetImageManager(),
        ],
      ),
    );
  }
}

// ================== TAB 1: HÀNG HÓA TRONG THIẾT LẬP ==================
class InventoryImageManager extends StatefulWidget {
  const InventoryImageManager({super.key});

  @override
  State<InventoryImageManager> createState() => _InventoryImageManagerState();
}

class _InventoryImageManagerState extends State<InventoryImageManager> {
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
                'Ivcode': item['code']?.toString().trim() ?? '',
                'iname': item['name']?.toString().trim() ?? 'Sản phẩm không tên',
                'Vend': item['quantity']?.toString() ?? '0',
                'rvc': item['locationCode']?.toString().trim() ?? '',
                'rvcname': item['locationName']?.toString().trim() ?? '',
                'unit': item['unit']?.toString().trim() ?? 'Cái',
                'imagePath': item['imagePath']?.toString().trim() ?? '',
                'Vperiod': item['period']?.toString() ?? '',
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
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
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
          _loadInventory();
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
              QrImageView(data: qrData, version: QrVersions.auto, size: 250, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.H),
              const SizedBox(height: 20),
              Text('Mã hàng: $ivcode', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Tồn kho: $vend cái', style: const TextStyle(color: Colors.green)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
      ),
    );
  }

  Future<void> _generateBatchQR() async {
    final ivcodes = inventoryList.where((item) {
      String vendStr = item['Vend'] ?? '0';
      vendStr = vendStr.replaceAll('.', '').replaceAll(',', '');
      final vend = int.tryParse(vendStr) ?? 0;
      return vend > 0;
    }).map((item) => item['Ivcode']!).toList();
    if (ivcodes.isEmpty) {
      EasyLoading.showInfo('Không có sản phẩm nào có tồn kho > 0');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo QR hàng loạt'),
        content: Text('Tạo QR cho ${ivcodes.length} sản phẩm có tồn kho?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tạo ngay', style: TextStyle(color: Colors.teal))),
        ],
      ),
    );
    if (confirm != true) return;
    EasyLoading.show(status: 'Đang tạo QR hàng loạt...');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/inventory/generate-batch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Codes': ivcodes, 'createdBy': 'MobileApp'}),
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
    return Column(
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 133, 100, 191)),
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
                                            buildImageUrl(item['imagePath']),
                                            fit: BoxFit.cover,
                                            loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                          ),
                                        )
                                      : const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                                ),
                                const SizedBox(width: 16),
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
                                Column(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _pickAndUploadImage(ivcode),
                                      icon: const Icon(Icons.upload, size: 18),
                                      label: const Text('Ảnh'),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 146, 118, 195), minimumSize: const Size(100, 40)),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _showQRDialog(ivcode, iname, vend),
                                      icon: const Icon(Icons.qr_code, size: 18),
                                      label: const Text('QR'),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 223, 186, 131), foregroundColor: Colors.white, minimumSize: const Size(100, 40)),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _generateBatchQR,
            icon: const Icon(Icons.qr_code_2, size: 28),
            label: const Text('Tạo QR hàng loạt', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 129, 90, 195),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(60),
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

// ================== TAB 2: TÀI SẢN & CCDC TRONG THIẾT LẬP ==================
class AssetImageManager extends StatefulWidget {
  const AssetImageManager({super.key});

  @override
  State<AssetImageManager> createState() => _AssetImageManagerState();
}

class _AssetImageManagerState extends State<AssetImageManager> {
  List<Map<String, String>> assetList = [];
  bool isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String get baseUrl => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    if (baseUrl.isEmpty) {
      EasyLoading.showError('Chưa đăng nhập');
      return;
    }
    EasyLoading.show(status: 'Đang tải danh sách tài sản...');
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/asset')).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final List<dynamic> rawData = jsonDecode(response.body);
        setState(() {
          assetList = rawData.map<Map<String, String>>((item) => {
                'AssetClassCode': item['assetClassCode']?.toString().trim() ?? '',
                'AssetClassName': item['assetClassName']?.toString().trim() ?? 'Không tên',
                'imagePath': item['imagePath']?.toString().trim() ?? '',
              }).toList();
        });
      }
    } catch (e) {
      EasyLoading.showError('Lỗi tải dữ liệu: $e');
    } finally {
      EasyLoading.dismiss();
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(String assetCode) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (pickedFile == null) return;

    EasyLoading.show(status: 'Đang tải ảnh lên...');
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/asset/upload-image'));
      request.fields['assetCode'] = assetCode;
      request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      EasyLoading.dismiss();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _loadAssets();
          EasyLoading.showSuccess('Upload ảnh thành công cho $assetCode!');
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

  Future<void> _generateBatchQR() async {
    final codes = assetList.map((e) => e['AssetClassCode']!).toList();
    if (codes.isEmpty) {
      EasyLoading.showInfo('Không có tài sản nào');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo QR hàng loạt'),
        content: Text('Tạo QR cho ${codes.length} tài sản?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tạo ngay', style: TextStyle(color: Colors.deepPurple))),
        ],
      ),
    );

    if (confirm != true) return;

    EasyLoading.show(status: 'Đang tạo QR...');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/asset/generate-batch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Codes': codes}),
      );
      final data = jsonDecode(response.body);
      EasyLoading.dismiss();
      if (response.statusCode == 200 && data['success'] == true) {
        EasyLoading.showSuccess('Tạo thành công ${data['count'] ?? codes.length} QR!');
      } else {
        EasyLoading.showError(data['message'] ?? 'Lỗi');
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('Lỗi: $e');
    }
  }

  void _showQRDialog(String code, String name) {
    final qrData = 'HPAPP:$code';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mã QR - $name'),
        content: SizedBox(
          width: 300,
          height: 420,
          child: Column(
            children: [
              QrImageView(data: qrData, version: QrVersions.auto, size: 250, backgroundColor: Colors.white),
              const SizedBox(height: 20),
              Text('Mã TS/CCDC: $code', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm mã hoặc tên tài sản...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loadAssets,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 146, 122, 187)),
              ),
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : assetList.isEmpty
                  ? const Center(child: Text('Không có dữ liệu', style: TextStyle(fontSize: 18)))
                  : ListView.builder(
                      itemCount: assetList.length,
                      itemBuilder: (context, index) {
                        final item = assetList[index];
                        final code = item['AssetClassCode'] ?? '';
                        final name = item['AssetClassName'] ?? '';
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 6,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
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
                                            buildImageUrl(item['imagePath']),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                          ),
                                        )
                                      : const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      Text(name, style: const TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _pickAndUploadImage(code),
                                      icon: const Icon(Icons.upload, size: 18),
                                      label: const Text('Ảnh'),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 148, 118, 198), minimumSize: const Size(100, 40)),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: () => _showQRDialog(code, name),
                                      icon: const Icon(Icons.qr_code, size: 18),
                                      label: const Text('QR'),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 208, 173, 121), foregroundColor: Colors.white, minimumSize: const Size(100, 40)),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _generateBatchQR,
            icon: const Icon(Icons.qr_code_2, size: 28),
            label: const Text('Tạo QR hàng loạt', style: TextStyle(fontSize: 18)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(60),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
class PhysicalInventoryScreen extends StatefulWidget {
  const PhysicalInventoryScreen({super.key});

  @override
  State<PhysicalInventoryScreen> createState() => _PhysicalInventoryScreenState();
}

class _PhysicalInventoryScreenState extends State<PhysicalInventoryScreen> {
  final MobileScannerController cameraController = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isScanning = false;
  String? _scanMessage;
  List<Map<String, dynamic>> systemInventory = []; // Từ /api/inventory (Vend)
  List<Map<String, dynamic>> physicalInventory = []; // Từ /api/invphysical/get (Vphis)
  List<Map<String, dynamic>> displayedItems = []; // Danh sách hiển thị sau merge
  List<TextEditingController> physicalControllers = [];

  String selectedVperiod = '';
  String selectedRVC = '';

  String get baseUrl => AppConfig.baseUrl;

  String formatQty(dynamic qty) {
    if (qty == null) return '0';
    final str = qty.toString().replaceAll(',', '').replaceAll('.', '');
    final numVal = int.tryParse(str) ?? 0;
    return numVal.toString(); // 6000000 → "6000000"
  }

  void _clearControllers() {
    for (var controller in physicalControllers) {
      controller.dispose();
    }
    physicalControllers.clear();
  }
String formatCleanQty(dynamic qty) {
  if (qty == null || qty == 0) return '0';

  // Chuyển thành chuỗi, loại bỏ dấu phẩy (nếu có từ dữ liệu cũ)
  String str = qty.toString().replaceAll(',', '');

  // Nếu không có dấu chấm → trả về nguyên bản (số nguyên)
  if (!str.contains('.')) {
    return str;
  }

  // Tách phần nguyên và thập phân
  final parts = str.split('.');
  final integerPart = parts[0];
  String decimalPart = parts.length > 1 ? parts[1] : '';

  // Nếu phần thập phân toàn 0 → chỉ giữ phần nguyên
  if (decimalPart.replaceAll('0', '').isEmpty) {
    return integerPart;
  }

  // Nếu có thập phân thực → loại bỏ 0 thừa ở cuối, và loại bỏ dấu chấm nếu không còn thập phân
  decimalPart = decimalPart.replaceAll(RegExp(r'0+$'), '');
  if (decimalPart.isEmpty) {
    return integerPart;
  }

  return '$integerPart.$decimalPart';
}
  @override
  void initState() {
    super.initState();
    _loadAllData(); // Load cả 2 nguồn khi vào màn hình
  }

  // Load cả tồn hệ thống và kiểm kê đã lưu
  Future<void> _loadAllData() async {
    if (baseUrl.isEmpty) {
      EasyLoading.showError('Chưa đăng nhập hoặc mất kết nối');
      return;
    }

    EasyLoading.show(status: 'Đang tải dữ liệu kiểm kê...');

    try {
      // 1. Load tồn kho hệ thống (Vend)
      final systemResponse = await http.get(Uri.parse('$baseUrl/api/inventory')).timeout(const Duration(seconds: 25));
      if (systemResponse.statusCode != 200) {
        throw Exception('Lỗi tải tồn kho hệ thống');
      }
      final List<dynamic> systemRaw = jsonDecode(systemResponse.body);
      systemInventory = systemRaw.map((e) => Map<String, dynamic>.from(e)).toList();

      // Tự động chọn kỳ mới nhất nếu chưa có
      if (selectedVperiod.isEmpty && systemInventory.isNotEmpty) {
        final periods = systemInventory
            .map((e) => e['period']?.toString().trim() ?? e['Vperiod']?.toString().trim() ?? '')
            .where((p) => p.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
        if (periods.isNotEmpty) {
          selectedVperiod = periods.first;
        }
      }

      // 2. Load dữ liệu kiểm kê đã lưu (Vphis) - theo kỳ/kho đã chọn
      var physicalUrl = '$baseUrl/api/invphysical/get';
      final query = <String, String>{};
      if (selectedVperiod.isNotEmpty) query['vperiod'] = selectedVperiod;
      if (selectedRVC.isNotEmpty) query['rvc'] = selectedRVC;
      if (query.isNotEmpty) {
        physicalUrl += '?${Uri(queryParameters: query).query}';
      }

      final physicalResponse = await http.get(Uri.parse(physicalUrl)).timeout(const Duration(seconds: 25));
      if (physicalResponse.statusCode == 200) {
        final List<dynamic> physicalRaw = jsonDecode(physicalResponse.body);
        physicalInventory = physicalRaw.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        physicalInventory = [];
      }

      // 3. Merge dữ liệu
      _mergeAndDisplay();

      EasyLoading.showSuccess('Đã tải dữ liệu kiểm kê');
    } catch (e) {
      EasyLoading.showError('Lỗi tải dữ liệu: $e');
    }
  }

  // Merge: Ưu tiên Vphis nếu có, nếu không dùng Vend
  void _mergeAndDisplay() {
  setState(() {
    final physicalMap = <String, Map<String, dynamic>>{};
    for (var p in physicalInventory) {
      final key = '${p['ivcode']?.toString().trim()}_${p['rvc']?.toString().trim()}_${p['vperiod']?.toString().trim()}';
      physicalMap[key] = p;
    }

    displayedItems = systemInventory.where((sys) {
      bool match = true;
      if (selectedVperiod.isNotEmpty) {
        match &= (sys['period'] ?? sys['Vperiod'] ?? '') == selectedVperiod;
      }
      if (selectedRVC.isNotEmpty) {
        match &= (sys['locationCode'] ?? sys['rvc'] ?? '') == selectedRVC;
      }
      return match;
    }).map((sys) {
      final key = '${sys['ivcode'] ?? sys['code']?.toString().trim()}_${sys['rvc'] ?? sys['locationCode']?.toString().trim()}_${sys['period'] ?? sys['Vperiod']?.toString().trim()}';
      final phys = physicalMap[key];
      final merged = Map<String, dynamic>.from(sys);
      merged['vphis'] = phys != null ? (phys['vphis'] ?? 0.0) : 0.0;  // Lấy double
      return merged;
    }).toList();

    _clearControllers();
    physicalControllers = displayedItems.map((_) => TextEditingController()).toList();

    for (int i = 0; i < displayedItems.length; i++) {
      final item = displayedItems[i];
      final vphis = double.tryParse(item['vphis']?.toString() ?? '0') ?? 0.0;
      physicalControllers[i].text = formatCleanQty(vphis);  // Hiển thị đẹp (dấu phẩy)
    }
  });
}

  // Khi thay đổi kỳ/kho → reload để merge lại
  void _applyFilter() {
    _loadAllData(); // Reload cả 2 nguồn để đảm bảo đồng bộ
  }

  // Quét QR → tìm trong systemInventory, nếu có thì thêm/merge vào displayedItems
  Future<void> _processScan(String qrData) async {
  if (!qrData.startsWith('HPAPP:')) {
    setState(() => _scanMessage = 'QR không hợp lệ (cần: HPAPP:mã_hàng)');
    return;
  }

  final ivcode = qrData.substring(6).trim();
  setState(() => _scanMessage = 'Đang xử lý mã: $ivcode...');

  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/inventory/search'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'QRCode': ivcode}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      setState(() => _scanMessage = 'Lỗi server: ${response.statusCode}');
      return;
    }

    final data = jsonDecode(response.body);
    if (data['success'] != true || data['data'] == null || (data['data'] as List).isEmpty) {
      setState(() => _scanMessage = 'Không tìm thấy sản phẩm với mã $ivcode');
      return;
    }

    final List<dynamic> rawList = data['data'];

    // Lọc theo kỳ & kho đang chọn
    final filtered = rawList.where((item) {
      bool match = true;
      if (selectedVperiod.isNotEmpty) {
        match &= (item['period']?.toString().trim() ?? item['Vperiod']?.toString().trim() ?? '') == selectedVperiod;
      }
      if (selectedRVC.isNotEmpty) {
        match &= (item['locationCode']?.toString().trim() ?? item['rvc']?.toString().trim() ?? '') == selectedRVC;
      }
      return match;
    }).toList();

    if (filtered.isEmpty) {
      setState(() => _scanMessage = 'Mã $ivcode không thuộc kỳ/kho đang chọn');
      return;
    }

    for (var raw in filtered) {
      final newItem = Map<String, dynamic>.from(raw);

      final code = (newItem['code'] ?? '').toString().trim();
      final rvc = (newItem['locationCode'] ?? newItem['rvc'] ?? '').toString().trim();
      final vperiod = (newItem['period'] ?? newItem['Vperiod'] ?? '').toString().trim();

      // Tìm dòng đã tồn tại
      final index = displayedItems.indexWhere((e) {
        final eCode = (e['code'] ?? e['ivcode'] ?? '').toString().trim();
        final eRvc = (e['locationCode'] ?? e['rvc'] ?? '').toString().trim();
        final eVperiod = (e['period'] ?? e['Vperiod'] ?? '').toString().trim();
        return eCode == code && eRvc == rvc && eVperiod == vperiod;
      });

      if (index != -1) {
        // Đã có → hiện popup chỉnh sửa Vphis
        await _showVphisInputDialog(index, code);
      } else {
        // Chưa có → thêm mới
        setState(() {
          displayedItems.add(newItem);
          physicalControllers.add(TextEditingController());
        });

        // Tự động copy tồn hệ thống (quantity hoặc vend)
        final qtyRaw = newItem['quantity']?.toString() ?? newItem['vend']?.toString() ?? '0';
        final qty = double.tryParse(qtyRaw.replaceAll(',', '.')) ?? 0.0;
        physicalControllers.last.text = formatCleanQty(qty);

        // Lưu ngay batch
        await _saveBatch(displayedItems);
        setState(() => _scanMessage = 'Đã thêm mới $code vào danh sách');
      }
    }

    // Reset message sau 4 giây
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _scanMessage = null);
    });
  } catch (e) {
    setState(() => _scanMessage = 'Lỗi xử lý QR: $e');
  }
}

// Popup nhập/chỉnh sửa Vphis (thêm ảnh nếu có)
Future<void> _showVphisInputDialog(int index, String code) async {
  final ctrl = TextEditingController(text: physicalControllers[index].text.trim());

  final item = displayedItems[index];
  final name = item['name']?.toString().trim() ?? 'Không tên';
  final rvcName = item['locationName']?.toString().trim() ?? item['rvcname']?.toString().trim() ?? item['rvc']?.toString().trim() ?? '---';
  final systemQty = formatCleanQty(item['quantity'] ?? item['vend'] ?? '0');
  final imagePath = item['imagePath']?.toString().trim() ?? '';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Nhập tồn vật lý - $code'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  buildImageUrl(imagePath),
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 100),
                ),
              ),
            if (imagePath.isNotEmpty) const SizedBox(height: 12),
            Text('Tên: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Kho: $rvcName'),
            Text('Tồn hệ thống: $systemQty', style: const TextStyle(color: Colors.blueGrey)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Tồn vật lý (Vphis)',
                border: const OutlineInputBorder(),
                hintText: 'Nhập số lượng thực tế...',
                prefixIcon: const Icon(Icons.inventory),
              ),
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            final val = ctrl.text.trim();
            if (val.isEmpty) {
              EasyLoading.showError('Vui lòng nhập số lượng');
              return;
            }
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );

  if (confirmed == true && mounted) {
    final newVal = ctrl.text.trim();
    setState(() {
      physicalControllers[index].text = newVal;
    });
    await _saveSingle(index);
    setState(() => _scanMessage = 'Đã cập nhật Vphis cho $code');
  }

  ctrl.dispose();
}
  Future<void> _saveBatch(List<dynamic> items, {bool autoCopy = false}) async {
  final List<Map<String, dynamic>> toSave = [];
  for (int i = 0; i < items.length; i++) {
    if (i >= displayedItems.length || i >= physicalControllers.length) continue;

    final item = Map<String, dynamic>.from(items[i]);
    final physStr = physicalControllers[i].text.trim();

    if (physStr.isEmpty && !autoCopy) continue;

    // Parse thập phân: thay dấu phẩy thành dấu chấm
    String normalized = physStr.replaceAll(',', '.');
    double physVend = double.tryParse(normalized) ?? 0.0;

    if (physVend < 0) {
      EasyLoading.showError('Số lượng không được âm');
      continue;
    }

    toSave.add({
      'Ivcode': (item['ivcode'] ?? item['code'] ?? '').trim(),
      'Vend': double.tryParse((item['vend'] ?? item['quantity'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0,
      'Vphis': physVend,  // ← GỬI DOUBLE, KHÔNG ROUND
      'RVC': (item['rvc'] ?? item['locationCode'] ?? '').trim(),
      'Vperiod': (item['Vperiod'] ?? item['period'] ?? '').trim(),
    });
  }

  if (toSave.isEmpty) return;

  EasyLoading.show(status: autoCopy ? 'Tự động copy & lưu...' : 'Đang lưu...');
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/api/invphysical/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'items': toSave}),
    );
    final result = jsonDecode(res.body);
    if (res.statusCode == 200 && result['success'] == true) {
      EasyLoading.showSuccess(
          autoCopy ? 'Đã tự động lưu ${toSave.length} dòng' : 'Lưu thành công ${toSave.length} dòng');
      _loadAllData();  // Reload để hiển thị giá trị mới từ SQL
    } else {
      EasyLoading.showError(result['message'] ?? 'Lưu thất bại');
    }
  } catch (e) {
    EasyLoading.showError('Lỗi: $e');
  }
}

  Future<void> _saveSingle(int index) async {
  if (index >= displayedItems.length || index >= physicalControllers.length) return;
  final item = displayedItems[index];
  final ctrl = physicalControllers[index];
  final physStr = ctrl.text.trim();

  if (physStr.isEmpty) {
    EasyLoading.showError('Vui lòng nhập số lượng vật lý');
    return;
  }

  String normalized = physStr.replaceAll(',', '.');
  double physVend = double.tryParse(normalized) ?? 0.0;

  if (physVend < 0) {
    EasyLoading.showError('Số lượng không được âm');
    return;
  }

  final toSave = [{
    'Ivcode': (item['ivcode'] ?? item['code'] ?? '').trim(),
    'Vend': double.tryParse((item['vend'] ?? item['quantity'] ?? '0').toString().replaceAll(',', '.')) ?? 0.0,
    'Vphis': physVend,  // ← GỬI DOUBLE
    'RVC': (item['rvc'] ?? item['locationCode'] ?? '').trim(),
    'Vperiod': (item['Vperiod'] ?? item['period'] ?? '').trim(),
  }];

  EasyLoading.show(status: 'Đang lưu dòng này...');
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/api/invphysical/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'items': toSave}),
    );
    final result = jsonDecode(res.body);
    if (res.statusCode == 200 && result['success'] == true) {
      EasyLoading.showSuccess('Lưu thành công 1 dòng');
      _loadAllData();  // Reload
    } else {
      EasyLoading.showError(result['message'] ?? 'Lưu thất bại');
    }
  } catch (e) {
    EasyLoading.showError('Lỗi: $e');
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm kê vật lý'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại tồn kho',
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: cameraController.switchCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          // Bộ lọc
         Padding(
  padding: const EdgeInsets.all(12),
  child: Row(
    children: [
      // Dropdown Kỳ (Vperiod)
      Expanded(
        child: DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Kỳ (Vperiod)',
            border: OutlineInputBorder(),
          ),
          initialValue: selectedVperiod.isEmpty ? null : selectedVperiod, // ← Dùng initialValue
          hint: const Text('Chọn kỳ...'),
          isExpanded: true,
          items: systemInventory
              .map((e) => e['period']?.toString().trim() ?? e['Vperiod']?.toString().trim() ?? '')
              .where((p) => p.isNotEmpty)
              .toSet()
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (val) {
            setState(() => selectedVperiod = val ?? '');
            _applyFilter();
          },
        ),
      ),
      const SizedBox(width: 12),
      // Dropdown Kho (RVC) - Giữ nguyên code bạn đã có, đã sửa initialValue
      Expanded(
        child: DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Kho (RVC)',
            border: OutlineInputBorder(),
          ),
          initialValue: selectedRVC.isEmpty ? null : selectedRVC,
          hint: const Text('Chọn kho...'),
          isExpanded: true,
          items: () {
            final Map<String, String> uniqueRVC = {};
            for (var e in systemInventory) {
              final code = e['locationCode']?.toString().trim() ?? e['rvc']?.toString().trim() ?? '';
              if (code.isEmpty) continue;
              final name = e['locationName']?.toString().trim() ?? 'Không xác định';
              if (!uniqueRVC.containsKey(code) ||
                  (uniqueRVC[code] == 'Không xác định' && name != 'Không xác định')) {
                uniqueRVC[code] = name;
              }
            }
            return uniqueRVC.entries.map((entry) {
              final rvcCode = entry.key;
              final rvcName = entry.value;
              final displayText = rvcName.isNotEmpty && rvcName != 'Không xác định'
                  ? '$rvcCode - $rvcName'
                  : rvcCode;
              return DropdownMenuItem<String>(
                value: rvcCode,
                child: Text(
                  displayText,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              );
            }).toList();
          }(),
          onChanged: (val) {
            setState(() => selectedRVC = val ?? '');
            _applyFilter();
          },
        ),
      ),
    ],
  ),
),
          // Camera / Preview
          Expanded(
            flex: 4,
            child: _isScanning
                ? MobileScanner(
                    controller: cameraController,
                    onDetect: (capture) {
                      final code = capture.barcodes.firstOrNull?.rawValue;
                      if (code != null && _isScanning) {
                        setState(() => _isScanning = false);
                        _processScan(code);
                      }
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_2, size: 100, color: Colors.teal),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Bật quét QR'),
                          onPressed: () => setState(() {
                            _isScanning = true;
                            _scanMessage = null;
                          }),
                        ),
                      ],
                    ),
                  ),
          ),

          // Danh sách tồn kho + nhập liệu
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_scanMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _scanMessage!,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  if (displayedItems.isNotEmpty) ...[
                    Text(
                      'Danh sách tồn kho (${displayedItems.length} dòng)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(displayedItems.length, (i) {
                      final item = displayedItems[i];
                      final ctrl = physicalControllers[i];
                      final systemQty = item['vend'] ?? item['quantity'] ?? '0';
                      final rvcName = item['rvcname'] ?? item['locationName'] ?? item['rvc'] ?? '---';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mã: ${item['ivcode'] ?? item['code'] ?? '---'}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text('Kho: $rvcName'),
                              Text('Tồn hệ thống: ${formatCleanQty(systemQty)}'),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                        child: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true), // ← Cho phép thập phân
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')), // Chỉ cho phép số + 1 dấu thập phân (tối đa 2 chữ số sau dấu)
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Tồn vật lý (Vphis)',
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                      ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: () => _saveSingle(i),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                    ),
                                    child: const Text('Lưu dòng này'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('LƯU TẤT CẢ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _saveBatch(displayedItems),
                    ),
                  ] else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Chưa có dữ liệu. Chọn kỳ/kho hoặc quét QR để bắt đầu.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
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
    _clearControllers();
    super.dispose();
  }
}
// Thêm class GameScreen này vào cuối file (trước dấu } cuối cùng của file)
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const double ballRadius = 22.0;
  static const double cupWidth = 90.0;
  static const double cupHeight = 110.0;
  static const int totalLevels = 20;

  int currentLevel = 1;
  int score = 0;
  int requiredHits = 1; // Bắt đầu chỉ cần 1 hit
  bool gameWon = false;
  bool ballThrown = false;

  Offset ballPos = const Offset(120, 600);
  Offset ballVel = Offset.zero;
  double gravity = 0.45;
  double drag = 0.98;

  late AnimationController _animController;
  double cupX = 0;
  double cupSpeed = 0.8; // Bắt đầu rất chậm
  double cupDir = 1.0;
  List<Rect> obstacles = [];
  final rng = math.Random();

  late double screenWidth;
  late double screenHeight;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    );
    _animController.addListener(_physicsTick);
    _animController.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    screenWidth = size.width;
    screenHeight = size.height;
    _resetLevel();
  }

  void _resetLevel() {
    if (!mounted) return;
    setState(() {
      ballPos = Offset(100 + rng.nextDouble() * 80, screenHeight - 200);
      ballVel = Offset.zero;
      ballThrown = false;

      // Tốc độ ly tăng dần theo level (từ 0.8 → 8.0)
      cupSpeed = 0.8 + (currentLevel - 1) * 0.38; // Level 1: 0.8, Level 20: ~8.0
      cupX = 80 + rng.nextDouble() * (screenWidth - 200);
      cupDir = rng.nextBool() ? 1.0 : -1.0;

      // Số lần trúng cần thiết tăng dần
      requiredHits = 1 + (currentLevel ~/ 4); // Level 1-3:1, 4-7:2, 8-11:3, ..., 16-20:5-6

      obstacles.clear();

      // Số chướng ngại tăng dần theo level
      int numObs = ((currentLevel - 3) / 2).clamp(0, 10).toInt(); // Level 1-3:0, 4-5:1, ..., 18-20:7-8
      for (int i = 0; i < numObs; i++) {
        double obsX = 60 + rng.nextDouble() * (screenWidth - 200);
        double obsY = 150 + rng.nextDouble() * 350;
        obstacles.add(Rect.fromLTWH(obsX, obsY, 50 + rng.nextDouble() * 40, 25));
      }
    });
  }

  void _physicsTick() {
    if (!mounted || gameWon || !ballThrown) return;

    setState(() {
      ballVel = Offset(ballVel.dx * drag, ballVel.dy * drag + gravity);
      ballPos += ballVel;

      cupX += cupDir * cupSpeed;
      if (cupX <= 20 || cupX >= screenWidth - cupWidth - 20) {
        cupDir *= -1;
      }

      final ballRect = Rect.fromCircle(center: ballPos, radius: ballRadius);
      for (Rect obs in obstacles) {
        if (ballRect.overlaps(obs)) {
          ballVel = Offset(
            ballVel.dx * -0.6 + (rng.nextDouble() - 0.5) * 2,
            ballVel.dy * -0.5,
          );
          break;
        }
      }

      final cupRect = Rect.fromLTWH(cupX, 120, cupWidth, cupHeight);
      if (ballRect.overlaps(cupRect) && ballVel.dy > 0) {
        score++;
        _showHitEffect();
        if (score >= requiredHits) {
          if (currentLevel < totalLevels) {
            currentLevel++;
            score = 0;
            _resetLevel();
          } else {
            gameWon = true;
            _animController.stop();
            if (mounted) {
              Timer(const Duration(seconds: 2), () {
                if (mounted) Navigator.pop(context);
              });
            }
          }
        } else {
          _resetLevel();
        }
      }

      if (ballPos.dy > screenHeight + 50) {
        _resetLevel();
      }
    });
  }

  void _showHitEffect() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trúng! $score/$requiredHits'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _throwBall(DragEndDetails details) {
    if (!mounted) return;
    setState(() {
      ballVel = Offset(
        details.velocity.pixelsPerSecond.dx / 25,
        details.velocity.pixelsPerSecond.dy / 25 - 12,
      );
      ballThrown = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[900],
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
              ),
            ),
          ),
          ...obstacles.map((obs) => Positioned(
                left: obs.left,
                top: obs.top,
                child: Container(
                  width: obs.width,
                  height: obs.height,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                ),
              )),
          Positioned(
            left: cupX,
            top: 110,
            child: Container(
              width: cupWidth,
              height: cupHeight,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.redAccent, Colors.orangeAccent]),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(45)),
                border: Border.all(color: Colors.white, width: 5),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.local_bar, size: 50, color: Colors.white),
            ),
          ),
          Positioned(
            left: ballPos.dx - ballRadius,
            top: ballPos.dy - ballRadius,
            child: GestureDetector(
              onPanEnd: _throwBall,
              child: Container(
                width: ballRadius * 2,
                height: ballRadius * 2,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(colors: [Colors.white, Colors.blueAccent]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12, spreadRadius: 2)],
                ),
                child: const Icon(Icons.sports_soccer, color: Colors.white70, size: 30),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                        onPressed: () {
                          _animController.stop();
                          Navigator.pop(context);
                        },
                      ),
                      Column(
                        children: [
                          Text(
                            'Level $currentLevel / $totalLevels',
                            style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Trúng: $score / $requiredHits',
                            style: const TextStyle(fontSize: 20, color: Colors.yellowAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Text(
                        gameWon
                            ? '🎉 CHÚC MỪNG! Bạn đã hoàn thành 20 level!\nĐang quay về đăng nhập...'
                            : 'Vuốt mạnh lên để ném bóng vào ly!',
                        style: TextStyle(
                          fontSize: 22,
                          color: gameWon ? Colors.greenAccent : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!gameWon) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Level càng cao ly càng nhanh và có nhiều chướng ngại hơn!\nLevel 1 rất dễ để bạn làm quen nhé!',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animController.stop();
    _animController.dispose();
    super.dispose();
  }
}
class MazeGameScreen extends StatefulWidget {
  const MazeGameScreen({super.key});

  @override
  State<MazeGameScreen> createState() => _MazeGameScreenState();
}

class _MazeGameScreenState extends State<MazeGameScreen> {
  static const int totalLevels = 20;
  int currentLevel = 1;
  bool gameWon = false;

  // Vị trí bóng (người chơi)
  Offset playerPos = const Offset(60, 60);
  double playerSize = 40.0;

  // Kích thước mê cung
  late int mazeWidth;
  late int mazeHeight;
  late List<List<int>> maze; // 0: đường đi, 1: tường

  // Vị trí đích
  Offset goalPos = const Offset(0, 0);

  // Tường di động (từ level 11+)
  List<MovingWall> movingWalls = [];

  late double screenWidth;
  late double screenHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    screenWidth = size.width;
    screenHeight = size.height;
    _generateMaze();
  }

  void _generateMaze() {
    if (!mounted) return;

    mazeWidth = 8 + (currentLevel ~/ 3);
    mazeHeight = 8 + (currentLevel ~/ 3);

    maze = List.generate(mazeHeight, (_) => List.filled(mazeWidth, 1));

    void carve(int x, int y) {
      maze[y][x] = 0;
      final directions = [
        [0, -2], [0, 2], [-2, 0], [2, 0]
      ]..shuffle();
      for (var dir in directions) {
        int nx = x + dir[0];
        int ny = y + dir[1];
        if (nx >= 0 && nx < mazeWidth && ny >= 0 && ny < mazeHeight && maze[ny][nx] == 1) {
          maze[y + dir[1] ~/ 2][x + dir[0] ~/ 2] = 0;
          carve(nx, ny);
        }
      }
    }

    carve(1, 1);

    maze[mazeHeight - 2][mazeWidth - 2] = 0;
    goalPos = Offset(
      (mazeWidth - 2) * (screenWidth / mazeWidth) + 30,
      (mazeHeight - 2) * (screenHeight * 0.6 / mazeHeight) + 30,
    );

    playerPos = const Offset(60, 60);

    movingWalls.clear();
    if (currentLevel >= 11) {
      int numMoving = (currentLevel - 10).clamp(1, 5);
      for (int i = 0; i < numMoving; i++) {
        double wx = 100 + rng.nextDouble() * (screenWidth - 200);
        double wy = 200 + rng.nextDouble() * (screenHeight * 0.5 - 300);
        movingWalls.add(MovingWall(
          pos: Offset(wx, wy),
          dir: rng.nextBool() ? 1 : -1,
          speed: 1.0 + (currentLevel - 10) * 0.3,
        ));
      }
    }

    setState(() {});
  }

  final rng = math.Random();

  void _movePlayer(Offset delta) {
    if (!mounted || gameWon) return;

    Offset newPos = playerPos + delta;

    bool collision = false;
    final playerRect = Rect.fromCircle(center: newPos, radius: playerSize / 2);

    // Kiểm tra tường tĩnh
    for (int y = 0; y < mazeHeight; y++) {
      for (int x = 0; x < mazeWidth; x++) {
        if (maze[y][x] == 1) {
          final wallRect = Rect.fromLTWH(
            x * (screenWidth / mazeWidth),
            y * (screenHeight * 0.6 / mazeHeight),
            screenWidth / mazeWidth,
            screenHeight * 0.6 / mazeHeight,
          );
          if (playerRect.overlaps(wallRect)) {
            collision = true;
            break;
          }
        }
      }
      if (collision) break;
    }

    // Kiểm tra tường di động
    for (var wall in movingWalls) {
      final wallRect = Rect.fromCircle(center: wall.pos, radius: 25);
      if (playerRect.overlaps(wallRect)) {
        collision = true;
        break;
      }
    }

    if (!collision) {
      setState(() {
        playerPos = Offset(
          newPos.dx.clamp(40.0, screenWidth - 40.0),
          newPos.dy.clamp(40.0, screenHeight * 0.6 - 40.0),
        );
      });
    }

    // Kiểm tra đến đích
    final goalRect = Rect.fromCircle(center: goalPos, radius: 30);
    if (playerRect.overlaps(goalRect)) {
      if (currentLevel < totalLevels) {
        currentLevel++;
        _generateMaze();
      } else {
        setState(() => gameWon = true);
        Timer(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
              ),
            ),
          ),

          CustomPaint(
            size: Size(screenWidth, screenHeight * 0.6),
            painter: MazePainter(maze, screenWidth / mazeWidth, screenHeight * 0.6 / mazeHeight),
          ),

          ...movingWalls.map((wall) => AnimatedPositioned(
                duration: const Duration(milliseconds: 16),
                left: wall.pos.dx - 25,
                top: wall.pos.dy - 25,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.7), // ← Sửa deprecated
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 10)],
                  ),
                ),
              )),

          Positioned(
            left: playerPos.dx - playerSize / 2,
            top: playerPos.dy - playerSize / 2,
            child: GestureDetector(
              onPanUpdate: (details) {
                _movePlayer(details.delta);
              },
              child: Container(
                width: playerSize,
                height: playerSize,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(colors: [Colors.cyanAccent, Colors.blue]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.cyanAccent, blurRadius: 12, spreadRadius: 4)],
                ),
                child: const Icon(Icons.sports_handball, color: Colors.white, size: 30),
              ),
            ),
          ),

          Positioned(
            left: goalPos.dx - 30,
            top: goalPos.dy - 30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.yellowAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange, width: 4),
                boxShadow: [BoxShadow(color: Colors.yellow.withValues(alpha: 0.6), blurRadius: 15)],
              ),
              child: const Icon(Icons.flag, color: Colors.red, size: 40),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Mê Cung - Level $currentLevel / $totalLevels',
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    children: [
                      if (gameWon)
                        const Text(
                          '🎉 CHÚC MỪNG! Bạn đã vượt qua 20 level mê cung!\nĐang quay về đăng nhập...',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else
                        const Text(
                          'Vuốt để di chuyển bóng đến cờ đích!\nLevel càng cao mê cung càng khó...',
                          style: TextStyle(fontSize: 18, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Painter vẽ mê cung (giữ nguyên)
class MazePainter extends CustomPainter {
  final List<List<int>> maze;
  final double cellWidth;
  final double cellHeight;

  MazePainter(this.maze, this.cellWidth, this.cellHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey[850]!;
    for (int y = 0; y < maze.length; y++) {
      for (int x = 0; x < maze[y].length; x++) {
        if (maze[y][x] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(x * cellWidth, y * cellHeight, cellWidth, cellHeight),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Class tường di động (giữ nguyên)
class MovingWall {
  Offset pos;
  double dir;
  double speed;

  MovingWall({required this.pos, required this.dir, required this.speed});
}