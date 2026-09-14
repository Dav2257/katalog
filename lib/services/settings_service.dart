import 'package:flutter/foundation.dart';

/// Service untuk mengelola pengaturan toko/aplikasi oleh Admin,
/// mencakup nomor WhatsApp tujuan pesanan, pilihan banner katalog umum,
/// variasi style navbar, dan jenis font katalog umum.
class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._internal();

  AppSettingsService._internal();

  // Nomor WhatsApp tujuan pesanan (Default: 085732257048)
  String _adminWhatsApp = '085732257048';
  String get adminWhatsApp => _adminWhatsApp;

  // Banner kustom untuk Dashboard Umum
  Uint8List? _bannerImageBytes;
  Uint8List? get bannerImageBytes => _bannerImageBytes;

  String? _bannerImageUrl;
  String? get bannerImageUrl => _bannerImageUrl;

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
    String? note,
  }) {
    final dest = formattedWhatsAppDestination;
    final itemsText = itemDescriptions.map((item) => '• $item').join('\n\n');
    final noteText = (note != null && note.trim().isNotEmpty) ? '\nCatatan: $note' : '';
    final message =
        'Halo Admin Jatimas Sangkar, saya ingin memesan produk berikut:\n\n$itemsText$noteText\n\nNomor Kontak Saya: $customerPhone\nMohon informasi ketersediaan & prosesnya. Terima kasih!';

    return Uri.parse('https://wa.me/$dest?text=${Uri.encodeComponent(message)}');
  }

  /// Memperbarui pengaturan oleh Admin
  void updateSettings({
    String? adminWhatsApp,
    Uint8List? bannerImageBytes,
    String? bannerImageUrl,
    int? navbarStyle,
    String? fontFamily,
    bool clearBanner = false,
  }) {
    if (adminWhatsApp != null && adminWhatsApp.trim().isNotEmpty) {
      _adminWhatsApp = adminWhatsApp.trim();
    }
    if (clearBanner) {
      _bannerImageBytes = null;
      _bannerImageUrl = null;
    } else if (bannerImageBytes != null) {
      _bannerImageBytes = bannerImageBytes;
      _bannerImageUrl = null;
    } else if (bannerImageUrl != null) {
      _bannerImageUrl = bannerImageUrl.trim();
      _bannerImageBytes = null;
    }
    if (navbarStyle != null && navbarStyle >= 1 && navbarStyle <= 3) {
      _navbarStyle = navbarStyle;
    }
    if (fontFamily != null && fontFamily.trim().isNotEmpty) {
      _fontFamily = fontFamily.trim();
    }
    notifyListeners();
  }

  /// Reset ke pengaturan default
  void resetToDefault() {
    _adminWhatsApp = '085732257048';
    _bannerImageBytes = null;
    _bannerImageUrl = null;
    _navbarStyle = 1;
    _fontFamily = 'Times New Roman';
    notifyListeners();
  }
}
