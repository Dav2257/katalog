import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/product.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/cart_page.dart';
import 'pages/login_page.dart';
import 'pages/product_detail_page.dart';
import 'pages/user_home_page.dart';
import 'services/auth_service.dart';
import 'services/cage_service.dart';
import 'services/hashtag_service.dart';
import 'services/order_service.dart';
import 'services/product_service.dart';
import 'services/user_service.dart';
import 'supabase_config.dart';
import 'widgets/hero_banner.dart';
import 'widgets/top_navbar.dart';
import 'services/settings_service.dart';
import 'services/ai_assistant_service.dart';
import 'widgets/ai_assistant_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );

  // Muat status autentikasi yang tersimpan di perangkat (SharedPreferences)
  await AuthService.instance.init();

  // Muat pengaturan toko (Banner, Logo, WhatsApp, Akun) yang tersimpan di Supabase
  await AppSettingsService.instance.loadSettings();

  // Muat bentuk sangkar dari database Supabase (tabel bentuk_sangkar)
  await CageService.instance.fetchCages();

  // Inisialisasi AI Asisten (Hermes AI)
  await AiAssistantService.instance.init();

  runApp(const MyApp());
}

/// Menonaktifkan seluruh transisi pindah halaman agar perpindahan halaman instan
class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// ============================================================================
/// WARNA BACKGROUND HALAMAN UTAMA (KATALOG UMUM & KATALOG PRIVATE)
/// Ganti kode HEX di bawah ini jika ingin mengubah warna background halaman:
/// Contoh opsi warna:
/// - Color(0xFFF5EBE1) : Krem Lembut Elegan (Default sekarang)
/// - Color(0xFFF7EFE5) : Krem Hangat Cerah
/// - Color(0xFFF5ECD7) : Krem Kuning Gading / Warm Ivory
/// - Color(0xFFEDE4D3) : Krem Beige Klasik
/// ============================================================================
const Color kCatalogBackgroundColor = Color(0xFFF5ECD7);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettingsService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'JatiMas',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: AppSettingsService.instance.fontFamily,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            scaffoldBackgroundColor: kCatalogBackgroundColor,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: NoTransitionsBuilder(),
                TargetPlatform.iOS: NoTransitionsBuilder(),
                TargetPlatform.windows: NoTransitionsBuilder(),
                TargetPlatform.macOS: NoTransitionsBuilder(),
                TargetPlatform.linux: NoTransitionsBuilder(),
                TargetPlatform.fuchsia: NoTransitionsBuilder(),
              },
            ),
          ),
          home: const MyHomePage(title: 'Katalog'),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  // Infinite Scroll state untuk Katalog Produk Standar (Mencegah frame drop)
  int _publicProductLimit = 10;
  bool _isLoadingMorePublic = false;

  // State Keranjang Belanja Terpisah (Guest vs Member Login)
  final List<CartItem> _guestCart = [];
  final List<CartItem> _userCart = [];

  // Mendapatkan produk custom pribadi khusus milik user yang sedang login
  List<Product> get _currentUserCustomLogos {
    final currentPhone = AuthService.instance.userPhone;
    final currentEmail = AuthService.instance.userEmail;
    final identifier = currentPhone.isNotEmpty ? currentPhone : currentEmail;
    if (identifier.isEmpty) return [];
    return UserService.instance.getUserCustomProducts(identifier);
  }

  // Status Tampilan Katalog Standar untuk Member (Toggle jika ingin lihat produk umum)
  bool _showStandardCatalogForUser = false;

  // State Status Login Pengguna & Role Admin (Sinkron langsung dengan AuthService)
  bool get _isLoggedIn => AuthService.instance.isLoggedIn;
  bool get _isAdmin => AuthService.instance.isAdmin;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onMainCatalogScroll);
    AuthService.instance.addListener(_handleAuthUpdate);
    ProductService.instance.addListener(_handleProductUpdate);
    UserService.instance.addListener(_handleUserUpdate);
    AiAssistantService.instance.addListener(_handleAiUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ProductService.instance.fetchProducts();
      UserService.instance.fetchUsers();
      OrderService.instance.fetchOrders();
      CageService.instance.fetchCages();
      HashtagService.instance.fetchHashtags();
    });
  }

  void _onMainCatalogScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      _loadMorePublicProducts();
    }
  }

  void _loadMorePublicProducts([int? maxCount]) {
    if (_isLoadingMorePublic) return;
    final total = maxCount ?? ProductService.instance.products.length;
    if (_publicProductLimit >= total) return;

    setState(() {
      _isLoadingMorePublic = true;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _publicProductLimit = _publicProductLimit + 10;
          _isLoadingMorePublic = false;
        });
      }
    });
  }

  /// Memperbarui seluruh data katalog, pengaturan toko, dan akun saat user menarik layar ke bawah (Pull-to-Refresh)
  Future<void> _handleRefresh() async {
    try {
      await Future.wait([
        ProductService.instance.fetchProducts(),
        UserService.instance.fetchUsers(),
        OrderService.instance.fetchOrders(),
        CageService.instance.fetchCages(),
        HashtagService.instance.fetchHashtags(),
        AppSettingsService.instance.loadSettings(),
      ]);
    } catch (e) {
      debugPrint('Pull-to-refresh error: $e');
    }

    if (mounted) {
      setState(() {
        _publicProductLimit = 10;
      });
    }
  }

  void _handleAuthUpdate() {
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

  void _handleUserUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onMainCatalogScroll);
    AuthService.instance.removeListener(_handleAuthUpdate);
    ProductService.instance.removeListener(_handleProductUpdate);
    UserService.instance.removeListener(_handleUserUpdate);
    AiAssistantService.instance.removeListener(_handleAiUpdate);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleAiUpdate() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Keranjang aktif sesuai status login saat ini (Data Tamu dan Member Terpisah 100%)
  List<CartItem> get _activeCart => _isLoggedIn ? _userCart : _guestCart;
  int get _totalCartCount =>
      _activeCart.fold(0, (sum, item) => sum + item.quantity);

  void _addToCart(
    Product product, {
    int quantity = 1,
    String? note,
    String? cageType,
  }) {
    setState(() {
      final cart = _activeCart;
      final index = cart.indexWhere(
        (item) => item.product.id == product.id && item.cageType == cageType,
      );
      if (index >= 0) {
        cart[index].quantity += quantity;
        if (note != null && note.isNotEmpty) {
          cart[index].note = note;
        }
      } else {
        cart.add(CartItem(
          product: product,
          quantity: quantity,
          cageType: cageType,
          note: note,
        ));
      }
    });
  }

  void _openCartPage() async {
    final cart = _activeCart;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartPage(
          cartItems: cart,
          onUpdateQuantity: (item, newQuantity) {
            setState(() {
              item.quantity = newQuantity;
            });
          },
          onRemoveItem: (item) {
            setState(() {
              cart.remove(item);
            });
          },
          onClearCart: () {
            setState(() {
              cart.clear();
            });
          },
          onUpdateNote: (item, newNote) {
            setState(() {
              item.note = newNote;
            });
          },
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _openLoginPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(
          onLoginSuccess: ({isAdmin = false, phone, email}) {
            AuthService.instance.login(
              isAdmin: isAdmin,
              phone: phone,
              email: email,
            );
            setState(() {
              _showStandardCatalogForUser = false;
            });
          },
        ),
      ),
    );

    if (result is Map && result['isLoggedIn'] == true) {
      final isAdmin = result['isAdmin'] == true;
      final phone = result['phone'] as String?;
      final email = result['email'] as String?;
      AuthService.instance.login(isAdmin: isAdmin, phone: phone, email: email);
      setState(() {
        _showStandardCatalogForUser = false;
      });
    } else if (result == true) {
      AuthService.instance.login(isAdmin: false);
      setState(() {
        _showStandardCatalogForUser = false;
      });
    }
  }

  void _openProductDetailPage(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(
          product: product,
          cartItemCount: _totalCartCount,
          getCartItemCount: () => _totalCartCount,
          isLoggedIn: _isLoggedIn,
          isAdmin: _isAdmin,
          onCartTap: _openCartPage,
          onProfileTap: _openLoginPage,
          onLogout: _handleLogout,
          onAddItemsToCart: (items) {
            setState(() {
              final cart = _activeCart;
              for (final newItem in items) {
                final existingIndex = cart.indexWhere(
                  (item) =>
                      item.product.id == newItem.product.id &&
                      item.cageType == newItem.cageType &&
                      item.note == newItem.note,
                );

                if (existingIndex >= 0) {
                  cart[existingIndex].quantity += newItem.quantity;
                } else {
                  cart.add(newItem);
                }
              }
            });
          },
          onAddCustomToCart: (p, {cageSummary, note, totalQuantity = 1}) {
            setState(() {
              _activeCart.add(
                CartItem(
                  product: p,
                  quantity: totalQuantity,
                  cageType: cageSummary,
                  note: note,
                ),
              );
            });
          },
          onAddToCart: _addToCart,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _handleLogout() async {
    await AuthService.instance.logout();
    setState(() {
      _showStandardCatalogForUser = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda telah berhasil keluar dari akun.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleHomeTap() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _publicProductLimit = 10;
      _showStandardCatalogForUser = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showProfileBottomSheet() {
    if (!_isLoggedIn) {
      _openLoginPage();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Info Role Pengguna
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isAdmin
                      ? const Color(0xFFFFF8E1)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isAdmin
                        ? Colors.amber.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isAdmin
                            ? Colors.amber.shade700
                            : const Color(0xFF4A301E),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.person_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  AuthService.instance.userPhone.isNotEmpty
                                      ? AuthService.instance.userPhone
                                      : (AuthService.instance.userEmail.isNotEmpty
                                          ? AuthService.instance.userEmail
                                          : (_isAdmin ? 'Admin' : 'Member')),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _isAdmin
                                      ? Colors.amber.shade800
                                      : Colors.blue.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _isAdmin ? 'ADMIN' : 'MEMBER',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isAdmin
                                ? 'Memiliki hak akses penuh untuk mengatur varian sangkar'
                                : 'Melihat varian sangkar & melakukan pemesanan',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                  ),
                ),
                title: const Text(
                  'Keluar dari akun',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleLogout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFooterNavigation() {
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
              // 1. KIRI: KERANJANG
              Expanded(
                child: InkWell(
                  onTap: _openCartPage,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Badge.count(
                        count: _totalCartCount,
                        isLabelVisible: _totalCartCount > 0,
                        backgroundColor: const Color(0xFFD32F2F),
                        textColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        child: const Icon(
                          Icons.shopping_cart_rounded,
                          color: Color(0xFFF5ECD7),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Keranjang',
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

              // 2. TENGAH: BERANDA (RUMAH)
              Expanded(
                child: InkWell(
                  onTap: _handleHomeTap,
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
                            Icons.home_rounded,
                            color: Color(0xFF382314),
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Beranda',
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
                  onTap: _showProfileBottomSheet,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Icon(
                            _isAdmin
                                ? Icons.admin_panel_settings_rounded
                                : (_isLoggedIn
                                    ? Icons.account_circle_rounded
                                    : Icons.person_outline_rounded),
                            color: _isAdmin
                                ? const Color(0xFFFFD900)
                                : const Color(0xFFF5ECD7),
                            size: 24,
                          ),
                          if (_isLoggedIn)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isAdmin
                                    ? const Color(0xFFFFD900)
                                    : Colors.greenAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF2C1A0E),
                                  width: 1.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isAdmin
                            ? 'Admin'
                            : (_isLoggedIn ? 'Profil' : 'Profil'),
                        style: TextStyle(
                          color: _isAdmin
                              ? const Color(0xFFFFD900)
                              : const Color(0xFFF5ECD7),
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
    // 1. Jika Akun Admin Login dan tidak sedang dalam mode preview umum:
    // Tampilkan Halaman Mandiri Dashboard Admin Sesuai Gambar Referensi!
    if (_isLoggedIn && _isAdmin && !_showStandardCatalogForUser) {
      return AdminDashboardPage(
        onPreviewUmum: () {
          setState(() {
            _showStandardCatalogForUser = true;
          });
        },
        onLogout: _handleLogout,
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 650;

    final filteredProducts = ProductService.instance.products.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.code != null &&
              p.code!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
          (p.hashtags != null &&
              p.hashtags!.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();

    final filteredCustomLogos = _currentUserCustomLogos.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.code != null &&
              p.code!.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();

    return Scaffold(
      backgroundColor: kCatalogBackgroundColor,
      appBar: TopNavbar(
        searchController: _searchController,
        cartItemCount: _totalCartCount,
        isLoggedIn: _isLoggedIn,
        isAdmin: _isAdmin,
        hideActionsOnMobile: true,
        onLogoTap: _handleHomeTap,
        onSearchChanged: (value) {
          setState(() {
            _searchQuery = value;
            _publicProductLimit = 10;
          });
        },
        onCartTap: _openCartPage,
        onProfileTap: _openLoginPage,
        onLogout: _handleLogout,
      ),
      bottomNavigationBar: isMobile ? _buildMobileFooterNavigation() : null,
      floatingActionButton: (!_isAdmin && AiAssistantService.instance.isEnabled)
          ? Container(
              margin: EdgeInsets.only(bottom: isMobile ? 64 : 12),
              child: FloatingActionButton.extended(
                onPressed: () {
                  AiAssistantDialog.show(
                    context,
                    onAddToCart: _addToCart,
                    onOpenCart: _openCartPage,
                  );
                },
                backgroundColor: const Color(0xFF2C1A0E),
                foregroundColor: const Color(0xFFF5ECD7),
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(
                    color: Color(0xFFD4AF37),
                    width: 1.5,
                  ),
                ),
                icon: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFDF00), Color(0xFFD4AF37)],
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF2C1A0E),
                    size: 16,
                  ),
                ),
                label: const Text(
                  'AI Asisten',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: const Color(0xFFD4AF37),
        backgroundColor: const Color(0xFF1E281E),
        displacement: 40,
        strokeWidth: 3.0,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Jika User Sudah Login (bukan admin) dan tidak sedang beralih ke katalog umum:
            // Tampilkan Halaman Beranda Khusus User Login dengan Tombol Request & Katalog Logo Custom
            if (_isLoggedIn && !_isAdmin && !_showStandardCatalogForUser)
              UserHomePage(
                customLogos: filteredCustomLogos,
                onAddCustomLogo: (newCustomProduct) {
                  final currentPhone = AuthService.instance.userPhone;
                  final currentEmail = AuthService.instance.userEmail;
                  final identifier = currentPhone.isNotEmpty
                      ? currentPhone
                      : currentEmail;

                  UserService.instance.addCustomProductToUser(
                    identifier,
                    newCustomProduct,
                  );

                  setState(() {
                    _activeCart.add(
                      CartItem(
                        product: newCustomProduct,
                        quantity: 1,
                        cageType: newCustomProduct.selectedCage,
                        note:
                            newCustomProduct.customNote != null &&
                                newCustomProduct.customNote!.trim().isNotEmpty
                            ? newCustomProduct.customNote!.trim()
                            : null,
                      ),
                    );
                  });
                },
                onProductTap: _openProductDetailPage,
                onOpenStandardCatalog: () {
                  setState(() {
                    _showStandardCatalogForUser = true;
                  });
                },
                onCartTap: _openCartPage,
              )
            else ...[
              // Banner logo proyek (selalu tampil baik untuk tamu, admin, maupun user private)
              const HeroBanner(),

              // Tombol Navigasi Kembali bagi Member atau Admin yang sedang melihat Katalog Standar
              // Terletak di bawah banner dan di atas katalog, di sebelah kanan
              if (_isLoggedIn && _showStandardCatalogForUser)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 14.0,
                    right: 16.0,
                    left: 16.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showStandardCatalogForUser = false;
                        });
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 16,
                        color: Color(0xFFFFD900),
                      ),
                      label: Text(
                        _isAdmin
                            ? 'Kembali ke Dashboard Admin'
                            : 'Kembali ke Katalog Custom Saya',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF382314),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ),

              // Daftar Katalog Produk Standar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'Katalog Produk Pilihan'
                                : 'Hasil Pencarian (${filteredProducts.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                                _publicProductLimit = 10;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (ProductService.instance.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7A4B29),
                          ),
                        ),
                      )
                    else if (filteredProducts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 50.0,
                          horizontal: 20.0,
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty
                                    ? Icons.search_off_rounded
                                    : Icons.inventory_2_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Produk "$_searchQuery" tidak ditemukan'
                                    : 'Katalog Masih Kosong',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Coba gunakan kata kunci pencarian lain atau klik Reset.'
                                    : 'Belum ada produk yang ditambahkan. Produk yang dibuat oleh Admin akan otomatis muncul di sini.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final int crossAxisCount;
                          final double childAspectRatio;

                          if (width >= 750) {
                            crossAxisCount = 5;
                            childAspectRatio = 0.88;
                          } else if (width >= 540) {
                            crossAxisCount = 3;
                            childAspectRatio = 0.90;
                          } else {
                            crossAxisCount = 2;
                            childAspectRatio = 0.80;
                          }

                          final visibleProducts = filteredProducts
                              .take(_publicProductLimit)
                              .toList();
                          final hasMore =
                              filteredProducts.length > _publicProductLimit;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: visibleProducts.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 14,
                                      childAspectRatio: childAspectRatio,
                                    ),
                                itemBuilder: (context, index) {
                                  final product = visibleProducts[index];
                                  return _buildProductCard(product);
                                },
                              ),
                              const SizedBox(height: 20),
                              if (_isLoadingMorePublic)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.0,
                                    ),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF7A4B29),
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                )
                              else if (hasMore)
                                Center(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _loadMorePublicProducts(
                                      filteredProducts.length,
                                    ),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF7A4B29),
                                    ),
                                    label: Text(
                                      'Muat Lebih Banyak (${filteredProducts.length - _publicProductLimit} lagi)',
                                      style: const TextStyle(
                                        color: Color(0xFF7A4B29),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFF7A4B29),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                )
                              else if (filteredProducts.length > 10)
                                Center(
                                  child: Text(
                                    'Semua ${filteredProducts.length} produk telah ditampilkan',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildProductCard(Product product) {
    return InkWell(
      onTap: () => _openProductDetailPage(product),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Produk (Expanded memastikan semua kartu memiliki proporsi dan tinggi seragam)
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: Product.buildImageFromSource(
                    product.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Informasi Produk dengan Tinggi Pasti (Menyamakan Total Dimensi Kartu 1 s/d 5)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 6.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Kategori / Hashtag Produk Terpisah
                  SizedBox(
                    height: 20,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            (product.hashtagList.isNotEmpty
                                    ? product.hashtagList
                                    : [product.category])
                                .map((tag) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Nama Produk (Ditetapkan tinggi pasti untuk 2 baris agar ukuran kartu 1 s/d 5 presisi sama persis)
                  SizedBox(
                    height: 32,
                    child: Text(
                      product.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
