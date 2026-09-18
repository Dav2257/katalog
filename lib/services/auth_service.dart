import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../supabase_config.dart';

/// Layanan terpusat untuk mengelola status autentikasi dan peran (Admin / Member).
/// Dengan ChangeNotifier dan persistensi SharedPreferences, setiap perubahan login/logout
/// akan tersimpan secara permanen di perangkat, sehingga status akun tidak hilang
/// saat melakukan Hot Reload, Hot Restart, maupun membuka ulang aplikasi.
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();

  static const String _keyIsLoggedIn = 'auth_is_logged_in';
  static const String _keyIsAdmin = 'auth_is_admin';
  static const String _keyUserPhone = 'auth_user_phone';
  static const String _keyUserEmail = 'auth_user_email';
  static const String _keyAdminName = 'auth_admin_name';
  static const String _keyAdminEmail = 'auth_admin_email';

  AuthService._internal();

  bool _isLoggedIn = false;
  bool _isAdmin = false;
  String _adminName = 'Admin 1';
  String _adminEmail = 'admin@gmail.com';

  String _userPhone = '';
  String _userEmail = '';

  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _isAdmin;
  String get adminName => _adminName;
  String get adminEmail => _adminEmail;
  String get userPhone => _userPhone;
  String get userEmail => _userEmail;

  /// Menginisialisasi status autentikasi dari penyimpanan lokal (SharedPreferences)
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      if (savedLoggedIn) {
        _isLoggedIn = true;
        _isAdmin = prefs.getBool(_keyIsAdmin) ?? false;
        _userPhone = prefs.getString(_keyUserPhone) ?? '';
        _userEmail = prefs.getString(_keyUserEmail) ?? '';
        _adminName = prefs.getString(_keyAdminName) ?? 'Admin 1';
        _adminEmail = prefs.getString(_keyAdminEmail) ?? 'admin@gmail.com';
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Catatan: Gagal memuat sesi autentikasi dari SharedPreferences: $e');
    }

    // Fallback: periksa sesi Supabase jika ada
    checkCurrentUser();
  }

  void checkCurrentUser() {
    try {
      final user = supabase.auth.currentUser;
      _isLoggedIn = user != null;
      _isAdmin = user?.email?.toLowerCase().contains('admin') == true;
      if (user?.email != null) _userEmail = user!.email!;
    } catch (_) {
      _isLoggedIn = false;
      _isAdmin = false;
    }
    notifyListeners();
  }

  Future<void> login({
    required bool isAdmin,
    String? phone,
    String? email,
    String? adminName,
  }) async {
    _isLoggedIn = true;
    _isAdmin = isAdmin;
    if (phone != null && phone.isNotEmpty) _userPhone = phone;
    if (email != null && email.isNotEmpty) _userEmail = email;
    if (adminName != null && adminName.isNotEmpty) _adminName = adminName;
    if (isAdmin && email != null && email.isNotEmpty) _adminEmail = email;

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setBool(_keyIsAdmin, _isAdmin);
      await prefs.setString(_keyUserPhone, _userPhone);
      await prefs.setString(_keyUserEmail, _userEmail);
      await prefs.setString(_keyAdminName, _adminName);
      await prefs.setString(_keyAdminEmail, _adminEmail);
    } catch (e) {
      debugPrint('Catatan: Gagal menyimpan sesi autentikasi: $e');
    }
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    _isLoggedIn = false;
    _isAdmin = false;
    _userPhone = '';
    _userEmail = '';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyIsAdmin);
      await prefs.remove(_keyUserPhone);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyAdminName);
      await prefs.remove(_keyAdminEmail);
    } catch (e) {
      debugPrint('Catatan: Gagal menghapus sesi autentikasi: $e');
    }
  }
}
