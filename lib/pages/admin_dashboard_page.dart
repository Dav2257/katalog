import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/cage_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/settings_service.dart';
import '../services/user_service.dart';
import 'admin_add_product_page.dart';
import 'admin_completed_order_detail_page.dart';
import 'admin_edit_product_page.dart';
import 'admin_order_detail_page.dart';
import 'admin_settings_page.dart';
import 'admin_user_detail_page.dart';

/// Ikon circular pie-chart khas seperti di gambar referensi
class PieChartIcon extends StatelessWidget {
  final double size;
  final Color color;

  const PieChartIcon({super.key, this.size = 18, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PieChartPainter(color: color),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final Color color;

  _PieChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Lingkaran utama (3/4 lingkaran)
    final mainRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(mainRect, math.pi * 0.45, math.pi * 1.45, true, paint);

    // Potongan 1/4 terpisah sedikit ke kanan atas
    final sliceRect = Rect.fromCircle(
      center: Offset(center.dx + radius * 0.18, center.dy - radius * 0.18),
      radius: radius * 0.9,
    );
    canvas.drawArc(sliceRect, math.pi * 1.95, math.pi * 0.45, true, paint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Model Pesanan Masuk untuk Admin
class AdminIncomingOrder {
  final int no;
  final String customerName;
  final String phone;
  final String email;
  final String date;
  final int quantity;
  final String productCode;
  final String status;
  final String note;
  final String cageType;
  final String orderId;
  final String? imageUrl;

  const AdminIncomingOrder({
    required this.no,
    this.customerName = '',
    required this.phone,
    this.email = '',
    required this.date,
    required this.quantity,
    required this.productCode,
    required this.status,
    this.note = '',
    this.cageType = '',
    this.orderId = '',
    this.imageUrl,
  });
}

/// Model Riwayat Pesanan Selesai untuk Admin
class AdminCompletedOrder {
  final int no;
  final String phone;
  final String email;
  final String date;
  final int quantity;
  final String productCode;
  final String status;
  final String customerName;
  final String cageType;
  final String note;
  final String? imageUrl;
  final String? orderId;

  const AdminCompletedOrder({
    required this.no,
    required this.phone,
    this.email = '',
    required this.date,
    required this.quantity,
    required this.productCode,
    required this.status,
    this.customerName = '',
    this.cageType = '',
    this.note = '',
    this.imageUrl,
    this.orderId,
  });
}

class AdminDashboardPage extends StatefulWidget {
  final VoidCallback onPreviewUmum;
  final VoidCallback onLogout;

  const AdminDashboardPage({
    super.key,
    required this.onPreviewUmum,
    required this.onLogout,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedMenuIndex = 0;

  final TextEditingController _nameFilterController = TextEditingController();
  final TextEditingController _codeFilterController = TextEditingController();
  final ScrollController _cageScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();

  // Kontrol Pagination untuk List Produk User Umum
  int _productPageSize = 5;
  int _productCurrentPage = 1;

  final GlobalKey _dashboardKey = GlobalKey();
  final GlobalKey _pesananKey = GlobalKey();
  final GlobalKey _userPrivateKey = GlobalKey();
  final GlobalKey _produkKey = GlobalKey();
  final GlobalKey _sangkarKey = GlobalKey();
  final GlobalKey _riwayatKey = GlobalKey();

  int? _hoveredMenuIndex;
  bool _isManualScrolling = false;

  final List<String> _menuItems = [
    'Dashboard',
    'Pesanan',
    'User Private',
    'Produk',
    'Sangkar',
    'Riwayat',
    'Pengaturan',
    'Preview Umum',
  ];

  // Data Tabel Riwayat Pesanan yang Sudah Selesai dari Semua User (Dikosongkan dari data dummy)
  final List<AdminCompletedOrder> _completedOrders = [];

  // Data Tabel Pesanan Masuk (Dikosongkan dari data dummy)
  final List<AdminIncomingOrder> _incomingOrders = [];

  // Data Tabel User Private bersumber dinamis dari UserService (terisi saat user registrasi)
  List<AdminPrivateUser> get _privateUsers => UserService.instance.users;

  // Data List Produk User Umum bersumber dinamis dari ProductService (Admin dapat menambah produk)
  List<AdminPublicProduct> get _publicProducts =>
      ProductService.instance.adminProducts;

  List<AdminPublicProduct> get _filteredPublicProducts {
    final nameQuery = _nameFilterController.text.trim().toLowerCase();
    final codeQuery = _codeFilterController.text.trim().toLowerCase();

    return _publicProducts.where((p) {
      final matchesName =
          nameQuery.isEmpty ||
          p.name.toLowerCase().contains(nameQuery) ||
          p.displayName.toLowerCase().contains(nameQuery) ||
          p.hashtags.toLowerCase().contains(nameQuery);
      final matchesCode =
          codeQuery.isEmpty || p.code.toLowerCase().contains(codeQuery);
      return matchesName && matchesCode;
    }).toList();
  }

  /// Menggabungkan seluruh pesanan masuk aktif dari semua user (OrderService) + pesanan bawaan
  List<AdminIncomingOrder> get _allIncomingOrders {
    final List<AdminIncomingOrder> list = [];
    int counter = 1;

    // 1. Pesanan aktif yang di-checkout oleh user (baik Member maupun Guest) dari OrderService
    final appOrders = OrderService.instance.allOrders;
    for (final order in appOrders) {
      final isFinished =
          order.currentStep >= 5 ||
          order.status.toLowerCase().contains('selesai') ||
          order.status.toLowerCase().contains('diterima');

      if (!isFinished) {
        final codeMatch = RegExp(
          r'^([A-Za-z0-9]+)',
        ).firstMatch(order.productName.trim());
        final code = (codeMatch != null && codeMatch.group(1)!.length <= 6)
            ? codeMatch.group(1)!
            : 'A01';

        final dateStr =
            '${order.orderDate.day.toString().padLeft(2, '0')}-${order.orderDate.month.toString().padLeft(2, '0')}-${order.orderDate.year}';

        list.add(
          AdminIncomingOrder(
            no: counter++,
            customerName: order.customerName,
            phone: order.phone,
            email: order.email,
            date: dateStr,
            quantity: order.quantity,
            productCode: code,
            status: order.status,
            note: order.note,
            cageType: order.cageTypeOrDesign,
            orderId: order.id,
            imageUrl: order.imageUrl,
          ),
        );
      }
    }

    // 2. Data pesanan masuk bawaan
    for (final inc in _incomingOrders) {
      list.add(
        AdminIncomingOrder(
          no: counter++,
          customerName: inc.customerName,
          phone: inc.phone,
          date: inc.date,
          quantity: inc.quantity,
          productCode: inc.productCode,
          status: inc.status,
          note: inc.note,
          cageType: inc.cageType,
          orderId: inc.orderId,
          imageUrl: inc.imageUrl,
        ),
      );
    }

    return list;
  }

  /// Menggabungkan data riwayat pesanan selesai: dummy acuan gambar + pesanan selesai dari OrderService
  List<AdminCompletedOrder> get _allCompletedOrders {
    final List<AdminCompletedOrder> combined = List.from(_completedOrders);

    final appOrders = OrderService.instance.allOrders;

    int nextNo = combined.length + 1;
    for (final order in appOrders) {
      final isFinished =
          order.currentStep >= 5 ||
          order.status.toLowerCase().contains('selesai') ||
          order.status.toLowerCase().contains('diterima');
      if (isFinished) {
        final codeMatch = RegExp(
          r'^[A-Za-z0-9]+',
        ).firstMatch(order.productName);
        final code = codeMatch != null ? codeMatch.group(0)! : 'CUSTOM';

        combined.add(
          AdminCompletedOrder(
            no: nextNo++,
            phone: order.phone,
            email: order.email,
            date:
                '${order.orderDate.day.toString().padLeft(2, '0')}-${order.orderDate.month.toString().padLeft(2, '0')}-${order.orderDate.year}',
            quantity: order.quantity,
            productCode: code,
            status: order.status.toLowerCase().contains('diterima')
                ? 'Diterima'
                : 'Selesai',
            customerName: 'Member App',
            cageType: order.cageTypeOrDesign,
            note: order.note,
            imageUrl: order.imageUrl,
            orderId: order.id,
          ),
        );
      }
    }

    return combined;
  }

  @override
  void initState() {
    super.initState();
    _mainScrollController.addListener(_onMainScroll);
    CageService.instance.addListener(_handleCageUpdate);
    OrderService.instance.addListener(_handleOrderUpdate);
    UserService.instance.addListener(_handleUserUpdate);
    ProductService.instance.addListener(_handleProductUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProductService.instance.fetchProducts();
      UserService.instance.fetchUsers();
      OrderService.instance.fetchOrders();
      CageService.instance.fetchCages();
    });
  }

  void _onMainScroll() {
    if (_isManualScrolling) return;
    if (!_mainScrollController.hasClients) return;

    final scrollOffset = _mainScrollController.offset;

    // Jika scroll berada di paling atas, aktifkan Dashboard (index 0)
    if (scrollOffset <= 80) {
      if (_selectedMenuIndex != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedMenuIndex != 0) {
            setState(() {
              _selectedMenuIndex = 0;
            });
          }
        });
      }
      return;
    }

    // Jika sudah mendekati paling bawah halaman, aktifkan Riwayat (index 5)
    final maxScroll = _mainScrollController.position.maxScrollExtent;
    if (scrollOffset >= maxScroll - 60) {
      if (_selectedMenuIndex != 5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedMenuIndex != 5) {
            setState(() {
              _selectedMenuIndex = 5;
            });
          }
        });
      }
      return;
    }

    // Daftar section berurutan dari atas ke bawah
    final sections = [
      MapEntry(0, _dashboardKey),
      MapEntry(1, _pesananKey),
      MapEntry(2, _userPrivateKey),
      MapEntry(3, _produkKey),
      MapEntry(4, _sangkarKey),
      MapEntry(5, _riwayatKey),
    ];

    int currentActive = 0;
    for (final entry in sections) {
      final ctx = entry.value.currentContext;
      if (ctx != null) {
        final renderBox = ctx.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final dy = renderBox.localToGlobal(Offset.zero).dy;
          // Elemen dianggap aktif jika posisinya sudah berada di area atas viewport
          if (dy <= 280) {
            currentActive = entry.key;
          }
        }
      }
    }

    if (_selectedMenuIndex != currentActive && currentActive < 6) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedMenuIndex != currentActive) {
          setState(() {
            _selectedMenuIndex = currentActive;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_onMainScroll);
    _nameFilterController.dispose();
    _codeFilterController.dispose();
    _cageScrollController.dispose();
    _mainScrollController.dispose();
    CageService.instance.removeListener(_handleCageUpdate);
    OrderService.instance.removeListener(_handleOrderUpdate);
    UserService.instance.removeListener(_handleUserUpdate);
    ProductService.instance.removeListener(_handleProductUpdate);
    super.dispose();
  }

  void _handleCageUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _handleOrderUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _handleUserUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _handleProductUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _scrollToMenu(String title) {
    _isManualScrolling = true;
    if (title == 'Dashboard') {
      if (_mainScrollController.hasClients) {
        _mainScrollController
            .animateTo(
              0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            )
            .then((_) {
              Future.delayed(const Duration(milliseconds: 150), () {
                if (mounted) _isManualScrolling = false;
              });
            });
      } else {
        _isManualScrolling = false;
      }
      return;
    }

    GlobalKey? targetKey;
    if (title == 'Pesanan') {
      targetKey = _pesananKey;
    } else if (title == 'User Private') {
      targetKey = _userPrivateKey;
    } else if (title == 'Produk') {
      targetKey = _produkKey;
    } else if (title == 'Sangkar') {
      targetKey = _sangkarKey;
    } else if (title == 'Riwayat') {
      targetKey = _riwayatKey;
    }

    if (targetKey?.currentContext != null) {
      Scrollable.ensureVisible(
        targetKey!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      ).then((_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _isManualScrolling = false;
        });
      });
    } else {
      _isManualScrolling = false;
    }
  }

  void _showAddCageDialog() {
    final nextNumber = CageService.instance.count + 1;
    final nameController = TextEditingController(text: 'Sangkar $nextNumber');

    showDialog(
      context: context,
      builder: (ctx) {
        void submitAddCage() async {
          final name = nameController.text.trim().isNotEmpty
              ? nameController.text.trim()
              : 'Sangkar $nextNumber';
          Navigator.pop(ctx);
          await CageService.instance.addCage(name: name);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_cageScrollController.hasClients) {
              _cageScrollController.animateTo(
                _cageScrollController.position.maxScrollExtent + 300,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            }
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Bentuk sangkar "$name" berhasil ditambahkan!'),
                backgroundColor: const Color(0xFF7A4B29),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actionsAlignment: MainAxisAlignment.end,
          actionsOverflowButtonSpacing: 8,
          title: const Row(
            children: [
              Icon(Icons.add_box_rounded, color: Color(0xFF7A4B29)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tambah Bentuk Sangkar',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nama Bentuk Sangkar:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submitAddCage(),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Sangkar Segi Enam',
                    filled: true,
                    fillColor: const Color(0xFFF4F4F4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: submitAddCage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A4B29),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Simpan Sangkar'),
            ),
          ],
        );
      },
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF382314),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService.instance.adminName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        AuthService.instance.adminEmail,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(
                  Icons.visibility_outlined,
                  color: Colors.black87,
                ),
                title: const Text('Preview Katalog Umum'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onPreviewUmum();
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Keluar dari Akun Admin',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAdminFooterNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C1A0E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // 1. KIRI: SETTING
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminSettingsPage(),
                      ),
                    );
                  },
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings_rounded,
                        color: Color(0xFFF5ECD7),
                        size: 24,
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Setting',
                        style: TextStyle(
                          color: Color(0xFFF5ECD7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. TENGAH: PREVIEW UMUM (MARKETPLACE)
              Expanded(
                child: InkWell(
                  onTap: widget.onPreviewUmum,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFDF00), Color(0xFFD4AF37)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD900).withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFF382314),
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Preview Umum',
                        style: TextStyle(
                          color: Color(0xFFFFD900),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. KANAN: PROFIL
              Expanded(
                child: InkWell(
                  onTap: _showProfileMenu,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_circle_rounded,
                        color: Color(0xFFFFD900),
                        size: 24,
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Profil',
                        style: TextStyle(
                          color: Color(0xFFFFD900),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;

        if (isDesktop) {
          // Tampilan Layar Lebar: Sidebar Kiri Tetap + Konten Utama Kanan
          return Scaffold(
            backgroundColor: const Color(0xFFEDEDED),
            body: Row(
              children: [
                // Sidebar Kiri
                _buildSidebar(width: 220),

                // Area Konten Utama
                Expanded(child: _buildMainContent(isDesktop: true)),
              ],
            ),
          );
        } else {
          // Tampilan Mobile / Tablet: Header Bersih Hanya Teks & Footer Navigation
          return Scaffold(
            backgroundColor: const Color(0xFFEDEDED),
            appBar: AppBar(
              backgroundColor: const Color(0xFF382314),
              elevation: 1,
              automaticallyImplyLeading: false,
              title: const Text(
                'Dashboard Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            bottomNavigationBar: _buildMobileAdminFooterNavigation(),
            body: _buildMainContent(isDesktop: false),
          );
        }
      },
    );
  }

  /// Membangun Sidebar Cokelat Kayu Jati Jepara persis sesuai gambar
  Widget _buildSidebar({required double width, bool inDrawer = false}) {
    return Container(
      width: width,
      color: const Color(0xFF382314),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bagian Header Atas Sidebar dengan Logo (Sesuai Gambar 2)
          Container(
            padding: EdgeInsets.only(
              top: inDrawer ? 20 : 28,
              bottom: 22,
              left: 14,
              right: 14,
            ),
            child: ListenableBuilder(
              listenable: AppSettingsService.instance,
              builder: (context, _) {
                return Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(1.5),
                        child: AppSettingsService.instance.buildLogoWidget(
                          width: 62,
                          height: 62,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'JatiMas',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'SANGKAR',
                            style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'ADMIN PANEL',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Daftar Item Menu
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedMenuIndex == index;
                final isHovered = _hoveredMenuIndex == index;
                final title = _menuItems[index];

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoveredMenuIndex = index),
                  onExit: (_) => setState(() => _hoveredMenuIndex = null),
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () {
                      if (title == 'Preview Umum') {
                        if (inDrawer) Navigator.pop(context);
                        widget.onPreviewUmum();
                        return;
                      }
                      if (title == 'Pengaturan') {
                        if (inDrawer) Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminSettingsPage(),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _selectedMenuIndex = index;
                      });
                      if (inDrawer) Navigator.pop(context);
                      _scrollToMenu(title);
                    },
                    hoverColor: Colors.transparent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5A3922)
                            : isHovered
                            ? const Color(0xFF4A2C18)
                            : Colors.transparent,
                        border: isSelected
                            ? const Border(
                                left: BorderSide(
                                  color: Color(0xFFD4AF37),
                                  width: 3.5,
                                ),
                              )
                            : null,
                      ),
                      padding: EdgeInsets.only(
                        left: isSelected ? 10.5 : 14,
                        right: 14,
                      ),
                      child: Row(
                        children: [
                          PieChartIcon(
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : isHovered
                                ? const Color(0xFFFFF0E0)
                                : const Color(0xFFE8DBD1),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white
                                    : isHovered
                                    ? const Color(0xFFFFF0E0)
                                    : const Color(0xFFE8DBD1),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  /// Membangun Konten Utama (Header Akun, Analisis Data, Pesanan Masuk, User Private, Riwayat)
  Widget _buildMainContent({required bool isDesktop}) {
    final int cageCount = CageService.instance.cages.length;

    return SingleChildScrollView(
      controller: _mainScrollController,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar Akun Admin di Atas
          KeyedSubtree(
            key: _dashboardKey,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Info Admin di Kiri
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AuthService.instance.adminName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              AuthService.instance.adminEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tombol Profil di Kanan (hanya tampil di desktop, di mobile sudah ada di footer navigasi)
                if (isDesktop)
                  IconButton(
                    onPressed: _showProfileMenu,
                    icon: const Icon(
                      Icons.account_circle_outlined,
                      size: 32,
                      color: Color(0xFF555555),
                    ),
                    tooltip: 'Menu Akun Admin',
                  ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 2. Bagian: Analisis Data
          _buildSectionHeader('Analisis Data'),
          const SizedBox(height: 16),

          // Baris Kartu Metrik Analisis Data persis seperti di gambar:
          // Baris 1: 3 kartu (JUMLAH DESIGN PRODUK, JUMLAH PESANAN, JUMLAH DESIGN REQUEST)
          // Baris 2: 2 kartu (JUMLAH BENTUK SANGKAR, JUMLAH PESANAN BARU) sejajar dengan kolom 1 & 2
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 780;

              final totalProducts = _publicProducts.length;
              final totalOrders =
                  _allCompletedOrders.length + _allIncomingOrders.length;
              final totalCustomLogos = UserService.instance.users.fold<int>(
                0,
                (sum, u) => sum + u.customLogoCount,
              );
              final newOrders = _allIncomingOrders.length;

              Widget buildRow1() => Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'JUMLAH DESIGN PRODUK',
                      value: '$totalProducts',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'JUMLAH PESANAN',
                      value: '$totalOrders',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'JUMLAH LOGO CUSTOM',
                      value: '$totalCustomLogos',
                    ),
                  ),
                ],
              );

              Widget buildRow2() => Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'JUMLAH BENTUK SANGKAR',
                      value: '$cageCount',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'JUMLAH PESANAN BARU',
                      value: '$newOrders',
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox()),
                ],
              );

              if (isWide) {
                return Column(
                  children: [
                    buildRow1(),
                    const SizedBox(height: 16),
                    buildRow2(),
                  ],
                );
              } else {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 780),
                    child: SizedBox(
                      width: 780,
                      child: Column(
                        children: [
                          buildRow1(),
                          const SizedBox(height: 16),
                          buildRow2(),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade400, thickness: 1.2),
          const SizedBox(height: 16),

          // 3. Bagian: Pesanan Masuk
          KeyedSubtree(
            key: _pesananKey,
            child: _buildSectionHeader('Pesanan Masuk'),
          ),
          const SizedBox(height: 14),
          _buildIncomingOrdersTable(),

          const SizedBox(height: 32),

          // 4. Bagian: User Private
          KeyedSubtree(
            key: _userPrivateKey,
            child: _buildSectionHeader('User Private'),
          ),
          const SizedBox(height: 14),
          _buildPrivateUsersTable(),

          const SizedBox(height: 32),

          // 5. Bagian: List Produk User Umum (Sesuai Gambar)
          KeyedSubtree(
            key: _produkKey,
            child: _buildSectionHeader('List Produk User Umum'),
          ),
          const SizedBox(height: 14),
          _buildPublicProductsSection(),

          const SizedBox(height: 32),

          // 6. Bagian: Sangkar (Sesuai Gambar)
          KeyedSubtree(
            key: _sangkarKey,
            child: _buildSectionHeader(
              'Sangkar',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${CageService.instance.count} Bentuk',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A7A7A),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _scrollCages(false),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _scrollCages(true),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildCageManagementSection(),

          const SizedBox(height: 32),

          // 7. Bagian: Riwayat (Pesanan Selesai dari Semua User - Sesuai Gambar)
          KeyedSubtree(key: _riwayatKey, child: _buildSectionHeader('Riwayat')),
          const SizedBox(height: 14),
          _buildCompletedOrdersTable(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Header bagian dengan garis aksen cokelat tebal di kiri
  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5328),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5F5F5F),
              ),
            ),
          ],
        ),
        ?trailing,
      ],
    );
  }

  /// Kartu Metrik Analisis Data dengan strip aksen cokelat di sisi kiri
  Widget _buildMetricCard({
    required String title,
    required String value,
    double? width,
  }) {
    return Container(
      width: width,
      height: 112,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Strip Cokelat di Kiri Kartu
            Container(
              width: 14,
              height: double.infinity,
              color: const Color(0xFF8B5328),
            ),

            // Konten Teks Kartu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF636363),
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A4A4A),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tabel Kartu Pesanan Masuk (Dipanjangkan & Lebih Luas)
  Widget _buildIncomingOrdersTable() {
    final incomingList = _allIncomingOrders;

    if (incomingList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 44, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Belum ada pesanan masuk',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pesanan yang masuk dari pengguna akan otomatis muncul di tabel ini.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final double dynamicSpacing =
              ((availableWidth - 48 - 720) / 7).clamp(20.0, 140.0);
          final double minTableWidth = math.max(availableWidth, 900.0);

          return Scrollbar(
            thumbVisibility: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: DataTable(
                  horizontalMargin: 24,
                  columnSpacing: dynamicSpacing,
                  headingRowHeight: 52,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 58,
                  columns: const [
                    DataColumn(label: Text('No.', style: _headerStyle)),
                    DataColumn(label: Text('Nama', style: _headerStyle)),
                    DataColumn(label: Text('Nomor Telp.', style: _headerStyle)),
                    DataColumn(label: Text('Tgl Pesanan', style: _headerStyle)),
                    DataColumn(label: Text('Jumlah Pesanan', style: _headerStyle)),
                    DataColumn(label: Text('Kode Produk', style: _headerStyle)),
                    DataColumn(label: Text('Status', style: _headerStyle)),
                    DataColumn(label: Text('Action', style: _headerStyle)),
                  ],
                  rows: incomingList.map((order) {
                    return DataRow(
                      cells: [
                        DataCell(Text('${order.no}.', style: _cellStyle)),
                        DataCell(
                          Text(
                            order.customerName.trim().isNotEmpty
                                ? order.customerName
                                : '-',
                            style: _cellStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            order.phone.trim().isNotEmpty
                                ? order.phone
                                : (order.email.trim().isNotEmpty
                                    ? order.email
                                    : '-'),
                            style: _cellStyle.copyWith(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        DataCell(Text(order.date, style: _cellStyle)),
                        DataCell(Text('${order.quantity}', style: _cellStyle)),
                        DataCell(Text(order.productCode, style: _cellStyle)),
                        DataCell(Text(order.status, style: _cellStyle)),
                        DataCell(
                          ElevatedButton(
                            key: ValueKey(
                              'order_detail_${order.phone}_${order.no}',
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminOrderDetailPage(order: order),
                                ),
                              ).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A4B29),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              minimumSize: const Size(60, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'Detail',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
          );
        },
      ),
    );
  }

  /// Tabel Kartu Riwayat Pesanan Selesai dari Semua User (Persis Sesuai Gambar Referensi)
  Widget _buildCompletedOrdersTable() {
    final completedList = _allCompletedOrders;

    if (completedList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                size: 44,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada riwayat pesanan selesai',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pesanan yang telah diselesaikan oleh admin akan dicatat di tabel riwayat ini.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final double dynamicSpacing =
              ((availableWidth - 48 - 640) / 6).clamp(20.0, 150.0);
          final double minTableWidth = math.max(availableWidth, 850.0);

          return Scrollbar(
            thumbVisibility: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: DataTable(
                  horizontalMargin: 24,
                  columnSpacing: dynamicSpacing,
                  headingRowHeight: 52,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 58,
                  columns: const [
                    DataColumn(label: Text('No.', style: _headerStyle)),
                    DataColumn(label: Text('Nomor Telp.', style: _headerStyle)),
                    DataColumn(label: Text('Tgl Pesanan', style: _headerStyle)),
                    DataColumn(label: Text('Jumlah Pesanan', style: _headerStyle)),
                    DataColumn(label: Text('Kode Produk', style: _headerStyle)),
                    DataColumn(label: Text('Status', style: _headerStyle)),
                    DataColumn(label: Text('Action', style: _headerStyle)),
                  ],
                  rows: completedList.map((order) {
                    return DataRow(
                      cells: [
                        DataCell(Text('${order.no}.', style: _cellStyle)),
                        DataCell(
                          InkWell(
                            key: ValueKey(
                              'completed_order_phone_${order.phone}_${order.no}',
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminCompletedOrderDetailPage(order: order),
                                ),
                              );
                            },
                            child: Text(
                              order.phone.trim().isNotEmpty
                                  ? order.phone
                                  : (order.email.trim().isNotEmpty
                                      ? order.email
                                      : '-'),
                              style: _cellStyle.copyWith(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(order.date, style: _cellStyle)),
                        DataCell(Text('${order.quantity}', style: _cellStyle)),
                        DataCell(Text(order.productCode, style: _cellStyle)),
                        DataCell(Text(order.status, style: _cellStyle)),
                        DataCell(
                          ElevatedButton(
                            key: ValueKey(
                              'completed_order_detail_${order.phone}_${order.no}',
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminCompletedOrderDetailPage(order: order),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A4B29),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              minimumSize: const Size(60, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'Detail',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
          );
        },
      ),
    );
  }

  /// Tabel Kartu User Private (Dipanjangkan & Lebih Luas)
  Widget _buildPrivateUsersTable() {
    if (_privateUsers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline_rounded,
                size: 44,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada user private terdaftar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pengguna yang membuat akun member/private akan tercatat di tabel ini.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final double dynamicSpacing =
              ((availableWidth - 48 - 780) / 7).clamp(20.0, 140.0);
          final double minTableWidth = math.max(availableWidth, 950.0);

          return Scrollbar(
            thumbVisibility: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: DataTable(
                  horizontalMargin: 24,
                  columnSpacing: dynamicSpacing,
                  headingRowHeight: 52,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 58,
                  columns: const [
                    DataColumn(label: Text('No.', style: _headerStyle)),
                    DataColumn(label: Text('Nama', style: _headerStyle)),
                    DataColumn(label: Text('No. Telp', style: _headerStyle)),
                    DataColumn(label: Text('Email', style: _headerStyle)),
                    DataColumn(label: Text('Password', style: _headerStyle)),
                    DataColumn(label: Text('Tgl Masuk', style: _headerStyle)),
                    DataColumn(
                      label: Text('Jumlah Logo Custom', style: _headerStyle),
                    ),
                    DataColumn(label: Text('Action', style: _headerStyle)),
                  ],
                  rows: _privateUsers.map((user) {
                    return DataRow(
                      cells: [
                        DataCell(Text('${user.no}.', style: _cellStyle)),
                        DataCell(
                          Text(
                            user.name.isNotEmpty ? user.name : '-',
                            style: _cellStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            user.phone.isNotEmpty ? user.phone : '-',
                            style: _cellStyle,
                          ),
                        ),
                        DataCell(
                          Text(
                            user.email.isNotEmpty ? user.email : '-',
                            style: _cellStyle,
                          ),
                        ),
                        DataCell(Text(user.password, style: _cellStyle)),
                        DataCell(Text(user.joinDate, style: _cellStyle)),
                        DataCell(Text('${user.customLogoCount}', style: _cellStyle)),
                        DataCell(
                          ElevatedButton(
                            key: ValueKey(
                              'user_detail_${user.phone.isNotEmpty ? user.phone : user.email}',
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminUserDetailPage(user: user),
                                ),
                              ).then((_) {
                                if (mounted) setState(() {});
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A4B29),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              minimumSize: const Size(60, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text(
                              'Detail',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
          );
        },
      ),
    );
  }

  /// List Produk yang akan ditampilkan di user umum dengan fitur Paginate
  Widget _buildPublicProductsSection() {
    final filteredList = _filteredPublicProducts;
    final totalItems = filteredList.length;

    // Hitung pembagian data berdasarkan pagination
    final totalPages = (totalItems / _productPageSize).ceil().clamp(1, 999999);
    final currentPage = _productCurrentPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _productPageSize;

    // Paginate: ambil sebanyak _productPageSize sesuai halaman saat ini
    final displayList = filteredList
        .skip(startIndex)
        .take(_productPageSize)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Judul Pencarian
              const Text(
                'Cari berdasarkan:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 12),

              // Tombol Kategori Pencarian (Nama & Kode)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A4B29),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Nama',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6D6D6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Kode',
                      style: TextStyle(
                        color: Color(0xFF6E6E6E),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Kolom Input Pencarian (Kiri Lebar untuk Nama '.....', Kanan untuk Kode '...')
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F1F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _nameFilterController,
                        onChanged: (_) => setState(() {
                          _productCurrentPage = 1;
                        }),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '.....',
                          hintStyle: TextStyle(
                            color: Color(0xFF8E8E8E),
                            fontSize: 14,
                            letterSpacing: 2.0,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F1F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      child: TextField(
                        controller: _codeFilterController,
                        onChanged: (_) => setState(() {
                          _productCurrentPage = 1;
                        }),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '...',
                          hintStyle: TextStyle(
                            color: Color(0xFF8E8E8E),
                            fontSize: 14,
                            letterSpacing: 2.0,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Toolbar Pengaturan Limit Per Halaman
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Batasi:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6E6E6E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1F1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _productPageSize,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: Color(0xFF7A4B29),
                            ),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(
                                value: 3,
                                child: Text(
                                  '3 per hal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 5,
                                child: Text(
                                  '5 per hal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 10,
                                child: Text(
                                  '10 per hal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 20,
                                child: Text(
                                  '20 per hal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _productPageSize = val;
                                  _productCurrentPage = 1;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Area Wadah List Produk Abu-Abu Persis di Gambar
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: ProductService.instance.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7A4B29),
                          ),
                        ),
                      )
                    : filteredList.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 32.0,
                          horizontal: 16.0,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _publicProducts.isEmpty
                                    ? 'Belum ada produk di database'
                                    : 'Tidak ada produk yang sesuai dengan pencarian.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                              if (_publicProducts.isEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Gunakan tombol "Tambah Produk" di bawah untuk membuat produk baru.',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayList.length,
                            separatorBuilder: (context, index) => const Divider(
                              color: Color(0xFFE4E4E4),
                              height: 12,
                              thickness: 1,
                            ),
                            itemBuilder: (context, index) {
                              return _buildProductListItem(displayList[index]);
                            },
                          ),

                          const Divider(
                            color: Color(0xFFE0E0E0),
                            height: 16,
                            thickness: 1,
                          ),

                          // Bagian Bawah: Navigasi Pagination Responsif (Anti-Overflow di HP)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 540;

                                final pageButtons = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Tombol Halaman Sebelumnya
                                    InkWell(
                                      onTap: currentPage > 1
                                          ? () {
                                              setState(() {
                                                _productCurrentPage--;
                                              });
                                            }
                                          : null,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: currentPage > 1
                                              ? Colors.white
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: currentPage > 1
                                                ? const Color(0xFF7A4B29)
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.chevron_left_rounded,
                                              size: 16,
                                              color: currentPage > 1
                                                  ? const Color(0xFF7A4B29)
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Sebelumnya',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: currentPage > 1
                                                    ? const Color(0xFF7A4B29)
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Label Halaman X dari Y
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        'Hal $currentPage / $totalPages',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4A4A4A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Tombol Halaman Selanjutnya
                                    InkWell(
                                      onTap: currentPage < totalPages
                                          ? () {
                                              setState(() {
                                                _productCurrentPage++;
                                              });
                                            }
                                          : null,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: currentPage < totalPages
                                              ? Colors.white
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: currentPage < totalPages
                                                ? const Color(0xFF7A4B29)
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Selanjutnya',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: currentPage < totalPages
                                                    ? const Color(0xFF7A4B29)
                                                    : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 2),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: currentPage < totalPages
                                                  ? const Color(0xFF7A4B29)
                                                  : Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );

                                final infoText = Text(
                                  'Menampilkan ${totalItems == 0 ? 0 : startIndex + 1}-${startIndex + displayList.length} dari $totalItems produk',
                                  textAlign: isNarrow
                                      ? TextAlign.center
                                      : TextAlign.start,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6E6E6E),
                                  ),
                                );

                                if (isNarrow) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      infoText,
                                      const SizedBox(height: 10),
                                      Center(child: pageButtons),
                                    ],
                                  );
                                }

                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    infoText,
                                    pageButtons,
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tombol Tambah Produk (Ditempatkan di luar kotak produk persis sesuai gambar referensi)
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminAddProductPage()),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A4B29),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Tambah Produk',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Item Baris Produk pada List User Umum di Dashboard Admin
  Widget _buildProductListItem(AdminPublicProduct product) {
    return InkWell(
      onTap: () {
        final targetProduct =
            ProductService.instance.findProductById(product.id) ??
            Product(
              id: product.id,
              name: product.name,
              price: 0,
              description: '',
              imageUrl: product.imageUrl,
              category: product.hashtags,
              code: product.code,
              hashtags: product.hashtags,
              cageVariations: product.cageVariations,
              lastEditedDate: product.lastEditedDate,
            );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminEditProductPage(
              product: targetProduct,
              adminProduct: product,
            ),
          ),
        ).then((_) {
          if (mounted) setState(() {});
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Row(
          children: [
            // Thumbnail Kotak Abu-Abu Membulat dengan Gambar Logo Produk
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFD2D2D2),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildPublicProductThumbnail(product),
            ),
            const SizedBox(width: 16),

            // Detail Judul dan Hashtag Produk
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.hashtags,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9E9E9E),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicProductThumbnail(AdminPublicProduct product) {
    String imgUrl = product.imageUrl.trim();
    if (imgUrl.contains('images.unsplash.com')) {
      imgUrl = '';
    }

    // 1. Cek dari variasi sangkar
    if (imgUrl.isEmpty && product.cageVariations != null) {
      for (final v in product.cageVariations!) {
        final clean = v.imageUrl.trim();
        if (clean.isNotEmpty && !clean.contains('images.unsplash.com')) {
          imgUrl = clean;
          break;
        }
      }
    }

    // 2. Cek di ProductService catalog
    if (imgUrl.isEmpty) {
      final p = ProductService.instance.findProductById(product.id);
      if (p != null &&
          p.imageUrl.trim().isNotEmpty &&
          !p.imageUrl.contains('images.unsplash.com')) {
        imgUrl = p.imageUrl.trim();
      }
    }

    // 3. Cek di ProductService products list berdasarkan nama atau kode
    if (imgUrl.isEmpty) {
      final pName = product.name.trim().toLowerCase();
      final pCode = product.code.trim().toLowerCase();
      for (final item in ProductService.instance.products) {
        if ((item.name.trim().toLowerCase() == pName ||
                (item.code != null &&
                    item.code!.trim().toLowerCase() == pCode)) &&
            item.imageUrl.trim().isNotEmpty &&
            !item.imageUrl.contains('images.unsplash.com')) {
          imgUrl = item.imageUrl.trim();
          break;
        }
      }
    }

    // 4. Cek di custom products milik user di UserService
    if (imgUrl.isEmpty) {
      final pName = product.name.trim().toLowerCase();
      for (final u in UserService.instance.users) {
        for (final cp in u.customProducts) {
          if (cp.name.trim().toLowerCase() == pName &&
              cp.imageUrl.trim().isNotEmpty &&
              !cp.imageUrl.contains('images.unsplash.com')) {
            imgUrl = cp.imageUrl.trim();
            break;
          }
        }
        if (imgUrl.isNotEmpty) break;
      }
    }

    if (imgUrl.isNotEmpty) {
      return Product.buildImageFromSource(
        imgUrl,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        placeholder: const Center(
          child: Icon(
            Icons.add_photo_alternate_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      );
    }

    return const Center(
      child: Icon(
        Icons.add_photo_alternate_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  void _scrollCages(bool forward) {
    if (!_cageScrollController.hasClients) return;
    final current = _cageScrollController.offset;
    final target = forward ? current + 280 : current - 280;
    _cageScrollController.animateTo(
      target.clamp(0.0, _cageScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Bagian penambahan & pengelolaan bentuk sangkar persis seperti di gambar
  Widget _buildCageManagementSection() {
    final cages = CageService.instance.cages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kotak Putih Wadah Kartu Sangkar dengan Dukungan Scroll Lengkap (Mouse Drag, Wheel, Arrow)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent &&
                  _cageScrollController.hasClients) {
                final newOffset =
                    _cageScrollController.offset + pointerSignal.scrollDelta.dy;
                _cageScrollController.jumpTo(
                  newOffset.clamp(
                    0.0,
                    _cageScrollController.position.maxScrollExtent,
                  ),
                );
              }
            },
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: Scrollbar(
                controller: _cageScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _cageScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: CageService.instance.isLoading && cages.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF6D4C41),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Memuat bentuk sangkar dari database...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : cages.isEmpty
                        ? [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Belum ada bentuk sangkar di database (0 data). Klik "+ Tambah Bentuk Sangkar" untuk membuatnya.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : cages.map((cage) {
                            return Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.category_outlined,
                                    size: 18,
                                    color: Color(0xFF7A4B29),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    cage.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4A4A4A),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  InkWell(
                                    key: ValueKey('delete_cage_btn_${cage.id}'),
                                    onTap: () async {
                                      await CageService.instance.removeCage(cage.id);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Bentuk sangkar "${cage.name}" berhasil dihapus.',
                                            ),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 13,
                                        color: Color(0xFF444444),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Tombol "Tambah Sangkar" di Kanan Bawah
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _showAddCageDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A4B29),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Tambah Sangkar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Color(0xFF424242),
  );

  static const TextStyle _cellStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF4A4A4A),
  );
}
