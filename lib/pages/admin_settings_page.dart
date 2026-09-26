import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../services/ai_assistant_service.dart';
import 'admin_order_detail_page.dart';

/// Halaman Pengaturan untuk Admin
/// - Breadcrumb: Kembali / Pengaturan
/// - Judul: Preview Dashboard Umum
/// - Pilihan Banner (Upload Foto / URL)
/// - Pilihan Wallpaper Halaman Login (Upload Foto dari Komputer/HP / URL / Contoh)
/// - Akun Administrator Resmi (Email, Username, Password)
/// - Pilihan Navbar (1, 2, 3)
/// - Pilihan Font (Times New Roman, dll.)
/// - Pengaturan Nomor WhatsApp Tujuan Pesanan
class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  late TextEditingController _waController;
  late TextEditingController _bannerUrlController;
  late int _selectedNavbarStyle;
  late String _selectedFont;
  Uint8List? _bannerImageBytes;
  String? _bannerImageUrl;
  String? _bannerFileName;

  // Kredensial Akun Administrator
  late TextEditingController _adminEmailController;
  late TextEditingController _adminUsernameController;
  late TextEditingController _adminPasswordController;
  bool _obscureAdminPassword = true;

  // Wallpaper Halaman Login
  late TextEditingController _loginWallpaperUrlController;
  Uint8List? _loginWallpaperBytes;
  String? _loginWallpaperUrl;
  String? _loginWallpaperFileName;

  // Logo Brand / Katalog (Jatimas Sangkar)
  late TextEditingController _logoUrlController;
  Uint8List? _logoImageBytes;
  String? _logoImageUrl;
  String? _logoFileName;

  // Status Aktif/Nonaktif AI Asisten di Beranda
  late bool _aiEnabled;

  // Status proses upload ke Supabase Storage & penyimpanan
  bool _isUploadingBanner = false;
  bool _isUploadingLogo = false;
  bool _isUploadingWallpaper = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = AppSettingsService.instance;
    _waController = TextEditingController(text: settings.adminWhatsApp);
    _bannerUrlController = TextEditingController(text: settings.bannerImageUrl ?? '');
    _selectedNavbarStyle = settings.navbarStyle;
    _selectedFont = settings.fontFamily;
    _bannerImageBytes = settings.bannerImageBytes;
    _bannerImageUrl = settings.bannerImageUrl;

    _adminEmailController = TextEditingController(text: settings.adminEmail);
    _adminUsernameController = TextEditingController(text: settings.adminUsername);
    _adminPasswordController = TextEditingController(text: settings.adminPassword);

    _loginWallpaperUrlController = TextEditingController(text: settings.loginWallpaperUrl ?? '');
    _loginWallpaperBytes = settings.loginWallpaperBytes;
    _loginWallpaperUrl = settings.loginWallpaperUrl;

    _logoUrlController = TextEditingController(text: settings.logoImageUrl ?? '');
    _logoImageBytes = settings.logoImageBytes;
    _logoImageUrl = settings.logoImageUrl;

    _aiEnabled = settings.aiAssistantEnabled;
  }

  @override
  void dispose() {
    _waController.dispose();
    _bannerUrlController.dispose();
    _adminEmailController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _loginWallpaperUrlController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  /// Memilih file banner dari perangkat lokal (Galeri / File Komputer)
  Future<void> _pickBannerFromFile() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        final base64String = 'data:image/$ext;base64,${base64Encode(bytes)}';

        setState(() {
          _bannerImageBytes = bytes;
          _bannerFileName = picked.name;
          _bannerImageUrl = base64String;
          _bannerUrlController.text = base64String;
          _isUploadingBanner = true;
        });

        // Unggah otomatis ke Supabase Storage bucket 'katalog' agar permanen di cloud
        final publicUrl = await StorageService.instance.uploadBytes(
          bytes: bytes,
          prefix: 'banner',
          originalFilename: picked.name,
        );

        if (mounted) {
          setState(() {
            _isUploadingBanner = false;
            if (publicUrl != null) {
              _bannerImageUrl = publicUrl;
              _bannerUrlController.text = publicUrl;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(publicUrl != null
                  ? 'Banner berhasil diunggah ke Cloud Storage! Klik "Simpan Pengaturan" untuk menerapkan.'
                  : 'Banner berhasil dimuat. Klik "Simpan Pengaturan" di bawah untuk menyimpan permanen.'),
              backgroundColor: const Color(0xFF7A4B29),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingBanner = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload dari file mengalami kendala: $e.\nAnda dapat menempelkan URL atau memilih contoh banner di bawah.'),
            backgroundColor: const Color(0xFF7A4B29),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Memilih file logo dari perangkat lokal (Galeri / Berkas Komputer)
  Future<void> _pickLogoFromFile() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        final base64String = 'data:image/$ext;base64,${base64Encode(bytes)}';

        setState(() {
          _logoImageBytes = bytes;
          _logoFileName = picked.name;
          _logoImageUrl = base64String;
          _logoUrlController.text = base64String;
          _isUploadingLogo = true;
        });

        // Unggah otomatis ke Supabase Storage bucket 'katalog' agar permanen di cloud
        final publicUrl = await StorageService.instance.uploadBytes(
          bytes: bytes,
          prefix: 'logo',
          originalFilename: picked.name,
        );

        if (mounted) {
          setState(() {
            _isUploadingLogo = false;
            if (publicUrl != null) {
              _logoImageUrl = publicUrl;
              _logoUrlController.text = publicUrl;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(publicUrl != null
                  ? 'Logo berhasil diunggah ke Cloud Storage! Klik "Simpan Pengaturan" untuk menerapkan.'
                  : 'Logo berhasil dimuat. Klik "Simpan Pengaturan" di bawah untuk menyimpan permanen.'),
              backgroundColor: const Color(0xFF7A4B29),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload logo mengalami kendala: $e'),
            backgroundColor: const Color(0xFF7A4B29),
          ),
        );
      }
    }
  }

  /// Memilih file wallpaper login dari perangkat lokal (Galeri / Berkas Komputer)
  Future<void> _pickLoginWallpaperFromFile() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        final base64String = 'data:image/$ext;base64,${base64Encode(bytes)}';

        setState(() {
          _loginWallpaperBytes = bytes;
          _loginWallpaperFileName = picked.name;
          _loginWallpaperUrl = base64String;
          _loginWallpaperUrlController.text = base64String;
          _isUploadingWallpaper = true;
        });

        // Unggah otomatis ke Supabase Storage bucket 'katalog' agar permanen di cloud
        final publicUrl = await StorageService.instance.uploadBytes(
          bytes: bytes,
          prefix: 'wallpaper',
          originalFilename: picked.name,
        );

        if (mounted) {
          setState(() {
            _isUploadingWallpaper = false;
            if (publicUrl != null) {
              _loginWallpaperUrl = publicUrl;
              _loginWallpaperUrlController.text = publicUrl;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(publicUrl != null
                  ? 'Wallpaper berhasil diunggah ke Cloud Storage! Klik "Simpan Pengaturan" untuk menerapkan.'
                  : 'Wallpaper berhasil dimuat. Klik "Simpan Pengaturan" di bawah untuk menyimpan permanen.'),
              backgroundColor: const Color(0xFF7A4B29),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingWallpaper = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload wallpaper mengalami kendala: $e.\nAnda dapat menempelkan URL atau memilih contoh wallpaper.'),
            backgroundColor: const Color(0xFF7A4B29),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Dialog pemilihan sumber wallpaper login (Upload File, Tempel URL, Contoh Wallpaper, Reset)
  void _showLoginWallpaperSourceDialog() {
    final tempUrlCtrl = TextEditingController(text: _loginWallpaperUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.wallpaper_rounded, color: Color(0xFF7A4B29)),
            SizedBox(width: 8),
            Text('Sumber Wallpaper Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih foto latar belakang untuk halaman login aplikasi:',
                style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 16),

              // 1. Opsi Upload File dari Komputer / HP
              InkWell(
                key: const ValueKey('dialog_pick_login_wallpaper_btn'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickLoginWallpaperFromFile();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF6F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF7A4B29).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_upload_rounded, color: Color(0xFF7A4B29), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Upload File dari Perangkat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Pilih foto dari galeri atau berkas komputer Anda', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Opsi Input URL Gambar
              const Text('Atau Tempel Link / URL Gambar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('dialog_login_wallpaper_url_input'),
                      controller: tempUrlCtrl,
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        prefixIcon: const Icon(Icons.link, size: 18, color: Color(0xFF7A4B29)),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final url = tempUrlCtrl.text.trim();
                      if (url.isNotEmpty) {
                        setState(() {
                          _loginWallpaperUrl = url;
                          _loginWallpaperBytes = null;
                          _loginWallpaperFileName = null;
                          _loginWallpaperUrlController.text = url;
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A4B29),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: const Text('Pakai'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 3. Opsi Pilihan Wallpaper Siap Pakai
              const Text('Atau Pilih Contoh Wallpaper Siap Pakai:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppSettingsService.sampleLoginWallpapers.map((wallpaperUrl) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _loginWallpaperUrl = wallpaperUrl;
                            _loginWallpaperBytes = null;
                            _loginWallpaperFileName = null;
                            _loginWallpaperUrlController.text = wallpaperUrl;
                          });
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 85,
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _loginWallpaperUrl == wallpaperUrl && _loginWallpaperBytes == null
                                  ? const Color(0xFF7A4B29)
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(wallpaperUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // 4. Opsi Kembalikan ke Wallpaper Default Bawaan
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _loginWallpaperBytes = null;
                      _loginWallpaperUrl = null;
                      _loginWallpaperFileName = null;
                      _loginWallpaperUrlController.clear();
                    });
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF7A4B29)),
                  label: const Text('Kembalikan ke Wallpaper Asli / Bawaan', style: TextStyle(fontSize: 12, color: Color(0xFF7A4B29))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  /// Dialog pemilihan sumber banner (Upload File, Tempel URL, atau Pilih Contoh)
  void _showBannerSourceDialog() {
    final tempUrlCtrl = TextEditingController(text: _bannerImageUrl ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.image_outlined, color: Color(0xFF7A4B29)),
            SizedBox(width: 8),
            Text('Pilih Sumber Banner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih metode penggantian banner dashboard umum:',
                style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 16),

              // 1. Opsi Upload File dari Komputer / HP
              InkWell(
                key: const ValueKey('dialog_pick_file_btn'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickBannerFromFile();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF6F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF7A4B29).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_upload_rounded, color: Color(0xFF7A4B29), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Upload File dari Perangkat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Pilih foto dari galeri atau berkas komputer', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Opsi Input URL Gambar
              const Text('Atau Tempel Link / URL Gambar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('dialog_banner_url_input'),
                      controller: tempUrlCtrl,
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        prefixIcon: const Icon(Icons.link, size: 18, color: Color(0xFF7A4B29)),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final url = tempUrlCtrl.text.trim();
                      if (url.isNotEmpty) {
                        setState(() {
                          _bannerImageUrl = url;
                          _bannerImageBytes = null;
                          _bannerFileName = null;
                          _bannerUrlController.text = url;
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A4B29),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    child: const Text('Pakai'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 3. Opsi Pilihan Banner Siap Pakai
              const Text('Atau Pilih Contoh Banner Jepara Siap Pakai:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppSettingsService.sampleBanners.map((bannerUrl) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _bannerImageUrl = bannerUrl;
                            _bannerImageBytes = null;
                            _bannerFileName = null;
                            _bannerUrlController.text = bannerUrl;
                          });
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 85,
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _bannerImageUrl == bannerUrl && _bannerImageBytes == null
                                  ? const Color(0xFF7A4B29)
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(bannerUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final wa = _waController.text.trim();
    if (wa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor WhatsApp tujuan tidak boleh kosong.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final adminEmail = _adminEmailController.text.trim();
    final adminUsername = _adminUsernameController.text.trim();
    final adminPass = _adminPasswordController.text.trim();

    if (adminEmail.isEmpty || adminPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email dan Kata Sandi Administrator tidak boleh kosong.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Pastikan banner bytes terunggah ke Supabase jika URL publik belum didapat
      if (_bannerImageBytes != null && (_bannerImageUrl == null || _bannerImageUrl!.isEmpty || _bannerImageUrl!.startsWith('data:image'))) {
        final uploaded = await StorageService.instance.uploadBytes(
          bytes: _bannerImageBytes!,
          prefix: 'banner',
          originalFilename: _bannerFileName,
        );
        if (uploaded != null) {
          _bannerImageUrl = uploaded;
        } else if (_bannerImageUrl == null || _bannerImageUrl!.isEmpty) {
          _bannerImageUrl = 'data:image/png;base64,${base64Encode(_bannerImageBytes!)}';
        }
      }

      // 2. Pastikan logo bytes terunggah ke Supabase jika URL publik belum didapat
      if (_logoImageBytes != null && (_logoImageUrl == null || _logoImageUrl!.isEmpty || _logoImageUrl!.startsWith('data:image'))) {
        final uploaded = await StorageService.instance.uploadBytes(
          bytes: _logoImageBytes!,
          prefix: 'logo',
          originalFilename: _logoFileName,
        );
        if (uploaded != null) {
          _logoImageUrl = uploaded;
        } else if (_logoImageUrl == null || _logoImageUrl!.isEmpty) {
          _logoImageUrl = 'data:image/png;base64,${base64Encode(_logoImageBytes!)}';
        }
      }

      // 3. Pastikan wallpaper bytes terunggah ke Supabase jika URL publik belum didapat
      if (_loginWallpaperBytes != null && (_loginWallpaperUrl == null || _loginWallpaperUrl!.isEmpty || _loginWallpaperUrl!.startsWith('data:image'))) {
        final uploaded = await StorageService.instance.uploadBytes(
          bytes: _loginWallpaperBytes!,
          prefix: 'wallpaper',
          originalFilename: _loginWallpaperFileName,
        );
        if (uploaded != null) {
          _loginWallpaperUrl = uploaded;
        } else if (_loginWallpaperUrl == null || _loginWallpaperUrl!.isEmpty) {
          _loginWallpaperUrl = 'data:image/png;base64,${base64Encode(_loginWallpaperBytes!)}';
        }
      }

      final urlInput = _bannerUrlController.text.trim();
      final effectiveImageUrl = (_bannerImageUrl != null && _bannerImageUrl!.isNotEmpty)
          ? _bannerImageUrl
          : (urlInput.isNotEmpty ? urlInput : null);

      final wallpaperUrlInput = _loginWallpaperUrlController.text.trim();
      final effectiveWallpaperUrl = (_loginWallpaperUrl != null && _loginWallpaperUrl!.isNotEmpty)
          ? _loginWallpaperUrl
          : (wallpaperUrlInput.isNotEmpty ? wallpaperUrlInput : null);

      final clearLoginWallpaper = _loginWallpaperBytes == null &&
          (effectiveWallpaperUrl == null || effectiveWallpaperUrl.isEmpty);

      final logoUrlInput = _logoUrlController.text.trim();
      final effectiveLogoUrl = (_logoImageUrl != null && _logoImageUrl!.isNotEmpty)
          ? _logoImageUrl
          : (logoUrlInput.isNotEmpty ? logoUrlInput : null);

      final clearLogo = _logoImageBytes == null &&
          (effectiveLogoUrl == null || effectiveLogoUrl.isEmpty);

      final clearBanner = _bannerImageBytes == null &&
          (effectiveImageUrl == null || effectiveImageUrl.isEmpty);

      AppSettingsService.instance.updateSettings(
        adminWhatsApp: wa,
        adminEmail: adminEmail,
        adminUsername: adminUsername,
        adminPassword: adminPass,
        bannerImageBytes: _bannerImageBytes,
        bannerImageUrl: effectiveImageUrl,
        logoImageBytes: _logoImageBytes,
        logoImageUrl: effectiveLogoUrl,
        clearLogo: clearLogo,
        navbarStyle: _selectedNavbarStyle,
        fontFamily: _selectedFont,
        clearBanner: clearBanner,
        loginWallpaperBytes: _loginWallpaperBytes,
        loginWallpaperUrl: effectiveWallpaperUrl,
        clearLoginWallpaper: clearLoginWallpaper,
        aiAssistantEnabled: _aiEnabled,
      );

      await AppSettingsService.instance.saveSettingsToCloud();
      AiAssistantService.instance.setEnabled(_aiEnabled);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pengaturan berhasil disimpan permanen! Banner, Logo, & Akun tersimpan aman di Cloud.',
          ),
          backgroundColor: Color(0xFF7A4B29),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kendala saat menyimpan ke Cloud: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5A3E28),
                Color(0xFF382314),
                Color(0xFF24150B),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 36),
                  const SizedBox(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.account_circle,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width < 500 ? 16.0 : 40.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Breadcrumb: Kembali / Pengaturan
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'Kembali',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    '  /  ',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const Text(
                    'Pengaturan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // 2. Heading: Preview Dashboard Umum
              const Text(
                'Preview Dashboard Umum',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),

              const SizedBox(height: 20),

              // 3. Section Banner & Logo Brand/Katalog
              // Responsif: Bersebelahan pada layar lebar (Desktop/Tablet) agar tidak kosong,
              // dan bertumpuk vertikal pada layar mobile.
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildBannerSettingsSection(),
                        ),
                        const SizedBox(width: 40),
                        Expanded(
                          flex: 5,
                          child: _buildLogoSettingsSection(),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBannerSettingsSection(),
                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFE0E0E0)),
                        const SizedBox(height: 20),
                        _buildLogoSettingsSection(),
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

              const Divider(color: Color(0xFFE0E0E0), thickness: 1),

              const SizedBox(height: 20),

              // ==================== 6. Section Wallpaper Halaman Login ====================
              Row(
                children: const [
                  Icon(Icons.wallpaper_rounded, color: Color(0xFF7A4B29), size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wallpaper Halaman Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Kustomisasi foto latar belakang di halaman login aplikasi. Anda dapat mengunggah file foto langsung dari galeri HP atau berkas komputer, menempelkan link gambar, atau memilih wallpaper siap pakai:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF777777),
                ),
              ),
              const SizedBox(height: 14),

              // Kotak Preview Wallpaper Login
              InkWell(
                key: const ValueKey('settings_login_wallpaper_picker'),
                onTap: _showLoginWallpaperSourceDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 300,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF232B1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF7A4B29).withValues(alpha: 0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_loginWallpaperBytes != null && _loginWallpaperBytes!.isNotEmpty)
                        Positioned.fill(
                          child: Image.memory(
                            _loginWallpaperBytes!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/login_bg.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else if (_loginWallpaperUrl != null && _loginWallpaperUrl!.isNotEmpty)
                        Positioned.fill(
                          child: Product.buildImageFromSource(
                            _loginWallpaperUrl!,
                            fit: BoxFit.cover,
                            placeholder: Image.asset(
                              'assets/images/login_bg.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/login_bg.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),

                      // Overlay badge status
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _loginWallpaperBytes != null
                                    ? Icons.cloud_done_rounded
                                    : (_loginWallpaperUrl != null && _loginWallpaperUrl!.isNotEmpty
                                        ? Icons.link_rounded
                                        : Icons.image_rounded),
                                color: const Color(0xFFFFD900),
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _loginWallpaperBytes != null
                                    ? 'Upload dari File'
                                    : (_loginWallpaperUrl != null && _loginWallpaperUrl!.isNotEmpty
                                        ? 'Dari URL / Web'
                                        : 'Wallpaper Bawaan'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tombol Hapus / Reset jika wallpaper kustom aktif
                      if (_loginWallpaperBytes != null || (_loginWallpaperUrl != null && _loginWallpaperUrl!.isNotEmpty))
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _loginWallpaperBytes = null;
                                _loginWallpaperUrl = null;
                                _loginWallpaperFileName = null;
                                _loginWallpaperUrlController.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Opsi Tombol Aksi Wallpaper
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('settings_upload_login_wallpaper_btn'),
                    onPressed: _isUploadingWallpaper ? null : _pickLoginWallpaperFromFile,
                    icon: _isUploadingWallpaper
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7A4B29)),
                          )
                        : const Icon(Icons.file_upload_outlined, size: 16),
                    label: Text(
                      _isUploadingWallpaper ? 'Mengunggah...' : 'Upload File dari Perangkat',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A301E),
                      side: const BorderSide(color: Color(0xFF7A4B29)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showLoginWallpaperSourceDialog,
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Pilih Contoh', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4A301E),
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  if (_loginWallpaperBytes != null || (_loginWallpaperUrl != null && _loginWallpaperUrl!.isNotEmpty))
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _loginWallpaperBytes = null;
                          _loginWallpaperUrl = null;
                          _loginWallpaperFileName = null;
                          _loginWallpaperUrlController.clear();
                        });
                      },
                      icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF7A4B29)),
                      label: const Text('Kembalikan ke Asli', style: TextStyle(fontSize: 12, color: Color(0xFF7A4B29))),
                    ),
                ],
              ),

              if (_loginWallpaperFileName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _loginWallpaperUrl != null
                        ? '✓ File aktif: $_loginWallpaperFileName (Tersimpan di Cloud)'
                        : '✓ File aktif: $_loginWallpaperFileName',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: 10),

              // Input URL Wallpaper Langsung
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  key: const ValueKey('settings_login_wallpaper_url_field'),
                  controller: _loginWallpaperUrlController,
                  onChanged: (val) {
                    setState(() {
                      final clean = val.trim();
                      if (clean.isNotEmpty) {
                        _loginWallpaperUrl = clean;
                        _loginWallpaperBytes = null;
                        _loginWallpaperFileName = null;
                      } else {
                        _loginWallpaperUrl = null;
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Atau tempel Link / URL Wallpaper di sini...',
                    prefixIcon: const Icon(Icons.link, size: 18, color: Color(0xFF7A4B29)),
                    suffixIcon: _loginWallpaperUrl != null && _loginWallpaperUrl!.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              setState(() {
                                _loginWallpaperUrl = null;
                                _loginWallpaperUrlController.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Pilihan Cepat Contoh Wallpaper Login
              const Text(
                'Contoh Wallpaper Siap Pakai:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppSettingsService.sampleLoginWallpapers.map((wallpaperUrl) {
                    final isSelected = _loginWallpaperUrl == wallpaperUrl && _loginWallpaperBytes == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _loginWallpaperUrl = wallpaperUrl;
                            _loginWallpaperBytes = null;
                            _loginWallpaperFileName = null;
                            _loginWallpaperUrlController.text = wallpaperUrl;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 80,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF7A4B29) : Colors.grey.shade300,
                              width: isSelected ? 2.5 : 1,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(wallpaperUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              const Divider(color: Color(0xFFE0E0E0), thickness: 1),

              const SizedBox(height: 20),

              // ==================== 7. Section Akun Administrator Resmi ====================
              Row(
                children: const [
                  Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7A4B29), size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Akun Administrator Resmi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Akun demo telah dihapus. Kelola email, username, dan kata sandi login Admin di bawah ini. Anda dapat masuk langsung melalui halaman login utama:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF777777),
                ),
              ),
              const SizedBox(height: 14),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field Email Admin
                    const Text(
                      'Email Administrator',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF444444)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const ValueKey('admin_email_input'),
                      controller: _adminEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF7A4B29), size: 20),
                        hintText: 'admin@jatimas.com',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Field Username Admin
                    const Text(
                      'Username Administrator (Alternatif Login)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF444444)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const ValueKey('admin_username_input'),
                      controller: _adminUsernameController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF7A4B29), size: 20),
                        hintText: 'admin',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Field Password Admin
                    const Text(
                      'Kata Sandi (Password) Administrator',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF444444)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const ValueKey('admin_password_input'),
                      controller: _adminPasswordController,
                      obscureText: _obscureAdminPassword,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF7A4B29), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureAdminPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: Colors.grey.shade600,
                          ),
                          onPressed: () => setState(() => _obscureAdminPassword = !_obscureAdminPassword),
                        ),
                        hintText: 'admin123',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Divider(color: Color(0xFFE0E0E0), thickness: 1),

              const SizedBox(height: 20),

              // ==================== 8. Section Nomor WhatsApp Tujuan Pemesanan ====================
              Row(
                children: const [
                  Icon(Icons.phone_android_rounded, color: Color(0xFF25D366), size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nomor WhatsApp Tujuan Pesanan (Admin)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Semua pesanan dari user manapun (baik umum maupun private) akan otomatis diarahkan ke nomor WhatsApp yang Anda atur di bawah ini:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF777777),
                ),
              ),
              const SizedBox(height: 12),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBDBDBD)),
                  ),
                  child: TextField(
                    key: const ValueKey('admin_whatsapp_input'),
                    controller: _waController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: WhatsAppIcon(size: 20, color: Color(0xFF25D366)),
                      ),
                      hintText: 'Contoh: 085732257048',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ==================== Section AI Asisten ====================
              _buildAiAssistantSettingsSection(),

              const SizedBox(height: 28),

              // 7. Tombol Simpan Pengaturan
              ElevatedButton.icon(
                key: const ValueKey('save_settings_btn'),
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  _isSaving ? 'Menyimpan ke Cloud...' : 'Simpan Pengaturan',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A4B29),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  /// Membangun Bagian Pengaturan Banner Dashboard Umum
  Widget _buildBannerSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Banner Dashboard Umum',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF555555),
          ),
        ),
        const SizedBox(height: 8),

        // Kotak Abu-Abu Upload Banner (Sesuai Gambar 1 & 2)
        InkWell(
          key: const ValueKey('settings_banner_picker'),
          onTap: _showBannerSourceDialog,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 260,
            height: 170,
            decoration: BoxDecoration(
              color: const Color(0xFF6E7173),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_bannerImageBytes != null && _bannerImageBytes!.isNotEmpty)
                  Positioned.fill(
                    child: Image.memory(
                      _bannerImageBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 54,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else if (_bannerImageUrl != null && _bannerImageUrl!.isNotEmpty)
                  Positioned.fill(
                    child: Product.buildImageFromSource(
                      _bannerImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: const Center(
                        child: Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 54,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 54,
                      color: Colors.white,
                    ),
                  ),

                // Tombol overlay untuk ganti / hapus jika ada gambar terpasang
                if (_bannerImageBytes != null || (_bannerImageUrl != null && _bannerImageUrl!.isNotEmpty))
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _bannerImageBytes = null;
                          _bannerImageUrl = null;
                          _bannerFileName = null;
                          _bannerUrlController.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Opsi tombol aksi cepat Banner (Upload File, URL, Preset, Hapus)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('settings_upload_file_btn'),
              onPressed: _isUploadingBanner ? null : _pickBannerFromFile,
              icon: _isUploadingBanner
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7A4B29)),
                    )
                  : const Icon(Icons.file_upload_outlined, size: 16),
              label: Text(
                _isUploadingBanner ? 'Mengunggah...' : 'Upload File',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A301E),
                side: const BorderSide(color: Color(0xFF7A4B29)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _showBannerSourceDialog,
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: const Text('Pilih Contoh', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A301E),
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            if (_bannerImageBytes != null || (_bannerImageUrl != null && _bannerImageUrl!.isNotEmpty))
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _bannerImageBytes = null;
                    _bannerImageUrl = null;
                    _bannerFileName = null;
                    _bannerUrlController.clear();
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                label: const Text('Hapus Banner', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
              ),
          ],
        ),

        if (_bannerFileName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              _bannerImageUrl != null
                  ? '✓ File aktif: $_bannerFileName (Tersimpan di Cloud)'
                  : '✓ File aktif: $_bannerFileName',
              style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
            ),
          ),

        const SizedBox(height: 10),

        // Input URL Banner langsung
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TextField(
            key: const ValueKey('settings_banner_url_field'),
            controller: _bannerUrlController,
            onChanged: (val) {
              setState(() {
                final clean = val.trim();
                if (clean.isNotEmpty) {
                  _bannerImageUrl = clean;
                  _bannerImageBytes = null;
                  _bannerFileName = null;
                } else {
                  _bannerImageUrl = null;
                }
              });
            },
            decoration: InputDecoration(
              hintText: 'Atau tempel Link / URL Banner di sini...',
              prefixIcon: const Icon(Icons.link, size: 18, color: Color(0xFF7A4B29)),
              suffixIcon: _bannerImageUrl != null && _bannerImageUrl!.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          _bannerImageUrl = null;
                          _bannerUrlController.clear();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Pilihan Cepat Preset Banner
        const Text(
          'Contoh Banner Jepara Pilihan:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF666666)),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AppSettingsService.sampleBanners.map((bannerUrl) {
              final isSelected = _bannerImageUrl == bannerUrl && _bannerImageBytes == null;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _bannerImageUrl = bannerUrl;
                      _bannerImageBytes = null;
                      _bannerFileName = null;
                      _bannerUrlController.text = bannerUrl;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF7A4B29) : Colors.grey.shade300,
                        width: isSelected ? 2.5 : 1,
                      ),
                      image: DecorationImage(
                        image: NetworkImage(bannerUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Membangun Bagian Pengaturan Logo Brand / Katalog (Ditempatkan di sebelah kanan banner)
  Widget _buildLogoSettingsSection() {
    final hasCustom = (_logoImageBytes != null && _logoImageBytes!.isNotEmpty) ||
        (_logoImageUrl != null && _logoImageUrl!.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Text(
              'Logo Brand / Katalog',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Katalog & Dashboard',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8C6B1C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Kotak Preview Logo (Lebar 260, tinggi 170 serasi dengan kotak Banner)
        InkWell(
          onTap: _pickLogoFromFile,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 280,
            height: 190,
            decoration: BoxDecoration(
              color: const Color(0xFF2C1810),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Emblem Logo Bundar
                Center(
                  child: Container(
                    width: 145,
                    height: 145,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _logoImageBytes != null && _logoImageBytes!.isNotEmpty
                          ? Image.memory(
                              _logoImageBytes!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              cacheWidth: 375,
                              cacheHeight: 375,
                            )
                          : (_logoImageUrl != null && _logoImageUrl!.isNotEmpty
                              ? Product.buildImageFromSource(
                                  _logoImageUrl!,
                                  fit: BoxFit.contain,
                                  placeholder: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                    cacheWidth: 375,
                                    cacheHeight: 375,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  cacheWidth: 375,
                                  cacheHeight: 375,
                                )),
                    ),
                  ),
                ),

                // Badge status kustom / bawaan
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasCustom ? 'Logo Kustom' : 'Logo Bawaan',
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Tombol Hapus / Reset Logo Kustom jika ada
                if (hasCustom)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _logoImageBytes = null;
                          _logoImageUrl = null;
                          _logoFileName = null;
                          _logoUrlController.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Tombol Aksi Upload Logo
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _isUploadingLogo ? null : _pickLogoFromFile,
              icon: _isUploadingLogo
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7A4B29)),
                    )
                  : const Icon(Icons.file_upload_outlined, size: 16),
              label: Text(
                _isUploadingLogo ? 'Mengunggah...' : 'Upload Logo',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4A301E),
                side: const BorderSide(color: Color(0xFF7A4B29)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            if (hasCustom)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _logoImageBytes = null;
                    _logoImageUrl = null;
                    _logoFileName = null;
                    _logoUrlController.clear();
                  });
                },
                icon: const Icon(Icons.restore_rounded, size: 16, color: Color(0xFF7A4B29)),
                label: const Text('Kembalikan ke Logo Asli', style: TextStyle(fontSize: 12, color: Color(0xFF7A4B29))),
              ),
          ],
        ),

        if (_logoFileName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              _logoImageUrl != null
                  ? '✓ File aktif: $_logoFileName (Tersimpan di Cloud)'
                  : '✓ File aktif: $_logoFileName',
              style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
            ),
          ),

        const SizedBox(height: 10),

        // Input URL Gambar Logo Langsung
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TextField(
            controller: _logoUrlController,
            onChanged: (val) {
              setState(() {
                final clean = val.trim();
                if (clean.isNotEmpty) {
                  _logoImageUrl = clean;
                  _logoImageBytes = null;
                  _logoFileName = null;
                } else {
                  _logoImageUrl = null;
                }
              });
            },
            decoration: InputDecoration(
              hintText: 'Atau tempel Link / URL Logo di sini...',
              prefixIcon: const Icon(Icons.link, size: 18, color: Color(0xFF7A4B29)),
              suffixIcon: _logoImageUrl != null && _logoImageUrl!.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          _logoImageUrl = null;
                          _logoUrlController.clear();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),

        const SizedBox(height: 6),
        const Text(
          'Logo ini otomatis tampil di navbar katalog pengguna dan pojok kiri atas dashboard admin.',
          style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
        ),
      ],
    );
  }

  /// Bagian Pengaturan AI Asisten (Hermes AI) - Cukup Saklar ON / OFF Sederhana
  Widget _buildAiAssistantSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF7A4B29), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'AI Asisten Pemesanan (Hermes AI)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Aktifkan atau nonaktifkan tombol asisten suara & teks di beranda katalog umum dan pribadi:',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF777777)),
        ),
        const SizedBox(height: 14),

        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _aiEnabled ? const Color(0xFFD4AF37) : const Color(0xFFE2D6C5),
                width: _aiEnabled ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Status AI Asisten di Beranda',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _aiEnabled ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _aiEnabled ? const Color(0xFF2E7D32) : Colors.grey,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _aiEnabled ? 'Aktif' : 'Nonaktif',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _aiEnabled ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiEnabled
                            ? 'Tombol "AI Asisten" tampil di pojok kanan bawah beranda untuk membantu pelanggan mencari dan memesan sangkar.'
                            : 'Tombol "AI Asisten" disembunyikan dari beranda.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF666666), height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _aiEnabled,
                  activeThumbColor: const Color(0xFF7A4B29),
                  activeTrackColor: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                  onChanged: (val) {
                    setState(() {
                      _aiEnabled = val;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
