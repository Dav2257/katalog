import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class LoginPage extends StatefulWidget {
  final void Function({bool isAdmin})? onLoginSuccess;

  const LoginPage({super.key, this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan email / no telepon dan kata sandi'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Cek kecocokan di database lokal UserService (User Private terdaftar)
    final registeredUser = UserService.instance.findUser(identifier, password);
    if (registeredUser != null) {
      AuthService.instance.login(
        isAdmin: false,
        phone: registeredUser.phone,
        email: registeredUser.email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selamat datang kembali, ${registeredUser.phone}!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onLoginSuccess?.call(isAdmin: false);
        Navigator.pop(context, {'isLoggedIn': true, 'isAdmin': false});
      }
      setState(() => _isLoading = false);
      return;
    }

    // 2. Kredensial Admin Demo Cepat
    if (identifier.toLowerCase().contains('admin') && password == 'admin123') {
      AuthService.instance.login(isAdmin: true, email: identifier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil masuk sebagai Administrator!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onLoginSuccess?.call(isAdmin: true);
        Navigator.pop(context, {'isLoggedIn': true, 'isAdmin': true});
      }
      setState(() => _isLoading = false);
      return;
    }

    // 3. Autentikasi via Supabase jika terhubung
    try {
      final response = await supabase.auth.signInWithPassword(
        email: identifier,
        password: password,
      );

      final user = response.user;
      final role = user?.userMetadata?['role']?.toString().toLowerCase();
      final bool isAdmin = identifier.toLowerCase().contains('admin') || role == 'admin';

      if (mounted) {
        AuthService.instance.login(isAdmin: isAdmin, email: user?.email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAdmin ? 'Berhasil masuk sebagai Administrator!' : 'Berhasil masuk!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onLoginSuccess?.call(isAdmin: isAdmin);
        Navigator.pop(context, {'isLoggedIn': true, 'isAdmin': isAdmin});
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal login: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon dan password wajib diisi untuk registrasi.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon minimal 8 digit.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Simpan user baru ke UserService (langsung muncul di Dashboard Admin User Private)
      final newUser = UserService.instance.registerUser(
        phone: phone,
        password: password,
        email: email,
      );

      // 2. Jika email diisi dan Supabase online, sinkronkan ke Supabase Auth
      if (email.isNotEmpty) {
        try {
          await supabase.auth.signUp(
            email: email,
            password: password,
            data: {'phone': phone, 'role': 'member'},
          );
        } catch (_) {}
      }

      // 3. Login kan user yang baru registrasi
      AuthService.instance.login(
        isAdmin: false,
        phone: newUser.phone,
        email: newUser.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registrasi berhasil! Selamat datang, ${newUser.phone}.'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onLoginSuccess?.call(isAdmin: false);
        Navigator.pop(context, {'isLoggedIn': true, 'isAdmin': false});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal registrasi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleDemoLogin() {
    AuthService.instance.login(isAdmin: false, phone: '085732257048');
    widget.onLoginSuccess?.call(isAdmin: false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Berhasil masuk (Mode Demo Pengguna)'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, {'isLoggedIn': true, 'isAdmin': false});
  }

  void _handleDemoAdminLogin() {
    AuthService.instance.login(isAdmin: true, email: 'admin@gmail.com');
    widget.onLoginSuccess?.call(isAdmin: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Berhasil masuk sebagai Administrator (Mode Demo)'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, {'isLoggedIn': true, 'isAdmin': true});
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand Title: JATIMAS SANGKAR
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'JATIMAS ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'SANGKAR',
                style: TextStyle(
                  color: Color(0xFFFFD900),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Subtitle: Sangkar Burung Pilihan
        const Text(
          'Sangkar Burung Pilihan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),

        const SizedBox(height: 24),

        // Mode Switcher Tab (MASUK vs REGISTRASI)
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isRegisterMode = false),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isRegisterMode ? const Color(0xFFFFD900) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Masuk',
                      style: TextStyle(
                        color: !_isRegisterMode ? const Color(0xFF382314) : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isRegisterMode = true),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isRegisterMode ? const Color(0xFFFFD900) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Registrasi',
                      style: TextStyle(
                        color: _isRegisterMode ? const Color(0xFF382314) : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        if (_isRegisterMode) ...[
          // ==================== MODE REGISTRASI ====================
          const Text(
            'Registrasi Akun Baru',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Akun Anda otomatis terdaftar sebagai User Private',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),

          const SizedBox(height: 16),

          // Field: Nomor Telepon (Wajib)
          const Text(
            'No. Telepon / WhatsApp *',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Contoh: 081298765432',
              hintStyle: const TextStyle(color: Colors.black45, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Field: E-mail (Opsional)
          const Text(
            'E-mail (Opsional)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Example@gmail.com',
              hintStyle: const TextStyle(color: Colors.black45, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Field: Password (Wajib)
          const Text(
            'Password *',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Minimal 4 karakter',
              hintStyle: const TextStyle(color: Colors.black45, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
              suffixIconConstraints: const BoxConstraints(maxHeight: 34, maxWidth: 36),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Tombol Daftar Sekarang
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD900),
                foregroundColor: const Color(0xFF382314),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: EdgeInsets.zero,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF382314),
                      ),
                    )
                  : const Text(
                      'DAFTAR SEKARANG',
                      style: TextStyle(
                        color: Color(0xFF382314),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 10),

          Center(
            child: TextButton(
              onPressed: () => setState(() => _isRegisterMode = false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text(
                'Sudah punya akun? Masuk di sini',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ] else ...[
          // ==================== MODE MASUK ====================
          const Text(
            'Masuk ke akun anda',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 18),

          // Field: E-mail
          const Text(
            'E-mail',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Example@gmail.com / 0812...',
              hintStyle: const TextStyle(color: Colors.black45, fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Field: Password
          const Text(
            'Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
              suffixIconConstraints: const BoxConstraints(maxHeight: 34, maxWidth: 36),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Tombol Masuk
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9D9D9),
                foregroundColor: const Color(0xFF444444),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: EdgeInsets.zero,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF444444),
                      ),
                    )
                  : const Text(
                      'MASUK',
                      style: TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: TextButton(
              onPressed: () => setState(() => _isRegisterMode = true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFD900),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text(
                'Belum punya akun? Registrasi Sekarang',
                style: TextStyle(fontSize: 12, color: Color(0xFFFFD900), fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Tombol Demo Cepat Pengguna
          Center(
            child: TextButton(
              onPressed: _handleDemoLogin,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text(
                'Masuk Cepat (Mode Demo)',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),

          // Tombol Demo Khusus Admin
          Center(
            child: TextButton.icon(
              onPressed: _handleDemoAdminLogin,
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 14, color: Color(0xFFFFD900)),
              label: const Text(
                'Masuk sebagai Admin (Mode Demo)',
                style: TextStyle(fontSize: 12, color: Color(0xFFFFD900), fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232B1A),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          if (isWide) {
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/login_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 24,
                  left: 24,
                  child: SafeArea(child: _buildBackButton()),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: constraints.maxWidth * 0.08,
                    ),
                    child: SizedBox(
                      width: 320,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: _buildForm(context),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/login_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: SafeArea(child: _buildBackButton()),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                    child: SizedBox(
                      width: 320,
                      child: _buildForm(context),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
