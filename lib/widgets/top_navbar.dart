import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class TopNavbar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onLogoTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onProfileTap;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final TextEditingController? searchController;
  final bool isLoggedIn;
  final bool isAdmin;
  final VoidCallback? onLogout;
  final VoidCallback? onSwitchRole;
  final int cartItemCount;

  const TopNavbar({
    super.key,
    this.onLogoTap,
    this.onCartTap,
    this.onProfileTap,
    this.onLogout,
    this.onSwitchRole,
    this.isLoggedIn = false,
    this.isAdmin = false,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.searchController,
    this.cartItemCount = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final style = AppSettingsService.instance.navbarStyle;
    final List<Color> gradientColors = style == 2
        ? const [Color(0xFF231812), Color(0xFF1B110B), Color(0xFF2A1C13)]
        : style == 3
            ? const [Color(0xFF5C3C22), Color(0xFF3B2414), Color(0xFF50321B)]
            : const [
                Color(0xFF4A301E),
                Color(0xFF382314),
                Color(0xFF2C190E),
                Color(0xFF482E1C),
                Color(0xFF5A3922),
              ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Logo di sebelah kiri (Brand Katalog)
              InkWell(
                onTap: onLogoTap ??
                    () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Navigasi ke Beranda'),
                          duration: Duration(milliseconds: 700),
                        ),
                      );
                    },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Katalog',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 2. Search bar putih kapsul sesuai referensi gambar
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        onSubmitted: onSearchSubmitted,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Superhero',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                          suffixIcon: Icon(
                            Icons.search_rounded,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // 3. Ikon Keranjang Putih dengan Indikator Badge yang Jelas
              Badge.count(
                count: cartItemCount,
                isLabelVisible: cartItemCount > 0,
                backgroundColor: const Color(0xFFD32F2F),
                textColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                child: IconButton(
                  onPressed: onCartTap ??
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Membuka Keranjang Belanja'),
                            duration: Duration(milliseconds: 700),
                          ),
                        );
                      },
                  icon: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 24,
                  ),
                  tooltip: 'Keranjang',
                ),
              ),

              const SizedBox(width: 4),

              // 4. Ikon Profil Putih (Account Circle) dengan Indikator Role
              InkWell(
                onTap: () {
                  if (!isLoggedIn) {
                    onProfileTap?.call();
                  } else {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
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
                                  color: isAdmin ? const Color(0xFFFFF8E1) : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAdmin ? Colors.amber.shade300 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isAdmin ? Colors.amber.shade700 : const Color(0xFF4A301E),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                isAdmin ? 'Administrator' : 'Member / Pengguna',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isAdmin ? Colors.amber.shade800 : Colors.blue.shade700,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isAdmin ? 'ADMIN' : 'MEMBER',
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
                                            isAdmin
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

                              if (onSwitchRole != null) ...[
                                const SizedBox(height: 8),
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.swap_horiz_rounded,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  title: Text(
                                    isAdmin ? 'Beralih ke Akun Member' : 'Beralih ke Akun Admin',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isAdmin
                                        ? 'Lihat aplikasi sebagai pengguna biasa (tanpa tombol tambah sangkar)'
                                        : 'Akses hak istimewa admin untuk menambah/mengatur sangkar',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onSwitchRole?.call();
                                  },
                                ),
                              ],

                              const SizedBox(height: 6),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.logout_rounded, color: Colors.red),
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
                                  onLogout?.call();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Icon(
                            isAdmin ? Icons.admin_panel_settings_rounded : Icons.account_circle,
                            color: isAdmin ? const Color(0xFFFFD900) : Colors.white,
                            size: 28,
                          ),
                          if (isLoggedIn)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isAdmin ? const Color(0xFFFFD900) : Colors.greenAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                        ],
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD900),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ADMIN',
                            style: TextStyle(
                              color: Color(0xFF382314),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
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
}
