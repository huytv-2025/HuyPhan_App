import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    );
  }
}

// ================== TRANG ĐĂNG NHẬP - CHIẾM GẦN HẾT MÀN HÌNH, CÓ NHẬP IP:PORT ==================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _clerkIdController = TextEditingController();
  final _securityCodeController = TextEditingController();
  final _ipController = TextEditingController(text: '10.0.2.2'); // Mặc định cho emulator
  final _portController = TextEditingController(text: '5107');   // Mặc định port API

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
          'clerkID': clerkId,
          'securityCode': securityCode,
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
                      const Icon(Icons.lock_person_rounded, size: 100, color: Colors.teal),
                      const SizedBox(height: 24),
                      const Text(
                        'HuyPhan App',
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const Text(
                        'Đăng Nhập Hệ Thống',
                        style: TextStyle(fontSize: 18, color: Colors.teal),
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

// ================== MENU CHÍNH ==================
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
      const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text('Trang Home', style: TextStyle(fontSize: 30)),
          ],
        ),
      ),
      const SaleOrderScreen(),
      const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 100, color: Colors.orange),
            SizedBox(height: 20),
            Text('Quét QR', style: TextStyle(fontSize: 30)),
          ],
        ),
      ),
      const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sync, size: 100, color: Colors.purple),
            SizedBox(height: 20),
            Text('Cập Nhật QR', style: TextStyle(fontSize: 30)),
          ],
        ),
      ),
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

// ================== TRANG SALE ORDER - ẢNH TỪ THƯ MỤC LOCAL ==================
class SaleOrderScreen extends StatefulWidget {
  const SaleOrderScreen({super.key});

  @override
  State<SaleOrderScreen> createState() => _SaleOrderScreenState();
}

class _SaleOrderScreenState extends State<SaleOrderScreen> {
  // Danh sách sản phẩm với ảnh LOCAL (từ thư mục assets/images/)
  final List<Map<String, dynamic>> products = [
    {
      'name': 'iPhone 15 Pro Max',
      'price': 34990000,
      'description': 'Thiết kế titanium cao cấp, chip A17 Pro mạnh mẽ, camera 48MP với zoom quang học 5x. Màn hình Super Retina XDR 6.7 inch.',
      'imagePath': 'assets/images/hp123.jpg', // Đổi tên file ảnh của bạn
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
    selectedProduct = products[0]; // Chọn sản phẩm đầu tiên
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
          // === PHẦN TRÊN: 70% - ẢNH LỚN + THÔNG TIN ===
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
                  // Ảnh lớn
                  Expanded(
                    flex: 6,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                      child: Image.asset(
                        selectedProduct['imagePath'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Thông tin sản phẩm
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedProduct['name'],
                            style: const TextStyle(
                              fontSize: 32, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${selectedProduct['price'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} ₫',
                            style: const TextStyle(
                              fontSize: 28, 
                              color: Colors.green, 
                              fontWeight: FontWeight.bold,
                            ),
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

          // === PHẦN DƯỚI: 30% - DÃY THUMBNAIL NHỎ ===
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
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: isSelected ? 4 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          product['imagePath'],
                          fit: BoxFit.cover,
                          width: 100,
                          height: double.infinity,
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