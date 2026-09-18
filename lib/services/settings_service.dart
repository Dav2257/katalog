import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../supabase_config.dart';
import 'cage_service.dart';

/// Service untuk mengelola pengaturan toko/aplikasi oleh Admin,
/// mencakup nomor WhatsApp tujuan pesanan, pilihan banner katalog umum,
/// logo brand/aplikasi, wallpaper halaman login, akun administrator,
/// variasi style navbar, dan jenis font katalog umum.
class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._internal();

  AppSettingsService._internal();

  // Keys untuk SharedPreferences lokal
  static const String _prefWa = 'app_settings_admin_wa';
  static const String _prefEmail = 'app_settings_admin_email';
  static const String _prefUsername = 'app_settings_admin_user';
  static const String _prefPassword = 'app_settings_admin_pass';
  static const String _prefBannerUrl = 'app_settings_banner_url';
  static const String _prefBannerBase64 = 'app_settings_banner_b64';
  static const String _prefLogoUrl = 'app_settings_logo_url';
  static const String _prefLogoBase64 = 'app_settings_logo_b64';
  static const String _prefWallpaperUrl = 'app_settings_wallpaper_url';
  static const String _prefWallpaperBase64 = 'app_settings_wallpaper_b64';
  static const String _prefNavbarStyle = 'app_settings_navbar_style';
  static const String _prefFontFamily = 'app_settings_font_family';

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

  /// Helper untuk mengekstrak bytes dari data URI atau base64
  static Uint8List? _decodeBase64Safe(String? src) {
    if (src == null || src.isEmpty) return null;
    try {
      final clean = src.trim();
      final commaIdx = clean.indexOf(',');
      final rawB64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
      final normalized = rawB64.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

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
      // Jika bytes ada tapi URL kosong, jadikan base64 data URI agar permanen
      if (_bannerImageBytes != null && (_bannerImageUrl == null || _bannerImageUrl!.isEmpty)) {
        _bannerImageUrl = 'data:image/png;base64,${base64Encode(_bannerImageBytes!)}';
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
      // Jika bytes ada tapi URL kosong, jadikan base64 data URI agar permanen
      if (_logoImageBytes != null && (_logoImageUrl == null || _logoImageUrl!.isEmpty)) {
        _logoImageUrl = 'data:image/png;base64,${base64Encode(_logoImageBytes!)}';
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
      // Jika bytes ada tapi URL kosong, jadikan base64 data URI agar permanen
      if (_loginWallpaperBytes != null && (_loginWallpaperUrl == null || _loginWallpaperUrl!.isEmpty)) {
        _loginWallpaperUrl = 'data:image/png;base64,${base64Encode(_loginWallpaperBytes!)}';
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

  /// Memuat pengaturan: pertama dari SharedPreferences lokal (instan & offline),
  /// lalu tersinkronisasi dari Supabase (Storage & Database)
  Future<void> loadSettings() async {
    // 1. Muat dari SharedPreferences lokal terlebih dahulu agar tampilan instan & anti-reset
    try {
      final prefs = await SharedPreferences.getInstance();
      final localWa = prefs.getString(_prefWa);
      if (localWa != null && localWa.trim().isNotEmpty) _adminWhatsApp = localWa.trim();

      final localEmail = prefs.getString(_prefEmail);
      if (localEmail != null && localEmail.trim().isNotEmpty) _adminEmail = localEmail.trim();

      final localUser = prefs.getString(_prefUsername);
      if (localUser != null && localUser.trim().isNotEmpty) _adminUsername = localUser.trim();

      final localPass = prefs.getString(_prefPassword);
      if (localPass != null && localPass.trim().isNotEmpty) _adminPassword = localPass.trim();

      final localBannerUrl = prefs.getString(_prefBannerUrl);
      if (localBannerUrl != null && localBannerUrl.trim().isNotEmpty) {
        _bannerImageUrl = localBannerUrl.trim();
      }
      final localBannerB64 = prefs.getString(_prefBannerBase64);
      if (localBannerB64 != null && localBannerB64.trim().isNotEmpty) {
        _bannerImageBytes = _decodeBase64Safe(localBannerB64);
      } else if (_bannerImageUrl != null && _bannerImageUrl!.startsWith('data:image')) {
        _bannerImageBytes = _decodeBase64Safe(_bannerImageUrl);
      }

      final localLogoUrl = prefs.getString(_prefLogoUrl);
      if (localLogoUrl != null && localLogoUrl.trim().isNotEmpty) {
        _logoImageUrl = localLogoUrl.trim();
      }
      final localLogoB64 = prefs.getString(_prefLogoBase64);
      if (localLogoB64 != null && localLogoB64.trim().isNotEmpty) {
        _logoImageBytes = _decodeBase64Safe(localLogoB64);
      } else if (_logoImageUrl != null && _logoImageUrl!.startsWith('data:image')) {
        _logoImageBytes = _decodeBase64Safe(_logoImageUrl);
      }

      final localWallpaperUrl = prefs.getString(_prefWallpaperUrl);
      if (localWallpaperUrl != null && localWallpaperUrl.trim().isNotEmpty) {
        _loginWallpaperUrl = localWallpaperUrl.trim();
      }
      final localWallpaperB64 = prefs.getString(_prefWallpaperBase64);
      if (localWallpaperB64 != null && localWallpaperB64.trim().isNotEmpty) {
        _loginWallpaperBytes = _decodeBase64Safe(localWallpaperB64);
      } else if (_loginWallpaperUrl != null && _loginWallpaperUrl!.startsWith('data:image')) {
        _loginWallpaperBytes = _decodeBase64Safe(_loginWallpaperUrl);
      }

      final localNavStyle = prefs.getInt(_prefNavbarStyle);
      if (localNavStyle != null && localNavStyle >= 1 && localNavStyle <= 3) {
        _navbarStyle = localNavStyle;
      }

      final localFont = prefs.getString(_prefFontFamily);
      if (localFont != null && localFont.trim().isNotEmpty) {
        _fontFamily = localFont.trim();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error memuat SharedPreferences lokal: $e');
    }

    // 2. Sinkronisasi dari Supabase (Tabel Database public.app_settings atau File Storage app_settings.json)
    try {
      Map<String, dynamic>? cloudMap;

      // Coba ambil dari tabel database app_settings jika tabel tersedia
      try {
        final dbResult = await supabase
            .from('app_settings')
            .select('settings_json')
            .eq('id', 'global_settings')
            .maybeSingle();
        if (dbResult != null && dbResult['settings_json'] is Map) {
          cloudMap = Map<String, dynamic>.from(dbResult['settings_json'] as Map);
          debugPrint('SettingsService: Sukses memuat dari tabel public.app_settings');
        }
      } catch (_) {}

      // Jika tabel belum ada atau kosong, coba ambil dari Supabase Storage
      if (cloudMap == null) {
        final buckets = ['katalog', 'images', 'uploads', 'public'];
        for (final bucket in buckets) {
          try {
            final downloadedBytes = await supabase.storage.from(bucket).download('app_settings.json');
            cloudMap = jsonDecode(utf8.decode(downloadedBytes)) as Map<String, dynamic>;
            debugPrint('SettingsService: Sukses memuat app_settings.json dari Storage $bucket');
            break;
          } catch (_) {}
        }
      }

      if (cloudMap != null) {
        _applyJsonMap(cloudMap);
        _saveToLocalPrefs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('SettingsService: Menggunakan cache lokal/default (Supabase load: $e)');
    }
  }

  void _applyJsonMap(Map<String, dynamic> jsonMap) {
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
      final val = jsonMap['bannerImageUrl']?.toString();
      if (val != null && val.trim().isNotEmpty) {
        _bannerImageUrl = val.trim();
        if (_bannerImageUrl!.startsWith('data:image')) {
          _bannerImageBytes = _decodeBase64Safe(_bannerImageUrl);
        }
      }
    }
    if (jsonMap.containsKey('logoImageUrl')) {
      final val = jsonMap['logoImageUrl']?.toString();
      if (val != null && val.trim().isNotEmpty) {
        _logoImageUrl = val.trim();
        if (_logoImageUrl!.startsWith('data:image')) {
          _logoImageBytes = _decodeBase64Safe(_logoImageUrl);
        }
      }
    }
    if (jsonMap.containsKey('loginWallpaperUrl')) {
      final val = jsonMap['loginWallpaperUrl']?.toString();
      if (val != null && val.trim().isNotEmpty) {
        _loginWallpaperUrl = val.trim();
        if (_loginWallpaperUrl!.startsWith('data:image')) {
          _loginWallpaperBytes = _decodeBase64Safe(_loginWallpaperUrl);
        }
      }
    }
    if (jsonMap['navbarStyle'] is num) {
      _navbarStyle = (jsonMap['navbarStyle'] as num).toInt();
    }
    if (jsonMap['fontFamily'] != null && jsonMap['fontFamily'].toString().trim().isNotEmpty) {
      _fontFamily = jsonMap['fontFamily'].toString().trim();
    }
  }

  /// Menyimpan pengaturan ke SharedPreferences secara instan
  Future<void> _saveToLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefWa, _adminWhatsApp);
      await prefs.setString(_prefEmail, _adminEmail);
      await prefs.setString(_prefUsername, _adminUsername);
      await prefs.setString(_prefPassword, _adminPassword);

      if (_bannerImageUrl != null && _bannerImageUrl!.isNotEmpty) {
        await prefs.setString(_prefBannerUrl, _bannerImageUrl!);
      } else {
        await prefs.remove(_prefBannerUrl);
      }
      if (_bannerImageBytes != null && _bannerImageBytes!.isNotEmpty) {
        await prefs.setString(_prefBannerBase64, base64Encode(_bannerImageBytes!));
      } else {
        await prefs.remove(_prefBannerBase64);
      }

      if (_logoImageUrl != null && _logoImageUrl!.isNotEmpty) {
        await prefs.setString(_prefLogoUrl, _logoImageUrl!);
      } else {
        await prefs.remove(_prefLogoUrl);
      }
      if (_logoImageBytes != null && _logoImageBytes!.isNotEmpty) {
        await prefs.setString(_prefLogoBase64, base64Encode(_logoImageBytes!));
      } else {
        await prefs.remove(_prefLogoBase64);
      }

      if (_loginWallpaperUrl != null && _loginWallpaperUrl!.isNotEmpty) {
        await prefs.setString(_prefWallpaperUrl, _loginWallpaperUrl!);
      } else {
        await prefs.remove(_prefWallpaperUrl);
      }
      if (_loginWallpaperBytes != null && _loginWallpaperBytes!.isNotEmpty) {
        await prefs.setString(_prefWallpaperBase64, base64Encode(_loginWallpaperBytes!));
      } else {
        await prefs.remove(_prefWallpaperBase64);
      }

      await prefs.setInt(_prefNavbarStyle, _navbarStyle);
      await prefs.setString(_prefFontFamily, _fontFamily);
    } catch (e) {
      debugPrint('Gagal menyimpan ke SharedPreferences: $e');
    }
  }

  /// Menyimpan pengaturan toko ke SharedPreferences lokal DAN Supabase (Storage + Database)
  Future<void> saveSettingsToCloud() async {
    // 1. Simpan segera ke SharedPreferences lokal
    await _saveToLocalPrefs();

    // 2. Siapkan data JSON untuk Cloud
    final effectiveBanner = (_bannerImageUrl != null && _bannerImageUrl!.isNotEmpty)
        ? _bannerImageUrl
        : (_bannerImageBytes != null ? 'data:image/png;base64,${base64Encode(_bannerImageBytes!)}' : null);

    final effectiveLogo = (_logoImageUrl != null && _logoImageUrl!.isNotEmpty)
        ? _logoImageUrl
        : (_logoImageBytes != null ? 'data:image/png;base64,${base64Encode(_logoImageBytes!)}' : null);

    final effectiveWallpaper = (_loginWallpaperUrl != null && _loginWallpaperUrl!.isNotEmpty)
        ? _loginWallpaperUrl
        : (_loginWallpaperBytes != null ? 'data:image/png;base64,${base64Encode(_loginWallpaperBytes!)}' : null);

    final jsonMap = <String, dynamic>{
      'adminWhatsApp': _adminWhatsApp,
      'adminEmail': _adminEmail,
      'adminUsername': _adminUsername,
      'adminPassword': _adminPassword,
      'bannerImageUrl': effectiveBanner,
      'logoImageUrl': effectiveLogo,
      'loginWallpaperUrl': effectiveWallpaper,
      'navbarStyle': _navbarStyle,
      'fontFamily': _fontFamily,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // Pertahankan data cages agar tidak tertimpa saat simpan pengaturan toko
    try {
      final downloadedBytes = await supabase.storage.from('katalog').download('app_settings.json');
      final existingMap = jsonDecode(utf8.decode(downloadedBytes)) as Map<String, dynamic>;
      if (existingMap['cages'] != null && existingMap['cages'] is List && (existingMap['cages'] as List).isNotEmpty) {
        jsonMap['cages'] = existingMap['cages'];
      } else if (CageService.instance.cages.isNotEmpty) {
        jsonMap['cages'] = CageService.instance.cages.map((c) => c.toMap()).toList();
      }
    } catch (_) {
      if (CageService.instance.cages.isNotEmpty) {
        jsonMap['cages'] = CageService.instance.cages.map((c) => c.toMap()).toList();
      }
    }

    // 3. Simpan ke Supabase Storage (app_settings.json)
    try {
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(jsonMap)));
      final buckets = ['katalog', 'images', 'uploads', 'public'];
      for (final bucket in buckets) {
        try {
          await supabase.storage.from(bucket).uploadBinary(
                'app_settings.json',
                jsonBytes,
                fileOptions: const FileOptions(
                  contentType: 'application/json',
                  upsert: true,
                ),
              );
          debugPrint('SettingsService: Berhasil simpan app_settings.json ke Storage $bucket');
          break;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('SettingsService Storage save error: $e');
    }

    // 4. Simpan ke Supabase Database (tabel public.app_settings)
    try {
      await supabase.from('app_settings').upsert({
        'id': 'global_settings',
        'settings_json': jsonMap,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('SettingsService: Berhasil simpan ke tabel public.app_settings');
    } catch (e) {
      debugPrint('SettingsService Database table save notice (dapat diaktifkan lewat SQL): $e');
    }
  }

  /// Reset ke pengaturan default
  void resetToDefault() async {
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

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefWa);
      await prefs.remove(_prefEmail);
      await prefs.remove(_prefUsername);
      await prefs.remove(_prefPassword);
      await prefs.remove(_prefBannerUrl);
      await prefs.remove(_prefBannerBase64);
      await prefs.remove(_prefLogoUrl);
      await prefs.remove(_prefLogoBase64);
      await prefs.remove(_prefWallpaperUrl);
      await prefs.remove(_prefWallpaperBase64);
      await prefs.remove(_prefNavbarStyle);
      await prefs.remove(_prefFontFamily);
    } catch (_) {}

    saveSettingsToCloud();
  }
}
