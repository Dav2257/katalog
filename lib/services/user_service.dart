import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../supabase_config.dart';
import 'auth_service.dart';

/// Model User Private untuk Admin Dashboard dan Registrasi Web
class AdminPrivateUser {
  final int no;
  final String phone;
  final String email;
  final String password;
  final String joinDate;
  final int _customLogoCount;
  final List<Product> customProducts;

  const AdminPrivateUser({
    required this.no,
    required this.phone,
    this.email = '',
    required this.password,
    required this.joinDate,
    required int customLogoCount,
    this.customProducts = const [],
  }) : _customLogoCount = customLogoCount;

  /// Jumlah logo custom selalu sinkron dengan produk custom riil yang ada
  int get customLogoCount =>
      customProducts.isNotEmpty ? customProducts.length : _customLogoCount;
  int get requestCount => customLogoCount;
  List<String> get customLogos => customProducts.map((p) => p.name).toList();

  AdminPrivateUser copyWith({
    int? no,
    String? phone,
    String? email,
    String? password,
    String? joinDate,
    int? customLogoCount,
    int? requestCount,
    List<Product>? customProducts,
  }) {
    final prods = customProducts ?? this.customProducts;
    final count = customLogoCount ?? requestCount ?? prods.length;
    return AdminPrivateUser(
      no: no ?? this.no,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      password: password ?? this.password,
      joinDate: joinDate ?? this.joinDate,
      customLogoCount: count,
      customProducts: prods,
    );
  }
}

/// Service untuk mengelola data user private terdaftar di web katalog
/// Terintegrasi langsung dengan database Supabase (tabel user_private dan produk_custom)
class UserService extends ChangeNotifier {
  static final UserService instance = UserService._internal();

  UserService._internal();

  // Data user private di memori lokal
  final List<AdminPrivateUser> _users = [];

  List<AdminPrivateUser> get users => List.unmodifiable(_users);

  /// Mengambil data user private dan produk custom dari database Supabase
  Future<void> fetchUsers() async {
    try {
      final userRows = await supabase
          .from('user_private')
          .select()
          .order('created_at', ascending: false);

      List<dynamic> customProdRows = [];
      try {
        customProdRows = await supabase.from('produk_custom').select();
      } catch (e) {
        debugPrint('Tabel produk_custom belum siap atau kosong: $e');
      }

      final List<AdminPrivateUser> loadedUsers = [];
      int counter = 1;

      for (final rawUser in userRows) {
        final phone = rawUser['phone']?.toString().trim() ?? '';
        final email = rawUser['email']?.toString().trim() ?? '';
        
        // Abaikan user hantu yang tidak memiliki no telp dan email
        if (phone.isEmpty && email.isEmpty) continue;

        final password = rawUser['password']?.toString() ?? '';
        final joinDate = rawUser['join_date']?.toString() ?? '';
        int customLogoCount = (rawUser['jumlah_logo_custom'] is num)
            ? (rawUser['jumlah_logo_custom'] as num).toInt()
            : ((rawUser['request_count'] is num)
                ? (rawUser['request_count'] as num).toInt()
                : 0);

        // Cari produk custom yang dimiliki oleh user ini
        final userCustoms = <Product>[];
        for (final rawProd in customProdRows) {
          final owner = rawProd['user_identifier']?.toString().toLowerCase().trim();
          final isMatch = (phone.isNotEmpty && owner == phone.toLowerCase().trim()) ||
              (email.isNotEmpty && owner == email.toLowerCase().trim());

          if (isMatch) {
            userCustoms.add(Product.fromMap(rawProd).copyWith(isUserCustom: true));
          }
        }

        // Sinkronkan selalu jumlah logo custom dengan produk custom riil milik user private
        customLogoCount = userCustoms.length;

        loadedUsers.add(
          AdminPrivateUser(
            no: counter++,
            phone: phone,
            email: email,
            password: password,
            joinDate: joinDate,
            customLogoCount: customLogoCount,
            customProducts: userCustoms,
          ),
        );
      }

      _users.clear();
      _users.addAll(loadedUsers);
      _reindex();
      notifyListeners();
    } catch (e) {
      debugPrint('Catatan: Gagal memuat user dari Supabase: $e');
    }
  }

  /// Registrasi user baru dan menyimpannya ke Supabase
  Future<AdminPrivateUser> registerUser({
    required String phone,
    required String password,
    String email = '',
    String? joinDate,
    List<Product>? customProducts,
  }) async {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    final dateStr = joinDate ?? '$day-$month-$year';

    final cleanPhone = phone.trim();
    final cleanEmail = email.trim();

    // Jangan izinkan registrasi jika nomor telepon dan email sama-sama kosong
    if (cleanPhone.isEmpty && cleanEmail.isEmpty) {
      debugPrint('Peringatan: Pendaftaran dibatalkan karena nomor telepon dan email kosong.');
      return AdminPrivateUser(
        no: 1,
        phone: '',
        password: '',
        joinDate: dateStr,
        customLogoCount: 0,
      );
    }

    // Periksa jika sudah terdaftar di memori lokal
    final existingIndex = _users.indexWhere((u) =>
        (cleanPhone.isNotEmpty && u.phone == cleanPhone) ||
        (cleanEmail.isNotEmpty && u.email.toLowerCase() == cleanEmail.toLowerCase()));

    if (existingIndex >= 0) {
      return _users[existingIndex];
    }

    final initialLogos = customProducts ?? const [];
    final newUser = AdminPrivateUser(
      no: 1,
      phone: cleanPhone,
      email: cleanEmail,
      password: password.trim(),
      joinDate: dateStr,
      customLogoCount: initialLogos.length,
      customProducts: initialLogos,
    );

    _users.insert(0, newUser);
    _reindex();
    notifyListeners();

    // Simpan langsung ke database Supabase
    await _saveUserToSupabase(newUser);

    return newUser;
  }

  Future<bool> _saveUserToSupabase(AdminPrivateUser user) async {
    try {
      await supabase.from('user_private').insert({
        'phone': user.phone,
        'email': user.email,
        'password': user.password,
        'join_date': user.joinDate,
        'jumlah_logo_custom': user.customLogoCount,
        'request_count': user.customLogoCount,
      });
      debugPrint('SUKSES: User ${user.phone.isNotEmpty ? user.phone : user.email} berhasil disimpan ke Supabase.');
      return true;
    } catch (e) {
      debugPrint('PERINGATAN: Gagal menyimpan user_private ke Supabase: $e');
      debugPrint('Pastikan tabel "user_private" sudah dibuat di Supabase SQL Editor.');
      return false;
    }
  }

  /// Update data user private (Nomor HP, Email, atau Password) ke Supabase
  Future<void> updateUser({
    required int no,
    required String phone,
    required String password,
    String? email,
    List<Product>? customProducts,
  }) async {
    final index = _users.indexWhere((u) => u.no == no);
    if (index >= 0) {
      final old = _users[index];
      final newPhone = phone.trim();
      final newEmail = email != null ? email.trim() : old.email;
      final newPassword = password.trim();

      _users[index] = old.copyWith(
        phone: newPhone,
        password: newPassword,
        email: newEmail,
        customProducts: customProducts ?? old.customProducts,
      );
      notifyListeners();

      // Update di database Supabase
      try {
        if (old.phone.isNotEmpty) {
          await supabase.from('user_private').update({
            'phone': newPhone,
            'email': newEmail,
            'password': newPassword,
          }).eq('phone', old.phone);
        } else if (old.email.isNotEmpty) {
          await supabase.from('user_private').update({
            'phone': newPhone,
            'email': newEmail,
            'password': newPassword,
          }).eq('email', old.email);
        }
      } catch (e) {
        debugPrint('Catatan: Gagal update user_private di Supabase: $e');
      }
    }
  }

  /// Mencari user berdasarkan no telp atau email dan password di memori lokal
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

  /// Mencari user langsung ke database Supabase jika lokal belum terisi
  Future<AdminPrivateUser?> findUserInSupabase(String identifier, String password) async {
    try {
      final cleanId = identifier.trim();
      final rows = await supabase
          .from('user_private')
          .select()
          .or('phone.eq.$cleanId,email.ilike.$cleanId')
          .eq('password', password);

      if (rows.isNotEmpty) {
        final rawUser = rows.first;
        final phone = rawUser['phone']?.toString() ?? '';
        final email = rawUser['email']?.toString() ?? '';
        final joinDate = rawUser['join_date']?.toString() ?? '';
        final customLogoCount = (rawUser['jumlah_logo_custom'] is num)
            ? (rawUser['jumlah_logo_custom'] as num).toInt()
            : ((rawUser['request_count'] is num)
                ? (rawUser['request_count'] as num).toInt()
                : 0);

        final found = AdminPrivateUser(
          no: _users.length + 1,
          phone: phone,
          email: email,
          password: password,
          joinDate: joinDate,
          customLogoCount: customLogoCount,
        );

        final existingIndex = _users.indexWhere((u) =>
            (phone.isNotEmpty && u.phone == phone) ||
            (email.isNotEmpty && u.email.toLowerCase() == email.toLowerCase()));
        if (existingIndex < 0) {
          _users.add(found);
          notifyListeners();
        }
        return found;
      }
    } catch (e) {
      debugPrint('Catatan: Pencarian user di Supabase gagal: $e');
    }
    return null;
  }

  /// Mencari user berdasarkan identifier (nomor telepon atau email)
  AdminPrivateUser? findUserByIdentifier(String identifier) {
    if (identifier.trim().isEmpty) return null;
    final cleanId = identifier.trim().toLowerCase();
    for (final u in _users) {
      if (u.phone == identifier.trim() || (u.email.isNotEmpty && u.email.toLowerCase() == cleanId)) {
        return u;
      }
    }
    return null;
  }

  /// Mengambil daftar produk custom pribadi khusus milik user tertentu
  List<Product> getUserCustomProducts(String identifier) {
    if (identifier.trim().isEmpty) return [];
    final user = findUserByIdentifier(identifier);
    if (user != null) {
      return List.unmodifiable(user.customProducts);
    }
    return [];
  }

  /// Menambah jumlah logo custom yang di-request oleh user private tertentu
  Future<void> incrementCustomLogoCount(String identifier) async {
    final cleanId = identifier.trim().toLowerCase();
    final index = _users.indexWhere((u) =>
        u.phone == identifier.trim() || (u.email.isNotEmpty && u.email.toLowerCase() == cleanId));
    if (index >= 0) {
      final old = _users[index];
      final newCount = old.customLogoCount + 1;
      _users[index] = old.copyWith(customLogoCount: newCount);
      notifyListeners();

      try {
        if (old.phone.isNotEmpty) {
          await supabase.from('user_private').update({
            'jumlah_logo_custom': newCount,
            'request_count': newCount,
          }).eq('phone', old.phone);
        } else if (old.email.isNotEmpty) {
          await supabase.from('user_private').update({
            'jumlah_logo_custom': newCount,
            'request_count': newCount,
          }).eq('email', old.email);
        }
      } catch (e) {
        debugPrint('Catatan: Gagal update jumlah_logo_custom di Supabase: $e');
      }
    }
  }

  void incrementRequestCount(String identifier) {
    incrementCustomLogoCount(identifier);
  }

  /// Menambahkan produk custom pribadi ke user tertentu dan menyimpannya ke Supabase
  Future<void> addCustomProductToUser(String identifier, Product product) async {
    String cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      final p = AuthService.instance.userPhone;
      final e = AuthService.instance.userEmail;
      cleanId = p.isNotEmpty ? p : e;
    }

    if (cleanId.isEmpty) {
      debugPrint('Peringatan: Tidak dapat menambah produk custom tanpa identitas user.');
      return;
    }

    final lowerId = cleanId.toLowerCase();
    var index = _users.indexWhere((u) =>
        u.phone == cleanId || (u.email.isNotEmpty && u.email.toLowerCase() == lowerId));

    if (index < 0) {
      // Refresh dari database jika user baru mendaftar di sesi lain
      await fetchUsers();
      index = _users.indexWhere((u) =>
          u.phone == cleanId || (u.email.isNotEmpty && u.email.toLowerCase() == lowerId));
    }

    if (index >= 0) {
      final old = _users[index];
      final updatedList = List<Product>.from(old.customProducts)..insert(0, product);
      final newCount = updatedList.length;
      _users[index] = old.copyWith(
        customProducts: updatedList,
        customLogoCount: newCount,
      );
      notifyListeners();

      // Sinkronkan count logo ke Supabase
      try {
        if (old.phone.isNotEmpty) {
          await supabase.from('user_private').update({
            'jumlah_logo_custom': newCount,
            'request_count': newCount,
          }).eq('phone', old.phone);
        } else if (old.email.isNotEmpty) {
          await supabase.from('user_private').update({
            'jumlah_logo_custom': newCount,
            'request_count': newCount,
          }).eq('email', old.email);
        }
      } catch (_) {}
    } else {
      if (cleanId.isNotEmpty) {
        final isEmail = cleanId.contains('@');
        final newUser = await registerUser(
          phone: isEmail ? '' : cleanId,
          email: isEmail ? cleanId : '',
          password: 'user123',
          customProducts: [product],
        );
        await incrementCustomLogoCount(newUser.phone.isNotEmpty ? newUser.phone : newUser.email);
      }
    }

    // Simpan ke tabel produk_custom di Supabase
    try {
      await supabase.from('produk_custom').insert({
        'user_identifier': cleanId,
        'kode': product.code ?? 'A01',
        'nama': product.name,
        'harga': product.price,
        'deskripsi': product.description,
        'gambar_url': product.imageUrl,
        'kategori': product.category,
        'variasi': product.cageVariations?.map((v) => v.toMap()).toList(),
        'last_edited_date': product.lastEditedDate,
      });
      debugPrint('SUKSES: Produk custom berhasil disimpan ke tabel produk_custom Supabase');
    } catch (e) {
      debugPrint('PERINGATAN: Gagal simpan produk_custom ke Supabase: $e');
    }
  }

  /// Mengubah produk custom pribadi (nama, kode, gambar, variasi sangkar) di Supabase
  Future<void> updateCustomProductForUser(String identifier, Product updatedProduct) async {
    final cleanId = identifier.trim().toLowerCase();
    final index = _users.indexWhere((u) =>
        u.phone == identifier.trim() || (u.email.isNotEmpty && u.email.toLowerCase() == cleanId));

    if (index >= 0) {
      final old = _users[index];
      final prodList = List<Product>.from(old.customProducts);
      final prodIndex = prodList.indexWhere((p) => p.id == updatedProduct.id);
      if (prodIndex >= 0) {
        prodList[prodIndex] = updatedProduct;
      } else {
        prodList.insert(0, updatedProduct);
      }
      _users[index] = old.copyWith(customProducts: prodList);
      notifyListeners();
    }

    // Update di database Supabase
    try {
      final dataToUpdate = {
        'kode': updatedProduct.code,
        'nama': updatedProduct.name,
        'gambar_url': updatedProduct.imageUrl,
        'variasi': updatedProduct.cageVariations?.map((v) => v.toMap()).toList(),
        'last_edited_date': updatedProduct.lastEditedDate,
      };

      await supabase
          .from('produk_custom')
          .update(dataToUpdate)
          .match({
            'user_identifier': identifier.trim(),
            'nama': updatedProduct.name,
          });
    } catch (e) {
      debugPrint('Catatan: Gagal update produk_custom di Supabase: $e');
    }
  }

  /// Menghapus produk custom pribadi milik user tertentu di Supabase
  Future<void> deleteCustomProductForUser(String identifier, String productId) async {
    final cleanId = identifier.trim().toLowerCase();
    final index = _users.indexWhere((u) =>
        u.phone == identifier.trim() || (u.email.isNotEmpty && u.email.toLowerCase() == cleanId));

    Product? toDelete;
    if (index >= 0) {
      final old = _users[index];
      final prodList = List<Product>.from(old.customProducts);
      final pIndex = prodList.indexWhere((p) => p.id == productId);
      if (pIndex >= 0) {
        toDelete = prodList[pIndex];
        prodList.removeAt(pIndex);
      }
      final newCount = prodList.length;
      _users[index] = old.copyWith(
        customProducts: prodList,
        customLogoCount: newCount,
      );
      notifyListeners();

      // Sinkronkan pengurangan jumlah logo custom ke database Supabase
      try {
        if (old.phone.isNotEmpty) {
          await supabase.from('user_private').update({
            'jumlah_logo_custom': newCount,
            'request_count': newCount,
          }).eq('phone', old.phone);
        } else if (old.email.isNotEmpty) {
          await supabase.from('user_private').update({
            'jumlah_logo_custom': newCount,
            'request_count': newCount,
          }).eq('email', old.email);
        }
      } catch (e) {
        debugPrint('Catatan: Gagal update pengurangan jumlah_logo_custom di Supabase: $e');
      }
    }

    // Hapus dari database Supabase
    try {
      if (toDelete != null) {
        await supabase.from('produk_custom').delete().match({
          'user_identifier': identifier.trim(),
          'nama': toDelete.name,
        });
      }
    } catch (e) {
      debugPrint('Catatan: Gagal hapus produk_custom di Supabase: $e');
    }
  }

  void _reindex() {
    for (int i = 0; i < _users.length; i++) {
      _users[i] = _users[i].copyWith(no: i + 1);
    }
  }
}
