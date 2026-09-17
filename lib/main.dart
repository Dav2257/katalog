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
import 'services/order_service.dart';
import 'services/product_service.dart';
import 'services/user_service.dart';
import 'supabase_config.dart';
import 'widgets/hero_banner.dart';
import 'widgets/top_navbar.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );

  // Muat pengaturan toko (Banner, Logo, WhatsApp, Akun) yang tersimpan di Supabase
  await AppSettingsService.instance.loadSettings();

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettingsService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Jatimas',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: AppSettingsService.instance.fontFamily,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.grey.shade50,
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

  // State Status Login Pengguna & Role Admin
  bool _isLoggedIn = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_handleAuthUpdate);
    ProductService.instance.addListener(_handleProductUpdate);
    UserService.instance.addListener(_handleUserUpdate);
    _syncAuthFromService();
    ProductService.instance.fetchProducts();
    UserService.instance.fetchUsers();
    OrderService.instance.fetchOrders();
    CageService.instance.fetchCages();
  }

  void _syncAuthFromService() {
    _isLoggedIn = AuthService.instance.isLoggedIn;
    _isAdmin = AuthService.instance.isAdmin;
  }

  void _handleAuthUpdate() {
    if (!mounted) return;
    setState(() {
      _syncAuthFromService();
    });
  }

  void _handleProductUpdate() {
    if (mounted) setState(() {});
  }

  void _handleUserUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_handleAuthUpdate);
    ProductService.instance.removeListener(_handleProductUpdate);
    UserService.instance.removeListener(_handleUserUpdate);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Keranjang aktif sesuai status login saat ini (Data Tamu dan Member Terpisah 100%)
  List<CartItem> get _activeCart => _isLoggedIn ? _userCart : _guestCart;
  int get _totalCartCount =>
      _activeCart.fold(0, (sum, item) => sum + item.quantity);

  void _addToCart(Product product) {
    setState(() {
      final cart = _activeCart;
      final index = cart.indexWhere(
        (item) => item.product.id == product.id && item.cageType == null,
      );
      if (index >= 0) {
        cart[index].quantity++;
      } else {
        cart.add(CartItem(product: product, quantity: 1));
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
              _isLoggedIn = true;
              _isAdmin = isAdmin;
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
        _isLoggedIn = true;
        _isAdmin = isAdmin;
        _showStandardCatalogForUser = false;
      });
    } else if (result == true) {
      AuthService.instance.login(isAdmin: false);
      setState(() {
        _isLoggedIn = true;
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
      _isLoggedIn = false;
      _isAdmin = false;
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
      appBar: TopNavbar(
        searchController: _searchController,
        cartItemCount: _totalCartCount,
        isLoggedIn: _isLoggedIn,
        isAdmin: _isAdmin,
        onLogoTap: () {
          setState(() {
            _searchController.clear();
            _searchQuery = '';
            _showStandardCatalogForUser = false;
          });
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        onSearchChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        onCartTap: _openCartPage,
        onProfileTap: _openLoginPage,
        onLogout: _handleLogout,
      ),
      body: SingleChildScrollView(
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
              // Banner Navigasi Kembali bagi Member atau Admin yang sedang melihat Katalog Standar
              if (_isLoggedIn && _showStandardCatalogForUser)
                Container(
                  width: double.infinity,
                  color: const Color(0xFF382314),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 560;
                      final infoText = Text(
                        _isAdmin
                            ? 'Mode Preview: Katalog Sangkar Umum (Admin)'
                            : 'Menampilkan Katalog Sangkar Standar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );

                      final backBtn = TextButton.icon(
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
                            color: Color(0xFFFFD900),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            infoText,
                            const SizedBox(height: 4),
                            backBtn,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: infoText),
                          const SizedBox(width: 8),
                          backBtn,
                        ],
                      );
                    },
                  ),
                )
              else
                // Banner logo proyek untuk tamu
                const HeroBanner(),

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
                            childAspectRatio = 0.74;
                          } else if (width >= 540) {
                            crossAxisCount = 3;
                            childAspectRatio = 0.76;
                          } else {
                            crossAxisCount = 2;
                            childAspectRatio = 0.73;
                          }

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredProducts.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: childAspectRatio,
                                ),
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return _buildProductCard(product);
                            },
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
                    fit: BoxFit.cover,
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
                  // Kategori Produk
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Nama Produk (Ditetapkan tinggi pasti untuk 2 baris agar ukuran kartu 1 s/d 5 presisi sama persis)
                  SizedBox(
                    height: 32,
                    child: Text(
                      product.name,
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
