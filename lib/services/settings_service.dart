import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../supabase_config.dart';

/// Service untuk mengelola pengaturan toko/aplikasi oleh Admin,
/// mencakup nomor WhatsApp tujuan pesanan, pilihan banner katalog umum,
/// logo brand/aplikasi, wallpaper halaman login, akun administrator,
/// variasi style navbar, dan jenis font katalog umum.
class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._internal();

  AppSettingsService._internal();

  // Nomor WhatsApp tujuan pesanan (Default: 085732257048)
  String _adminWhatsApp = '085732257048';
  String get adminWhatsApp => _adminWhatsApp;

  // Kredensial Akun Administrator Resmi
  String _adminEmail = 'admin@jatimas.com';
  String _adminUsername = 'admin';
  String _adminPassword = 'admin123';

  String get adminEmail => _adminEmail;
  String get adminUsername => _adminUsername;
  String get adminPassword => _adminPassword;

  // Banner kustom untuk Dashboard Umum
  Uint8List? _bannerImageBytes;
  Uint8List? get bannerImageBytes => _bannerImageBytes;

  String? _bannerImageUrl;
  String? get bannerImageUrl => _bannerImageUrl;

  // Logo Toko / Brand Jatimas Sangkar (Bisa Diupload / URL / Default Asset)
  Uint8List? _logoImageBytes;
  Uint8List? get logoImageBytes => _logoImageBytes;

  String? _logoImageUrl;
  String? get logoImageUrl => _logoImageUrl;

  bool get hasCustomLogo =>
      (_logoImageBytes != null && _logoImageBytes!.isNotEmpty) ||
      (_logoImageUrl != null && _logoImageUrl!.trim().isNotEmpty);

  /// Widget penampil logo brand yang responsif terhadap perubahan custom upload/url atau fallback default asset
  Widget buildLogoWidget({
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    final int? cacheW = width != null ? (width * 3).round() : null;
    final int? cacheH = height != null ? (height * 3).round() : null;

    if (_logoImageBytes != null && _logoImageBytes!.isNotEmpty) {
      return Image.memory(
        _logoImageBytes!,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.medium,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/logo.png',
          width: width,
          height: height,
          fit: fit,
          filterQuality: FilterQuality.medium,
          cacheWidth: cacheW,
          cacheHeight: cacheH,
        ),
      );
    } else if (_logoImageUrl != null && _logoImageUrl!.trim().isNotEmpty) {
      return Product.buildImageFromSource(
        _logoImageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: Image.asset(
          'assets/images/logo.png',
          width: width,
          height: height,
          fit: fit,
          filterQuality: FilterQuality.medium,
          cacheWidth: cacheW,
          cacheHeight: cacheH,
        ),
      );
    }
    return Image.asset(
      'assets/images/logo.png',
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      cacheWidth: cacheW,
      cacheHeight: cacheH,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.pets,
        color: Color(0xFFD4AF37),
      ),
    );
  }

  // Wallpaper Kustom untuk Halaman Login (Bisa Diupload / URL)
  Uint8List? _loginWallpaperBytes;
  Uint8List? get loginWallpaperBytes => _loginWallpaperBytes;

  String? _loginWallpaperUrl;
  String? get loginWallpaperUrl => _loginWallpaperUrl;

  bool get hasCustomLoginWallpaper =>
      (_loginWallpaperBytes != null && _loginWallpaperBytes!.isNotEmpty) ||
      (_loginWallpaperUrl != null && _loginWallpaperUrl!.trim().isNotEmpty);

  // Variasi Layout Navbar Dashboard Umum (1, 2, atau 3)
  int _navbarStyle = 1;
  int get navbarStyle => _navbarStyle;

  // Jenis Font untuk Dashboard Umum
  String _fontFamily = 'Times New Roman';
  String get fontFamily => _fontFamily;

  /// Daftar contoh banner siap pakai untuk katalog umum
  static const List<String> sampleBanners = [
    'https://images.unsplash.com/photo-1548767797-d8c844163c4c?w=1200',
    'https://images.unsplash.com/photo-1552728089-57bdde30beb3?w=1200',
    'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?w=1200',
    'https://images.unsplash.com/photo-1541701494587-cb58502866ab?w=1200',
  ];

  /// Daftar contoh wallpaper siap pakai untuk halaman login
  static const List<String> sampleLoginWallpapers = [
    'https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?w=1600',
    'https://images.unsplash.com/photo-1448375240586-882707db888b?w=1600',
    'https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=1600',
    'https://images.unsplash.com/photo-1518495973542-4542c06a5843?w=1600',
  ];

  /// Daftar pilihan font yang didukung
  static const List<String> availableFonts = [
    'Times New Roman',
    'Outfit',
    'Poppins',
    'Roboto',
    'Playfair Display',
  ];

  /// Mengambil nomor WhatsApp yang sudah diformat dengan kode negara 62 untuk wa.me
  String get formattedWhatsAppDestination {
    String clean = _adminWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    } else if (!clean.startsWith('62')) {
      clean = '62$clean';
    }
    return clean;
  }

  /// Membuat link wa.me ke nomor WhatsApp Admin dengan pesan pesanan
  Uri createOrderWhatsAppUri({
    required String customerPhone,
    required List<String> itemDescriptions,
    String? orderCode,
    String? note,
  }) {
    final dest = formattedWhatsAppDestination;
    final itemsText = itemDescriptions.map((item) => '• $item').join('\n\n');
    final noteText = (note != null && note.trim().isNotEmpty) ? '\nCatatan: $note' : '';
    final codeHeader = orderCode != null && orderCode.trim().isNotEmpty
        ? '📦 No. Pesanan: #$orderCode\n'
        : '';
    final message =
        'Halo Admin Jatimas Sangkar, saya ingin memesan produk berikut:\n$codeHeader\n$itemsText$noteText\n\nNomor Kontak Saya: $customerPhone\nMohon informasi ketersediaan & prosesnya. Terima kasih!';

    return Uri.parse('https://wa.me/$dest?text=${Uri.encodeComponent(message)}');
  }

  /// Memperbarui pengaturan oleh Admin
  void updateSettings({
    String? adminWhatsApp,
    String? adminEmail,
    String? adminUsername,
    String? adminPassword,
    Uint8List? bannerImageBytes,
    String? bannerImageUrl,
    bool clearBanner = false,
    Uint8List? logoImageBytes,
    String? logoImageUrl,
    bool clearLogo = false,
    Uint8List? loginWallpaperBytes,
    String? loginWallpaperUrl,
    bool clearLoginWallpaper = false,
    int? navbarStyle,
    String? fontFamily,
  }) {
    if (adminWhatsApp != null && adminWhatsApp.trim().isNotEmpty) {
      _adminWhatsApp = adminWhatsApp.trim();
    }
    if (adminEmail != null && adminEmail.trim().isNotEmpty) {
      _adminEmail = adminEmail.trim();
    }
    if (adminUsername != null && adminUsername.trim().isNotEmpty) {
      _adminUsername = adminUsername.trim();
    }
    if (adminPassword != null && adminPassword.trim().isNotEmpty) {
      _adminPassword = adminPassword.trim();
    }

    if (clearBanner) {
      _bannerImageBytes = null;
      _bannerImageUrl = null;
    } else {
      if (bannerImageBytes != null) {
        _bannerImageBytes = bannerImageBytes;
      }
      if (bannerImageUrl != null) {
        _bannerImageUrl = bannerImageUrl.trim().isEmpty ? null : bannerImageUrl.trim();
      }
    }

    if (clearLogo) {
      _logoImageBytes = null;
      _logoImageUrl = null;
    } else {
      if (logoImageBytes != null) {
        _logoImageBytes = logoImageBytes;
      }
      if (logoImageUrl != null) {
        _logoImageUrl = logoImageUrl.trim().isEmpty ? null : logoImageUrl.trim();
      }
    }

    if (clearLoginWallpaper) {
      _loginWallpaperBytes = null;
      _loginWallpaperUrl = null;
    } else {
      if (loginWallpaperBytes != null) {
        _loginWallpaperBytes = loginWallpaperBytes;
      }
      if (loginWallpaperUrl != null) {
        _loginWallpaperUrl = loginWallpaperUrl.trim().isEmpty ? null : loginWallpaperUrl.trim();
      }
    }

    if (navbarStyle != null && navbarStyle >= 1 && navbarStyle <= 3) {
      _navbarStyle = navbarStyle;
    }
    if (fontFamily != null && fontFamily.trim().isNotEmpty) {
      _fontFamily = fontFamily.trim();
    }
    notifyListeners();
    saveSettingsToCloud();
  }

  /// Mengambil pengaturan tersimpan dari Supabase Storage (app_settings.json)
  Future<void> loadSettings() async {
    try {
      final downloadedBytes = await supabase.storage.from('katalog').download('app_settings.json');
      final jsonMap = jsonDecode(utf8.decode(downloadedBytes)) as Map<String, dynamic>;

      if (jsonMap['adminWhatsApp'] != null && jsonMap['adminWhatsApp'].toString().trim().isNotEmpty) {
        _adminWhatsApp = jsonMap['adminWhatsApp'].toString().trim();
      }
      if (jsonMap['adminEmail'] != null && jsonMap['adminEmail'].toString().trim().isNotEmpty) {
        _adminEmail = jsonMap['adminEmail'].toString().trim();
      }
      if (jsonMap['adminUsername'] != null && jsonMap['adminUsername'].toString().trim().isNotEmpty) {
        _adminUsername = jsonMap['adminUsername'].toString().trim();
      }
      if (jsonMap['adminPassword'] != null && jsonMap['adminPassword'].toString().trim().isNotEmpty) {
        _adminPassword = jsonMap['adminPassword'].toString().trim();
      }
      if (jsonMap.containsKey('bannerImageUrl')) {
        _bannerImageUrl = jsonMap['bannerImageUrl']?.toString();
      }
      if (jsonMap.containsKey('logoImageUrl')) {
        _logoImageUrl = jsonMap['logoImageUrl']?.toString();
      }
      if (jsonMap.containsKey('loginWallpaperUrl')) {
        _loginWallpaperUrl = jsonMap['loginWallpaperUrl']?.toString();
      }
      if (jsonMap['navbarStyle'] is num) {
        _navbarStyle = (jsonMap['navbarStyle'] as num).toInt();
      }
      if (jsonMap['fontFamily'] != null && jsonMap['fontFamily'].toString().trim().isNotEmpty) {
        _fontFamily = jsonMap['fontFamily'].toString().trim();
      }
      notifyListeners();
    } catch (_) {
      // Jika file app_settings.json belum ada di bucket katalog, gunakan nilai default
    }
  }

  /// Menyimpan pengaturan toko ke Supabase Storage (app_settings.json) agar permanen
  Future<void> saveSettingsToCloud() async {
    try {
      final jsonMap = {
        'adminWhatsApp': _adminWhatsApp,
        'adminEmail': _adminEmail,
        'adminUsername': _adminUsername,
        'adminPassword': _adminPassword,
        'bannerImageUrl': _bannerImageUrl,
        'logoImageUrl': _logoImageUrl,
        'loginWallpaperUrl': _loginWallpaperUrl,
        'navbarStyle': _navbarStyle,
        'fontFamily': _fontFamily,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(jsonMap)));

      await supabase.storage.from('katalog').uploadBinary(
            'app_settings.json',
            jsonBytes,
            fileOptions: const FileOptions(
              contentType: 'application/json',
              upsert: true,
            ),
          );
    } catch (e) {
      debugPrint('Gagal menyimpan app_settings.json ke Supabase: $e');
    }
  }

  /// Reset ke pengaturan default
  void resetToDefault() {
    _adminWhatsApp = '085732257048';
    _adminEmail = 'admin@jatimas.com';
    _adminUsername = 'admin';
    _adminPassword = 'admin123';
    _bannerImageBytes = null;
    _bannerImageUrl = null;
    _logoImageBytes = null;
    _logoImageUrl = null;
    _loginWallpaperBytes = null;
    _loginWallpaperUrl = null;
    _navbarStyle = 1;
    _fontFamily = 'Times New Roman';
    notifyListeners();
    saveSettingsToCloud();
  }
}
