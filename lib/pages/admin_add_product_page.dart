import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/cage_service.dart';
import '../services/product_service.dart';

class AdminAddProductPage extends StatefulWidget {
  const AdminAddProductPage({super.key});

  @override
  State<AdminAddProductPage> createState() => _AdminAddProductPageState();
}

class _AdminAddProductPageState extends State<AdminAddProductPage> {
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _hashtagController;

  late final PageController _slideController;
  final ScrollController _cageScrollController = ScrollController();
  int _currentSlideIndex = 0;

  String _mainImageUrl = '';

  // Variasi bentuk sangkar disinkronkan dari CageService
  final List<ProductCageVariation> _cages = [];

  @override
  void initState() {
    super.initState();
    final nextNum = ProductService.instance.products.length + 1;
    final defaultCode = nextNum < 10 ? 'A0$nextNum' : 'A$nextNum';
    _codeController = TextEditingController(text: defaultCode);
    _nameController = TextEditingController();
    _hashtagController = TextEditingController(text: '#sangkar #jati #jepara');

    final serviceCages = CageService.instance.cages;
    if (serviceCages.isNotEmpty) {
      _cages.addAll(serviceCages.map((c) {
        final cleanImg = (c.imageUrl ?? '').contains('images.unsplash.com') ? '' : (c.imageUrl ?? '');
        return ProductCageVariation(
          id: c.id,
          name: c.name,
          imageUrl: cleanImg,
          imageBytes: c.imageBytes,
        );
      }));
    }

    _slideController = PageController();
    _precacheImages();
  }

  void _precacheImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mainImageUrl.isNotEmpty) {
        _precacheSource(_mainImageUrl);
      }
      for (final cage in _cages) {
        if (cage.imageBytes != null && cage.imageBytes!.isNotEmpty) {
          precacheImage(MemoryImage(cage.imageBytes!), context).catchError((_) {});
        } else if (cage.imageUrl.isNotEmpty) {
          _precacheSource(cage.imageUrl);
        }
      }
    });
  }

  void _precacheSource(String src) {
    try {
      final clean = src.trim();
      if (clean.isEmpty) return;
      if (clean.startsWith('data:image') || (clean.length > 200 && !clean.startsWith('http'))) {
        final commaIdx = clean.indexOf(',');
        final rawB64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        final bytes = base64Decode(rawB64);
        precacheImage(MemoryImage(bytes), context).catchError((_) {});
      } else {
        precacheImage(NetworkImage(clean), context).catchError((_) {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _hashtagController.dispose();
    _slideController.dispose();
    _cageScrollController.dispose();
    super.dispose();
  }

  void _scrollThumbnailToVisible(int slideIndex) {
    if (!_cageScrollController.hasClients) return;
    const itemWidth = 131.0;
    final targetOffset = (slideIndex * itemWidth) - 80.0;
    _cageScrollController.animateTo(
      targetOffset.clamp(0.0, _cageScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  bool _isLoading = false;

  Future<void> _createProduct() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    final hashtags = _hashtagController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama produk tidak boleh kosong!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final cleanCode = code.isNotEmpty ? code : 'A01';
    final cleanHashtags = hashtags.isNotEmpty ? hashtags : '#sangkar #jati #jepara';

    try {
      await ProductService.instance.addProduct(
        name: name,
        code: cleanCode,
        hashtags: cleanHashtags,
        imageUrl: _mainImageUrl.isNotEmpty ? _mainImageUrl : null,
        cageVariations: List.from(_cages),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produk "$name" berhasil disimpan ke database Supabase!'),
          backgroundColor: const Color(0xFF7A4B29),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan ke database Supabase:\n$e\n\n'
            'Tips: Pastikan skrip supabase_setup.sql sudah dijalankan di menu SQL Editor pada Dashboard Supabase Anda.',
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF382314),
                    child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService.instance.adminName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        AuthService.instance.adminEmail,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: Colors.black87),
                title: const Text('Preview Katalog Umum'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Keluar dari Akun Admin', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await AuthService.instance.logout();
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPhotoDialog({bool isCage = false, int? cageIndex}) {
    final initialUrl = isCage && cageIndex != null
        ? _cages[cageIndex].imageUrl
        : _mainImageUrl;
    final urlController = TextEditingController(text: initialUrl);
    Uint8List? uploadedImageBytes = isCage && cageIndex != null
        ? _cages[cageIndex].imageBytes
        : null;
    String? uploadedFileName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasImage = (uploadedImageBytes != null && uploadedImageBytes!.isNotEmpty) ||
              urlController.text.trim().isNotEmpty;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF7A4B29)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCage
                        ? 'Ubah Foto ${cageIndex != null ? _cages[cageIndex].name : "Sangkar"}'
                        : 'Ubah Foto Produk',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preview Foto Terpilih Saat Ini
                    Center(
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Container(
                            width: 180,
                            height: 130,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEEEEE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFDCDCDC)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (uploadedImageBytes != null && uploadedImageBytes!.isNotEmpty)
                                ? Image.memory(
                                    uploadedImageBytes!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Center(
                                      child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
                                    ),
                                  )
                                : urlController.text.trim().isNotEmpty
                                    ? Product.buildImageFromSource(
                                        urlController.text.trim(),
                                        fit: BoxFit.cover,
                                        placeholder: const Center(
                                          child: Icon(Icons.image_rounded, color: Colors.grey, size: 36),
                                        ),
                                      )
                                    : const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate_outlined, color: Colors.grey, size: 40),
                                            SizedBox(height: 6),
                                            Text(
                                              'Belum ada foto',
                                              style: TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                          ),
                          if (hasImage)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    uploadedImageBytes = null;
                                    uploadedFileName = null;
                                    urlController.clear();
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tombol Upload dari Galeri / Folder File
                    InkWell(
                      onTap: () async {
                        try {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1600,
                            maxHeight: 1600,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
                            final base64String = 'data:image/$ext;base64,${base64Encode(bytes)}';
                            setDialogState(() {
                              uploadedImageBytes = bytes;
                              uploadedFileName = picked.name;
                              urlController.text = base64String;
                            });
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Upload dari file terkendala: $e.\nAnda dapat menempelkan URL atau memilih contoh foto.'),
                                backgroundColor: const Color(0xFF7A4B29),
                              ),
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: uploadedImageBytes != null
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFBF6F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: uploadedImageBytes != null
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF7A4B29).withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              uploadedImageBytes != null
                                  ? Icons.check_circle_rounded
                                  : Icons.upload_file_rounded,
                              color: uploadedImageBytes != null
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF7A4B29),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    uploadedImageBytes != null
                                        ? 'Foto Terpilih dari Folder:'
                                        : 'Upload Foto dari Galeri / Folder',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: uploadedImageBytes != null
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF7A4B29),
                                    ),
                                  ),
                                  Text(
                                    uploadedImageBytes != null
                                        ? (uploadedFileName ?? 'File gambar dipilih')
                                        : 'Pilih file JPG/PNG dari komputer atau perangkat',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: uploadedImageBytes != null
                                          ? const Color(0xFF2E7D32)
                                          : Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (uploadedImageBytes != null)
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    uploadedImageBytes = null;
                                    uploadedFileName = null;
                                    urlController.clear();
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Ganti', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Pemisah ATAU
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'ATAU GUNAKAN LINK URL',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: urlController,
                      onChanged: (val) {
                        setDialogState(() {
                          if (uploadedImageBytes != null) {
                            uploadedImageBytes = null;
                            uploadedFileName = null;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'URL Gambar / Link Web',
                        hintText: 'https://...',
                        prefixIcon: const Icon(Icons.link_rounded, size: 20, color: Color(0xFF7A4B29)),
                        suffixIcon: urlController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setDialogState(() {
                                    uploadedImageBytes = null;
                                    uploadedFileName = null;
                                    urlController.clear();
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  final newUrl = urlController.text.trim();
                  setState(() {
                    if (isCage && cageIndex != null) {
                      _cages[cageIndex] = _cages[cageIndex].copyWith(
                        imageUrl: newUrl,
                        imageBytes: uploadedImageBytes,
                      );
                    } else {
                      _mainImageUrl = newUrl;
                    }
                  });
                  _precacheImages();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A4B29),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Terapkan Foto'),
              ),
            ],
          );
        },
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
                Color(0xFF5D3A1A),
                Color(0xFF2C1810),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo / Text Header Brand
                  Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'JATIMAS SANGKAR - ADMIN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  // Profil Icon di sudut kanan atas
                  InkWell(
                    key: const Key('admin_add_profile_button'),
                    onTap: _showProfileMenu,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF2C1810),
                        size: 24,
                      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Breadcrumb: Kembali / Tambah Produk Baru
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                      child: Text(
                        'Kembali',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    ' / Tambah Produk Baru',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Konten Utama: Responsif
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kolom Kiri
                        Expanded(
                          flex: 6,
                          child: _buildLeftColumn(),
                        ),
                        const SizedBox(width: 48),
                        // Kolom Kanan
                        Expanded(
                          flex: 4,
                          child: _buildRightColumn(),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeftColumn(),
                        const SizedBox(height: 32),
                        _buildRightColumn(),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kolom Kiri: Foto Utama Produk dan Bentuk Sangkar (Bisa Digeser)
  Widget _buildLeftColumn() {
    final int totalSlides = 1 + _cages.length;
    final bool isLogoSlide = _currentSlideIndex == 0;
    final int currentCageIndex = _currentSlideIndex - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kotak Slider Foto Produk & Bentuk Sangkar
        Container(
          height: 350,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFB0B0B0),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. PageView Slider dengan dukungan Mouse Drag (Desktop/Web) & Touch (HP)
                ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: PageView.builder(
                    controller: _slideController,
                    itemCount: totalSlides,
                    onPageChanged: (index) {
                      setState(() {
                        _currentSlideIndex = index;
                      });
                      _scrollThumbnailToVisible(index);
                    },
                    itemBuilder: (context, index) {
                      final cage = index > 0 ? _cages[index - 1] : null;
                      final slideKey = ValueKey('add_slide_${index}_${index == 0 ? _mainImageUrl : (cage?.imageBytes?.length ?? cage?.imageUrl ?? "")}');
                      if (index == 0) {
                        // Slide 1: Logo Produk
                        return _KeepAliveWrapper(
                          key: slideKey,
                          child: Tooltip(
                            message: 'Klik untuk ubah foto logo produk',
                            child: InkWell(
                              onTap: () => _showEditPhotoDialog(isCage: false),
                              child: _mainImageUrl.isNotEmpty
                                  ? Product.buildImageFromSource(
                                      _mainImageUrl,
                                      fit: BoxFit.contain,
                                      placeholder: _buildPlaceholderIcon(),
                                    )
                                  : _buildPlaceholderIcon(),
                            ),
                          ),
                        );
                      } else {
                        // Slide 2 dst: Bentuk Sangkar
                        final cageIdx = index - 1;
                        final cage = _cages[cageIdx];
                        return _KeepAliveWrapper(
                          key: slideKey,
                          child: Tooltip(
                            message: 'Klik untuk ganti foto ${cage.name}',
                            child: InkWell(
                              onTap: () => _showEditPhotoDialog(isCage: true, cageIndex: cageIdx),
                              child: cage.buildImage(
                                fit: BoxFit.contain,
                                placeholder: _buildPlaceholderIcon(),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),

                // 2. Badge Keterangan Slide di Pojok Kiri Atas
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLogoSlide ? Icons.image_rounded : Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isLogoSlide
                              ? 'Logo Produk (${_currentSlideIndex + 1}/$totalSlides)'
                              : '${_cages[currentCageIndex].name} (${_currentSlideIndex + 1}/$totalSlides)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Tombol Panah Navigasi Kiri (<)
                if (_currentSlideIndex > 0)
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: InkWell(
                        onTap: () {
                          _slideController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: Color(0xFF2C1810),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 4. Tombol Panah Navigasi Kanan (>)
                if (_currentSlideIndex < totalSlides - 1)
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: InkWell(
                        onTap: () {
                          _slideController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Color(0xFF2C1810),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 5. Tombol "Ubah Foto" di Pojok Kanan Bawah
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: InkWell(
                    onTap: () {
                      if (isLogoSlide) {
                        _showEditPhotoDialog(isCage: false);
                      } else {
                        _showEditPhotoDialog(isCage: true, cageIndex: currentCageIndex);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isLogoSlide
                                ? 'Ubah Foto'
                                : 'Ubah Foto ${_cages[currentCageIndex].name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 6. Dot Indicators di Tengah Bawah
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(totalSlides, (idx) {
                      final isActive = idx == _currentSlideIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Horizontal List Thumbnail (Slide 1: Logo, Slide 2+: Bentuk Sangkar)
        SingleChildScrollView(
          controller: _cageScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail 1: Logo Produk
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Column(
                  children: [
                    SizedBox(
                      width: 115,
                      height: 115,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Tooltip(
                            message: 'Lihat / Pilih Logo Produk',
                            child: InkWell(
                              onTap: () {
                                _slideController.animateToPage(
                                  0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 115,
                                height: 115,
                                decoration: BoxDecoration(
                                  color: _currentSlideIndex == 0
                                      ? const Color(0xFF6E6E6E)
                                      : const Color(0xFFA6A6A6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: _currentSlideIndex == 0
                                      ? Border.all(color: const Color(0xFF7A4B29), width: 3)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _mainImageUrl.isNotEmpty
                                      ? Product.buildImageFromSource(
                                          _mainImageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: const Center(
                                            child: Icon(
                                              Icons.add_photo_alternate_rounded,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.add_photo_alternate_rounded,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          // Badge Edit Foto di pojok kanan bawah
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: InkWell(
                              onTap: () => _showEditPhotoDialog(isCage: false),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Label Logo Produk
                    Text(
                      'Logo Produk',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _currentSlideIndex == 0 ? FontWeight.bold : FontWeight.w600,
                        color: _currentSlideIndex == 0 ? const Color(0xFF2C1810) : const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ),

              // Thumbnail 2 dst: Bentuk Sangkar
              ...List.generate(_cages.length, (index) {
                final cage = _cages[index];
                final isSelected = _currentSlideIndex == index + 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Column(
                    children: [
                      // Kotak Sangkar (Klik langsung untuk geser ke slide atau ganti foto)
                      SizedBox(
                        width: 115,
                        height: 115,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Tooltip(
                              message: 'Lihat / Pilih ${cage.name}',
                              child: InkWell(
                                onTap: () {
                                  _slideController.animateToPage(
                                    index + 1,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 115,
                                  height: 115,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF6E6E6E)
                                        : const Color(0xFFA6A6A6),
                                    borderRadius: BorderRadius.circular(14),
                                    border: isSelected
                                        ? Border.all(color: const Color(0xFF7A4B29), width: 3)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: cage.buildImage(
                                      fit: BoxFit.cover,
                                      placeholder: const Center(
                                        child: Icon(
                                          Icons.add_photo_alternate_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Badge Edit Foto di pojok kanan bawah
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: InkWell(
                                onTap: () => _showEditPhotoDialog(isCage: true, cageIndex: index),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Label Nama Sangkar (misal Sangkar 1, Sangkar 2)
                      Text(
                        cage.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? const Color(0xFF2C1810) : const Color(0xFF555555),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderIcon({String? label}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 8),
          Text(
            label ?? 'Belum ada foto',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Klik untuk upload foto',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  /// Kolom Kanan: Input Kode, Input Nama Produk, Tombol Buat, dan Divider
  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Kode
        const Text(
          'Kode',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A4A4A),
          ),
        ),
        const SizedBox(height: 8),

        // Input Field Kode
        SizedBox(
          width: 100,
          height: 38,
          child: TextField(
            key: const Key('admin_add_code_field'),
            controller: _codeController,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A4A),
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF7A4B29), width: 1.5),
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Input Field Nama Produk
        SizedBox(
          width: double.infinity,
          height: 38,
          child: TextField(
            key: const Key('admin_add_name_field'),
            controller: _nameController,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A4A),
            ),
            decoration: InputDecoration(
              hintText: 'Nama Produk',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF7A4B29), width: 1.5),
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Input Field Hashtag / Kategori Produk
        SizedBox(
          width: double.infinity,
          height: 38,
          child: TextField(
            key: const Key('admin_add_hashtag_field'),
            controller: _hashtagController,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A4A),
            ),
            decoration: InputDecoration(
              hintText: 'Hashtag (Contoh: #sangkar #jati #jepara)',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF7A4B29), width: 1.5),
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Tombol Buat (Outlined persis di gambar)
        OutlinedButton(
          key: const Key('admin_create_button'),
          onPressed: _isLoading ? null : _createProduct,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFAAAAAA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF7A4B29),
                  ),
                )
              : const Text(
                  'Buat',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A4A4A),
                  ),
                ),
        ),

        const SizedBox(height: 24),

        // Garis Pembatas (Sesuai gambar referensi)
        const Divider(
          color: Color(0xFFD0D0D0),
          thickness: 1,
        ),
      ],
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({super.key, required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
