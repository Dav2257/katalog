import 'package:flutter/foundation.dart';
import '../supabase_config.dart';

/// Layanan terpusat untuk mengelola status autentikasi dan peran (Admin / Member).
/// Dengan ChangeNotifier, setiap perubahan login/logout/switch role akan langsung
/// tersinkronisasi secara real-time ke semua halaman (Home, Detail Produk, dll).
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();

  AuthService._internal() {
    checkCurrentUser();
  }

  bool _isLoggedIn = false;
  bool _isAdmin = false;
  final String _adminName = 'Admin 1';
  final String _adminEmail = 'admin@gmail.com';

  String _userPhone = '085732257048';
  String _userEmail = '';

  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _isAdmin;
  String get adminName => _adminName;
  String get adminEmail => _adminEmail;
  String get userPhone => _userPhone;
  String get userEmail => _userEmail;

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

  void login({required bool isAdmin, String? phone, String? email}) {
    _isLoggedIn = true;
    _isAdmin = isAdmin;
    if (phone != null && phone.isNotEmpty) _userPhone = phone;
    if (email != null && email.isNotEmpty) _userEmail = email;
    notifyListeners();
  }

  void toggleRole() {
    _isAdmin = !_isAdmin;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    _isLoggedIn = false;
    _isAdmin = false;
    notifyListeners();
  }
}
