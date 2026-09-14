import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/cage_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
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
    canvas.drawArc(
      mainRect,
      math.pi * 0.45,
      math.pi * 1.45,
      true,
      paint,
    );

    // Potongan 1/4 terpisah sedikit ke kanan atas
    final sliceRect = Rect.fromCircle(
      center: Offset(center.dx + radius * 0.18, center.dy - radius * 0.18),
      radius: radius * 0.9,
    );
    canvas.drawArc(
      sliceRect,
      math.pi * 1.95,
      math.pi * 0.45,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Model Pesanan Masuk untuk Admin
class AdminIncomingOrder {
  final int no;
  final String phone;
  final String email;
  final String date;
  final int quantity;
  final String productCode;
  final String status;
  final String note;
  final String cageType;
  final String orderId;

  const AdminIncomingOrder({
    required this.no,
    required this.phone,
    this.email = '',
    required this.date,
    required this.quantity,
    required this.productCode,
    required this.status,
    this.note = '',
    this.cageType = '',
    this.orderId = '',
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
  });
}


class AdminDashboardPage extends StatefulWidget {
  final VoidCallback onPreviewUmum;
  final VoidCallback onLogout;
  final VoidCallback? onSwitchToMember;

  const AdminDashboardPage({
    super.key,
    required this.onPreviewUmum,
    required this.onLogout,
    this.onSwitchToMember,
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

  final GlobalKey _pesananKey = GlobalKey();
  final GlobalKey _userPrivateKey = GlobalKey();
  final GlobalKey _produkKey = GlobalKey();
  final GlobalKey _sangkarKey = GlobalKey();
  final GlobalKey _riwayatKey = GlobalKey();

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
  List<AdminPublicProduct> get _publicProducts => ProductService.instance.adminProducts;

  List<AdminPublicProduct> get _filteredPublicProducts {
    final nameQuery = _nameFilterController.text.trim().toLowerCase();
    final codeQuery = _codeFilterController.text.trim().toLowerCase();

    return _publicProducts.where((p) {
      final matchesName = nameQuery.isEmpty ||
          p.name.toLowerCase().contains(nameQuery) ||
          p.displayName.toLowerCase().contains(nameQuery) ||
          p.hashtags.toLowerCase().contains(nameQuery);
      final matchesCode = codeQuery.isEmpty ||
          p.code.toLowerCase().contains(codeQuery);
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
      final isFinished = order.currentStep >= 5 ||
          order.status.toLowerCase().contains('selesai') ||
          order.status.toLowerCase().contains('diterima');

      if (!isFinished) {
        final codeMatch = RegExp(r'^([A-Za-z0-9]+)').firstMatch(order.productName.trim());
        final code = (codeMatch != null && codeMatch.group(1)!.length <= 6)
            ? codeMatch.group(1)!
            : 'A01';

        final dateStr =
            '${order.orderDate.day.toString().padLeft(2, '0')}-${order.orderDate.month.toString().padLeft(2, '0')}-${order.orderDate.year}';

        list.add(
          AdminIncomingOrder(
            no: counter++,
            phone: order.phone,
            email: order.email,
            date: dateStr,
            quantity: order.quantity,
            productCode: code,
            status: order.status,
            note: order.note,
            cageType: order.cageTypeOrDesign,
            orderId: order.id,
          ),
        );
      }
    }

    // 2. Data pesanan masuk bawaan
    for (final inc in _incomingOrders) {
      list.add(
        AdminIncomingOrder(
          no: counter++,
          phone: inc.phone,
          date: inc.date,
          quantity: inc.quantity,
          productCode: inc.productCode,
          status: inc.status,
          note: inc.note,
          cageType: inc.cageType,
          orderId: inc.orderId,
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
      final isFinished = order.currentStep >= 5 ||
          order.status.toLowerCase().contains('selesai') ||
          order.status.toLowerCase().contains('diterima');
      if (isFinished) {
        final codeMatch = RegExp(r'^[A-Za-z0-9]+').firstMatch(order.productName);
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
            status: order.status.toLowerCase().contains('diterima') ? 'Diterima' : 'Selesai',
            customerName: 'Member App',
            cageType: order.cageTypeOrDesign,
            note: order.note,
          ),
        );
      }
    }

    return combined;
  }

  @override
  void initState() {
    super.initState();
    CageService.instance.addListener(_handleCageUpdate);
    OrderService.instance.addListener(_handleOrderUpdate);
    UserService.instance.addListener(_handleUserUpdate);
    ProductService.instance.addListener(_handleProductUpdate);
    ProductService.instance.fetchProducts();
    UserService.instance.fetchUsers();
    OrderService.instance.fetchOrders();
  }

  @override
  void dispose() {
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
    if (mounted) setState(() {});
  }

  void _handleOrderUpdate() {
    if (mounted) setState(() {});
  }

  void _handleUserUpdate() {
    if (mounted) setState(() {});
  }

  void _handleProductUpdate() {
    if (mounted) setState(() {});
  }

  void _scrollToMenu(String title) {
    if (title == 'Dashboard') {
      if (_mainScrollController.hasClients) {
        _mainScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
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
      );
    }
  }





  void _showAddCageDialog() {
    final nextNumber = CageService.instance.count + 1;
    final nameController = TextEditingController(text: 'Sangkar $nextNumber');
    String selectedImageUrl = CageService.sampleCageImages[(nextNumber - 1) % CageService.sampleCageImages.length];
    final imageController = TextEditingController(text: selectedImageUrl);
    Uint8List? uploadedImageBytes;
    String? uploadedFileName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.add_box_rounded, color: Color(0xFF7A4B29)),
                SizedBox(width: 8),
                Text('Tambah Bentuk Sangkar'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nama Bentuk Sangkar:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF555555)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Sangkar Segi Enam',
                      filled: true,
                      fillColor: const Color(0xFFF4F4F4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Foto / Gambar Sangkar:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF555555)),
                  ),
                  const SizedBox(height: 8),

                  // Preview Foto Sangkar (Mendukung File Upload Memori & URL)
                  Center(
                    child: Container(
                      width: 140,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA6A6A6),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (uploadedImageBytes != null && uploadedImageBytes!.isNotEmpty)
                          ? Image.memory(
                              uploadedImageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 36),
                              ),
                            )
                          : (selectedImageUrl.isNotEmpty)
                              ? Image.network(
                                  selectedImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 36),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 36),
                                ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tombol Unggah / Upload Gambar dari Perangkat (Galeri / File Komputer)
                  InkWell(
                    key: const ValueKey('upload_cage_image_btn'),
                    onTap: () async {
                      try {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          setDialogState(() {
                            uploadedImageBytes = bytes;
                            uploadedFileName = picked.name;
                            selectedImageUrl = '';
                            imageController.clear();
                          });
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Upload dari file terkendala: $e.\nAnda dapat menempelkan URL atau memilih contoh foto di bawah.'),
                            backgroundColor: const Color(0xFF7A4B29),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: uploadedImageBytes != null
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFBF6F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: uploadedImageBytes != null
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF7A4B29).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: uploadedImageBytes != null
                                  ? const Color(0xFFC8E6C9)
                                  : const Color(0xFFEFE5DC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              uploadedImageBytes != null
                                  ? Icons.check_circle_rounded
                                  : Icons.cloud_upload_rounded,
                              color: uploadedImageBytes != null
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF7A4B29),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  uploadedImageBytes != null
                                      ? 'Foto Berhasil Diunggah'
                                      : 'Upload Foto dari Galeri / File',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: uploadedImageBytes != null
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFF7A4B29),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  uploadedImageBytes != null
                                      ? (uploadedFileName ?? 'foto_sangkar.png')
                                      : 'Pilih file gambar sangkar langsung dari perangkat',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: uploadedImageBytes != null
                                        ? const Color(0xFF388E3C)
                                        : const Color(0xFF757575),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (uploadedImageBytes != null)
                            InkWell(
                              onTap: () {
                                setDialogState(() {
                                  uploadedImageBytes = null;
                                  uploadedFileName = null;
                                  selectedImageUrl = CageService.sampleCageImages[0];
                                  imageController.text = selectedImageUrl;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Opsi Alternatif: Input URL Foto
                  TextField(
                    controller: imageController,
                    onChanged: (val) {
                      setDialogState(() {
                        selectedImageUrl = val.trim();
                        if (val.trim().isNotEmpty) {
                          uploadedImageBytes = null;
                          uploadedFileName = null;
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Atau tempel Link / URL Foto...',
                      labelText: 'Atau Masukkan URL Foto',
                      filled: true,
                      fillColor: const Color(0xFFF4F4F4),
                      prefixIcon: const Icon(Icons.link, size: 20, color: Color(0xFF7A4B29)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Pilihan Gambar Contoh:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF777777)),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: CageService.sampleCageImages.map((img) {
                        final isChosen = selectedImageUrl == img && uploadedImageBytes == null;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedImageUrl = img;
                                imageController.text = img;
                                uploadedImageBytes = null;
                                uploadedFileName = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isChosen ? const Color(0xFF7A4B29) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(img, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      }).toList(),
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
                onPressed: () {
                  final name = nameController.text.trim().isNotEmpty
                      ? nameController.text.trim()
                      : 'Sangkar $nextNumber';
                  CageService.instance.addCage(
                    name: name,
                    imageUrl: uploadedImageBytes != null ? null : selectedImageUrl,
                    imageBytes: uploadedImageBytes,
                  );
                  Navigator.pop(ctx);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_cageScrollController.hasClients) {
                      _cageScrollController.animateTo(
                        _cageScrollController.position.maxScrollExtent + 300,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Bentuk sangkar "$name" berhasil ditambahkan!'),
                      backgroundColor: const Color(0xFF7A4B29),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A4B29),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Simpan Sangkar'),
              ),
            ],
          );
        },
      ),
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
                    child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService.instance.adminName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        AuthService.instance.adminEmail,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: Colors.black87),
                title: const Text('Preview Katalog Umum'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onPreviewUmum();
                },
              ),
              if (widget.onSwitchToMember != null)
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded, color: Colors.black87),
                  title: const Text('Beralih ke Akun Member'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onSwitchToMember!();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Keluar dari Akun Admin', style: TextStyle(color: Colors.redAccent)),
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
                _buildSidebar(width: 210),

                // Area Konten Utama
                Expanded(
                  child: _buildMainContent(isDesktop: true),
                ),
              ],
            ),
          );
        } else {
          // Tampilan Mobile / Tablet: Drawer Sidebar
          return Scaffold(
            backgroundColor: const Color(0xFFEDEDED),
            appBar: AppBar(
              backgroundColor: const Color(0xFF382314),
              elevation: 1,
              title: const Text(
                'Dashboard Admin',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                  onPressed: _showProfileMenu,
                ),
              ],
            ),
            drawer: Drawer(
              child: _buildSidebar(width: double.infinity, inDrawer: true),
            ),
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
          // Bagian Header Atas Sidebar
          SizedBox(height: inDrawer ? 50 : 130),

          // Daftar Item Menu
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedMenuIndex == index;
                final title = _menuItems[index];

                return InkWell(
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
                  child: Container(
                    height: 42,
                    color: isSelected ? const Color(0xFF5A3922) : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        PieChartIcon(
                          size: 16,
                          color: isSelected ? Colors.white : const Color(0xFFE8DBD1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? Colors.white : const Color(0xFFE8DBD1),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Info Admin di Kiri
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService.instance.adminName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        AuthService.instance.adminEmail,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Tombol Profil di Kanan
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
              final totalOrders = _allCompletedOrders.length + _allIncomingOrders.length;
              final totalCustomLogos = UserService.instance.users.fold<int>(0, (sum, u) => sum + u.customLogoCount);
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
          KeyedSubtree(
            key: _riwayatKey,
            child: _buildSectionHeader('Riwayat'),
          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1050),
          child: DataTable(
            horizontalMargin: 28,
            columnSpacing: 42,
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
            rows: incomingList.map((order) {
              return DataRow(
                cells: [
                  DataCell(Text('${order.no}.', style: _cellStyle)),
                  DataCell(
                    Text(
                      order.phone.trim().isNotEmpty ? order.phone : (order.email.trim().isNotEmpty ? order.email : '-'),
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
                      key: ValueKey('order_detail_${order.phone}_${order.no}'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminOrderDetailPage(order: order),
                          ),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A4B29),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        minimumSize: const Size(60, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
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
              Icon(Icons.assignment_turned_in_outlined, size: 44, color: Colors.grey.shade400),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1050),
          child: DataTable(
            horizontalMargin: 28,
            columnSpacing: 42,
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
                      key: ValueKey('completed_order_phone_${order.phone}_${order.no}'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminCompletedOrderDetailPage(order: order),
                          ),
                        );
                      },
                      child: Text(
                        order.phone.trim().isNotEmpty ? order.phone : (order.email.trim().isNotEmpty ? order.email : '-'),
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
                      key: ValueKey('completed_order_detail_${order.phone}_${order.no}'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminCompletedOrderDetailPage(order: order),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A4B29),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        minimumSize: const Size(60, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
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
              Icon(Icons.people_outline_rounded, size: 44, color: Colors.grey.shade400),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1050),
          child: DataTable(
            horizontalMargin: 28,
            columnSpacing: 46,
            headingRowHeight: 52,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 58,
            columns: const [
              DataColumn(label: Text('No.', style: _headerStyle)),
              DataColumn(label: Text('No. Telp', style: _headerStyle)),
              DataColumn(label: Text('Email', style: _headerStyle)),
              DataColumn(label: Text('Password', style: _headerStyle)),
              DataColumn(label: Text('Tgl Masuk', style: _headerStyle)),
              DataColumn(label: Text('Jumlah Logo Custom', style: _headerStyle)),
              DataColumn(label: Text('Action', style: _headerStyle)),
            ],
            rows: _privateUsers.map((user) {
              return DataRow(
                cells: [
                  DataCell(Text('${user.no}.', style: _cellStyle)),
                  DataCell(Text(user.phone.isNotEmpty ? user.phone : '-', style: _cellStyle)),
                  DataCell(Text(user.email.isNotEmpty ? user.email : '-', style: _cellStyle)),
                  DataCell(Text(user.password, style: _cellStyle)),
                  DataCell(Text(user.joinDate, style: _cellStyle)),
                  DataCell(Text('${user.customLogoCount}', style: _cellStyle)),
                  DataCell(
                    ElevatedButton(
                      key: ValueKey('user_detail_${user.phone.isNotEmpty ? user.phone : user.email}'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        minimumSize: const Size(60, 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// List Produk yang akan ditampilkan di user umum persis seperti di gambar
  Widget _buildPublicProductsSection() {
    final filteredList = _filteredPublicProducts;

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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
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
                    onChanged: (_) => setState(() {}),
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
                    onChanged: (_) => setState(() {}),
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
          const SizedBox(height: 16),

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
                        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
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
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredList.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Color(0xFFE4E4E4),
                      height: 12,
                      thickness: 1,
                    ),
                    itemBuilder: (context, index) {
                      final product = filteredList[index];
                      return InkWell(
                        onTap: () {
                          final targetProduct = ProductService.instance.findProductById(product.id) ??
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
                              // Thumbnail Kotak Abu-Abu Membulat
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD2D2D2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
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
                    },
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
            MaterialPageRoute(
              builder: (_) => const AdminAddProductPage(),
            ),
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  ],
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
              if (pointerSignal is PointerScrollEvent && _cageScrollController.hasClients) {
                final newOffset = _cageScrollController.offset + pointerSignal.scrollDelta.dy;
                _cageScrollController.jumpTo(
                  newOffset.clamp(0.0, _cageScrollController.position.maxScrollExtent),
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
                    children: cages.map((cage) {
                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 14),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Thumbnail Kotak Gambar Berfoto Persis Gambar User (Biar ngga kosongan)
                            Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 85,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA6A6A6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: cage.buildImage(
                                    fit: BoxFit.cover,
                                    placeholder: const Center(
                                      child: Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 28),
                                    ),
                                  ),
                                ),
                                if (cages.length > 1)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: InkWell(
                                      key: ValueKey('delete_cage_btn_${cage.id}'),
                                      onTap: () {
                                        CageService.instance.removeCage(cage.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Bentuk sangkar "${cage.name}" berhasil dihapus.'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Nama Bentuk Sangkar
                            Text(
                              cage.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A4A4A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
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
