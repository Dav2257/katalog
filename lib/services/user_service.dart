import 'package:flutter/foundation.dart';

/// Model User Private untuk Admin Dashboard dan Registrasi Web
class AdminPrivateUser {
  final int no;
  final String phone;
  final String email;
  final String password;
  final String joinDate;
  final int requestCount;
  final List<String> customLogos;

  const AdminPrivateUser({
    required this.no,
    required this.phone,
    this.email = '',
    required this.password,
    required this.joinDate,
    required this.requestCount,
    this.customLogos = const ['Logo Merak', 'Logo Nusantara'],
  });

  AdminPrivateUser copyWith({
    int? no,
    String? phone,
    String? email,
    String? password,
    String? joinDate,
    int? requestCount,
    List<String>? customLogos,
  }) {
    return AdminPrivateUser(
      no: no ?? this.no,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      password: password ?? this.password,
      joinDate: joinDate ?? this.joinDate,
      requestCount: requestCount ?? this.requestCount,
      customLogos: customLogos ?? this.customLogos,
    );
  }
}

/// Service untuk mengelola data user private terdaftar di web katalog
class UserService extends ChangeNotifier {
  static final UserService instance = UserService._internal();

  UserService._internal();

  // Data user private (dikosongkan dari dummy bawaan)
  final List<AdminPrivateUser> _users = [];

  List<AdminPrivateUser> get users => List.unmodifiable(_users);

  /// Registrasi user baru saat mengisi form pendaftaran di web
  AdminPrivateUser registerUser({
    required String phone,
    required String password,
    String email = '',
    String? joinDate,
    List<String>? customLogos,
  }) {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    final dateStr = joinDate ?? '$day-$month-$year';

    // Periksa jika nomor telepon sudah terdaftar sebelumnya
    final existingIndex = _users.indexWhere((u) => u.phone == phone);
    if (existingIndex >= 0) {
      return _users[existingIndex];
    }

    final newUser = AdminPrivateUser(
      no: 1,
      phone: phone,
      email: email,
      password: password,
      joinDate: dateStr,
      requestCount: 0,
      customLogos: customLogos ?? const ['Logo Merak', 'Logo Nusantara'],
    );

    // Masukkan ke urutan paling atas agar langsung terlihat oleh Admin
    _users.insert(0, newUser);
    _reindex();
    notifyListeners();
    return newUser;
  }

  /// Update data user private (Nomor HP/Email atau Password)
  void updateUser({
    required int no,
    required String phone,
    required String password,
    String? email,
    List<String>? customLogos,
  }) {
    final index = _users.indexWhere((u) => u.no == no);
    if (index >= 0) {
      final old = _users[index];
      _users[index] = old.copyWith(
        phone: phone.trim(),
        password: password.trim(),
        email: email ?? old.email,
        customLogos: customLogos ?? old.customLogos,
      );
      notifyListeners();
    }
  }

  /// Mencari user berdasarkan no telp atau email dan password
  AdminPrivateUser? findUser(String identifier, String password) {
    final cleanId = identifier.trim().toLowerCase();
    for (final u in _users) {
      if ((u.phone == identifier.trim() || (u.email.isNotEmpty && u.email.toLowerCase() == cleanId)) &&
          u.password == password) {
        return u;
      }
    }
    return null;
  }

  /// Menambah jumlah request custom logo untuk nomor telepon tertentu
  void incrementRequestCount(String phone) {
    final index = _users.indexWhere((u) => u.phone == phone);
    if (index >= 0) {
      final old = _users[index];
      _users[index] = old.copyWith(requestCount: old.requestCount + 1);
      notifyListeners();
    }
  }

  /// Menambahkan custom logo baru ke profil user
  void addCustomLogoToUser(String phone, String logoName) {
    final index = _users.indexWhere((u) => u.phone == phone);
    if (index >= 0) {
      final old = _users[index];
      final updatedList = List<String>.from(old.customLogos)..add(logoName);
      _users[index] = old.copyWith(
        customLogos: updatedList,
        requestCount: old.requestCount + 1,
      );
      notifyListeners();
    }
  }

  void _reindex() {
    for (int i = 0; i < _users.length; i++) {
      _users[i] = _users[i].copyWith(no: i + 1);
    }
  }
}
