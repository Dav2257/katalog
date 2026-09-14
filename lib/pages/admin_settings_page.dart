import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/settings_service.dart';
import 'admin_order_detail_page.dart';

/// Halaman Pengaturan untuk Admin
/// Sesuai Gambar Referensi 2:
/// - Breadcrumb: Kembali / Pengaturan
/// - Judul: Preview Dashboard Umum
/// - Pilihan Banner (Upload Foto / URL)
/// - Pilihan Navbar (1, 2, 3)
/// - Pilihan Font (Times New Roman, dll.)
/// - Kolom Pengaturan Nomor WhatsApp Tujuan Pesanan (Semua pesanan user umum & private ditujukan ke nomor ini)
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
  }

  @override
  void dispose() {
    _waController.dispose();
    _bannerUrlController.dispose();
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
        setState(() {
          _bannerImageBytes = bytes;
          _bannerFileName = picked.name;
          _bannerImageUrl = null;
          _bannerUrlController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload dari file mengalami kendala: $e.\nAnda dapat menempelkan URL atau memilih contoh banner di bawah.'),
          backgroundColor: const Color(0xFF7A4B29),
          duration: const Duration(seconds: 4),
        ),
      );
    }
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

  void _saveSettings() {
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

    final urlInput = _bannerUrlController.text.trim();
    final effectiveImageUrl = _bannerImageBytes != null
        ? null
        : (urlInput.isNotEmpty ? urlInput : _bannerImageUrl);

    AppSettingsService.instance.updateSettings(
      adminWhatsApp: wa,
      bannerImageBytes: _bannerImageBytes,
      bannerImageUrl: effectiveImageUrl,
      navbarStyle: _selectedNavbarStyle,
      fontFamily: _selectedFont,
      clearBanner: _bannerImageBytes == null && (effectiveImageUrl == null || effectiveImageUrl.isEmpty),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pengaturan berhasil disimpan! Pesanan WhatsApp kini ditujukan ke $wa dan layout katalog diperbarui.',
        ),
        backgroundColor: const Color(0xFF7A4B29),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Breadcrumb: Kembali / Pengaturan
              Row(
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

              // 3. Section Banner
              const Text(
                'Banner',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 8),

              // Kotak Abu-Abu Upload Banner (Sesuai Gambar 2)
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
                          child: Image.network(
                            _bannerImageUrl!,
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
                    onPressed: _pickBannerFromFile,
                    icon: const Icon(Icons.file_upload_outlined, size: 16),
                    label: const Text('Upload File', style: TextStyle(fontSize: 12)),
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
                    '✓ File aktif: $_bannerFileName',
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

              const SizedBox(height: 24),

              const Divider(color: Color(0xFFE0E0E0), thickness: 1),

              const SizedBox(height: 20),

              // 6. Section Nomor WhatsApp Tujuan Pemesanan (Khusus Permintaan Pengguna)
              Row(
                children: const [
                  Icon(Icons.phone_android_rounded, color: Color(0xFF25D366), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Nomor WhatsApp Tujuan Pesanan (Admin)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
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

              Container(
                width: 380,
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

              const SizedBox(height: 28),

              // 7. Tombol Simpan Pengaturan
              ElevatedButton.icon(
                key: const ValueKey('save_settings_btn'),
                onPressed: _saveSettings,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text(
                  'Simpan Pengaturan',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
}
