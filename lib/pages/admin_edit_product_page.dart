import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/cage_service.dart';
import '../services/product_service.dart';

class AdminEditProductPage extends StatefulWidget {
  final Product? product;
  final AdminPublicProduct? adminProduct;

  const AdminEditProductPage({
    super.key,
    this.product,
    this.adminProduct,
  });

  @override
  State<AdminEditProductPage> createState() => _AdminEditProductPageState();
}

class _AdminEditProductPageState extends State<AdminEditProductPage> {
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _hashtagController;

  String _mainImageUrl = '';
  String _lastEditedDate = '09-09-2026';
  late String _productId;

  // Daftar variasi bentuk sangkar untuk produk ini
  final List<ProductCageVariation> _cages = [];

  // Sample photo options for quick selection
  static const List<String> samplePhotos = [
    'https://images.unsplash.com/photo-1548767797-d8c844163c4c?w=600',
    'https://images.unsplash.com/photo-1552728089-57bdde30beb3?w=600',
    'https://images.unsplash.com/photo-1522858547137-f1dcec554f55?w=600',
    'https://images.unsplash.com/photo-1555169062-013468b47731?w=600',
  ];

  @override
  void initState() {
    super.initState();

    final p = widget.product;
    final ap = widget.adminProduct;

    _productId = p?.id ?? ap?.id ?? '';
    _codeController = TextEditingController(text: p?.code ?? ap?.code ?? 'A01');
    _nameController = TextEditingController(
      text: p?.name ?? ap?.name ?? '',
    );
    _hashtagController = TextEditingController(
      text: p?.hashtags ?? ap?.hashtags ?? '',
    );

    _mainImageUrl = p?.imageUrl ?? ap?.imageUrl ?? '';
    _lastEditedDate = p?.lastEditedDate ?? ap?.lastEditedDate ?? _getTodayFormatted();

    // Inisialisasi daftar bentuk sangkar dari CageService (agar sinkron dengan Admin Dashboard & semua halaman)
    final serviceCages = CageService.instance.cages;
    if (p?.cageVariations != null && p!.cageVariations!.isNotEmpty) {
      _cages.addAll(p.cageVariations!);
    } else if (ap?.cageVariations != null && ap!.cageVariations!.isNotEmpty) {
      _cages.addAll(ap.cageVariations!);
    } else if (serviceCages.isNotEmpty) {
      _cages.addAll(serviceCages.map((c) => ProductCageVariation(
            id: c.id,
            name: c.name,
            imageUrl: c.imageUrl ?? '',
          )));
    } else {
      _cages.addAll([
        const ProductCageVariation(id: 'c1', name: 'Sangkar 1'),
        const ProductCageVariation(id: 'c2', name: 'Sangkar 2'),
        const ProductCageVariation(id: 'c3', name: 'Sangkar 3'),
        const ProductCageVariation(id: 'c4', name: 'Sangkar 4'),
      ]);
    }

    // Pastikan foto sangkar terisi dari CageService jika kosong
    for (int i = 0; i < _cages.length; i++) {
      if (_cages[i].imageUrl.isEmpty) {
        final match = serviceCages.firstWhere(
          (c) => c.name.toLowerCase() == _cages[i].name.toLowerCase(),
          orElse: () => const CageData(id: '', name: ''),
        );
        if (match.imageUrl != null && match.imageUrl!.isNotEmpty) {
          _cages[i] = _cages[i].copyWith(imageUrl: match.imageUrl);
        }
      }
    }
  }

  String _getTodayFormatted() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    return '$day-$month-$year';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  Future<void> _saveProduct() async {
    final newCode = _codeController.text.trim();
    final newName = _nameController.text.trim();
    final newHashtags = _hashtagController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama produk tidak boleh kosong!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final today = _getTodayFormatted();

    try {
      await ProductService.instance.updateProduct(
        id: _productId,
        name: newName,
        code: newCode.isNotEmpty ? newCode : 'A01',
        imageUrl: _mainImageUrl,
        hashtags: newHashtags,
        cageVariations: List.from(_cages),
        lastEditedDate: today,
      );

      if (!mounted) return;

      setState(() {
        _lastEditedDate = today;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Produk "$newName" berhasil disimpan ke database Supabase!'),
          backgroundColor: const Color(0xFF7A4B29),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan perubahan ke Supabase: $e'),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 5),
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

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('Apakah Anda yakin ingin menghapus produk "${_nameController.text.trim()}" dari database Supabase?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ProductService.instance.deleteProduct(_productId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk berhasil dihapus dari database Supabase!'),
          backgroundColor: Color(0xFF7A4B29),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus produk: $e'),
          backgroundColor: Colors.red.shade800,
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
                leading: const Icon(Icons.swap_horiz_rounded, color: Colors.black87),
                title: const Text('Beralih ke Akun Member'),
                onTap: () {
                  Navigator.pop(ctx);
                  AuthService.instance.toggleRole();
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
    final urlController = TextEditingController(
      text: isCage && cageIndex != null
          ? _cages[cageIndex].imageUrl
          : _mainImageUrl,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          isCage ? 'Ubah Foto ${cageIndex != null ? _cages[cageIndex].name : "Sangkar"}' : 'Ubah Foto Produk',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan URL foto baru atau pilih contoh foto di bawah:',
                style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'URL Gambar',
                  hintText: 'https://...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pilih Contoh Foto Sangkar Jati:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6E6E6E)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(samplePhotos.length, (idx) {
                  final photo = samplePhotos[idx];
                  return InkWell(
                    onTap: () {
                      urlController.text = photo;
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                          image: NetworkImage(photo),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
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
                  _cages[cageIndex] = _cages[cageIndex].copyWith(imageUrl: newUrl);
                  CageService.instance.updateCageImageByName(_cages[cageIndex].name, newUrl);
                } else {
                  _mainImageUrl = newUrl;
                }
              });
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
      ),
    );
  }

  void _addCage() {
    final nextNumber = _cages.length + 1;
    final nameCtrl = TextEditingController(
      text: 'Sangkar $nextNumber',
    );
    String selectedPhoto = CageService.sampleCageImages[(nextNumber - 1) % CageService.sampleCageImages.length];
    final photoCtrl = TextEditingController(text: selectedPhoto);
    Uint8List? uploadedImageBytes;
    String? uploadedFileName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.add_box_rounded, color: Color(0xFF7A4B29)),
                SizedBox(width: 8),
                Text('Tambah Bentuk Sangkar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nama Bentuk Sangkar:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Sangkar 5',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Foto / Gambar Sangkar:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 120,
                        height: 85,
                        decoration: BoxDecoration(
                          color: const Color(0xFFA6A6A6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (uploadedImageBytes != null && uploadedImageBytes!.isNotEmpty)
                            ? Image.memory(
                                uploadedImageBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Center(
                                  child: Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 28),
                                ),
                              )
                            : selectedPhoto.isNotEmpty
                                ? Image.network(
                                    selectedPhoto,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => const Center(
                                      child: Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 28),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 28),
                                  ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tombol Upload Foto Langsung dari Perangkat
                    InkWell(
                      key: const ValueKey('edit_page_upload_cage_btn'),
                      onTap: () async {
                        try {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setDialogState(() {
                              uploadedImageBytes = bytes;
                              uploadedFileName = picked.name;
                              selectedPhoto = '';
                              photoCtrl.clear();
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
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: uploadedImageBytes != null
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFBF6F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: uploadedImageBytes != null
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF7A4B29).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              uploadedImageBytes != null
                                  ? Icons.check_circle_rounded
                                  : Icons.cloud_upload_rounded,
                              color: uploadedImageBytes != null
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF7A4B29),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                uploadedImageBytes != null
                                    ? '✓ ${uploadedFileName ?? "File dipilih"}'
                                    : 'Upload Foto dari Galeri / File',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: uploadedImageBytes != null
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF7A4B29),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    TextField(
                      controller: photoCtrl,
                      onChanged: (val) {
                        setDialogState(() {
                          selectedPhoto = val.trim();
                          if (val.trim().isNotEmpty) {
                            uploadedImageBytes = null;
                            uploadedFileName = null;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Atau Masukkan URL Foto',
                        hintText: 'https://...',
                        prefixIcon: const Icon(Icons.link, size: 18, color: Color(0xFF7A4B29)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Pilih Contoh Foto Sangkar:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF777777))),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: CageService.sampleCageImages.map((img) {
                          final isChosen = selectedPhoto == img && uploadedImageBytes == null;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selectedPhoto = img;
                                  photoCtrl.text = img;
                                  uploadedImageBytes = null;
                                  uploadedFileName = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isChosen ? const Color(0xFF7A4B29) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.network(img, fit: BoxFit.cover),
                              ),
                            ),
                          );
                        }).toList(),
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
                  final name = nameCtrl.text.trim().isNotEmpty
                      ? nameCtrl.text.trim()
                      : 'Sangkar $nextNumber';
                  final addedCage = CageService.instance.addCage(
                    name: name,
                    imageUrl: uploadedImageBytes != null ? null : selectedPhoto,
                    imageBytes: uploadedImageBytes,
                  );
                  setState(() {
                    _cages.add(
                      ProductCageVariation(
                        id: addedCage.id,
                        name: addedCage.name,
                        imageUrl: addedCage.imageUrl ?? selectedPhoto,
                        imageBytes: uploadedImageBytes,
                      ),
                    );
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Bentuk sangkar "$name" berhasil ditambahkan dan disinkronkan ke Dashboard!'),
                      backgroundColor: const Color(0xFF7A4B29),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A4B29),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _editCage(int index) {
    final cage = _cages[index];
    final nameCtrl = TextEditingController(text: cage.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Edit ${cage.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nama Sangkar',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showEditPhotoDialog(isCage: true, cageIndex: index);
              },
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Ganti Foto Sangkar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7A4B29),
                side: const BorderSide(color: Color(0xFF7A4B29)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final oldName = _cages[index].name;
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  _cages[index] = _cages[index].copyWith(name: newName);
                });
                final match = CageService.instance.cages.firstWhere(
                  (c) => c.name.toLowerCase() == oldName.toLowerCase(),
                  orElse: () => const CageData(id: '', name: ''),
                );
                if (match.id.isNotEmpty) {
                  CageService.instance.updateCage(id: match.id, name: newName);
                }
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A4B29),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _removeCage(int index) {
    final removed = _cages[index];
    CageService.instance.removeCageByName(removed.name);
    setState(() {
      _cages.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bentuk sangkar "${removed.name}" dihapus dan disinkronkan ke Dashboard.'),
        duration: const Duration(seconds: 1),
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
                  // Profil Icon di sudut kanan atas seperti pada gambar
                  InkWell(
                    key: const Key('admin_edit_profile_button'),
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
              // 1. Breadcrumb: Kembali / Detail Produk
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
                    ' / Detail Produk',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. Konten Utama: Responsif (Kiri: Foto & Sangkar, Kanan: Form Kode, Nama & Simpan)
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

  /// Kolom Kiri: Foto Utama Produk dan Bentuk Sangkar
  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kotak Foto Produk Utama (Abu-abu Membulat dengan Icon Add Photo)
        Tooltip(
          message: 'Klik untuk ubah foto produk',
          child: InkWell(
            onTap: () => _showEditPhotoDialog(isCage: false),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 290,
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
                child: _mainImageUrl.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _mainImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => _buildPlaceholderIcon(),
                          ),
                          Positioned(
                            right: 14,
                            bottom: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ubah Foto',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : _buildPlaceholderIcon(),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Bagian: Bentuk Sangkar
        const Text(
          'Bentuk Sangkar',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF555555),
          ),
        ),
        const SizedBox(height: 14),

        // Horizontal List Bentuk Sangkar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(_cages.length, (index) {
                final cage = _cages[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 14.0),
                  child: Column(
                    children: [
                      // Kotak Sangkar dengan tombol [x] di pojok kanan atas
                      SizedBox(
                        width: 78,
                        height: 78,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Kotak Abu-Abu Sangkar
                            InkWell(
                              onTap: () => _editCage(index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  color: index == 0
                                      ? const Color(0xFF6E6E6E) // sedikit lebih gelap untuk item pertama seperti di gambar
                                      : const Color(0xFFA6A6A6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: cage.buildImage(
                                    fit: BoxFit.cover,
                                    placeholder: const Center(
                                      child: Icon(
                                        Icons.add_photo_alternate_rounded,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Tombol [x] di pojok kanan atas
                            Positioned(
                              top: -4,
                              right: -4,
                              child: InkWell(
                                onTap: () => _removeCage(index),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 13,
                                    ),
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Tombol Tambah Bentuk Sangkar
              Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: InkWell(
                  onTap: _addCage,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFCCCCCC),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_rounded,
                            color: Color(0xFF7A4B29),
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '+ Tambah',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A4B29),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderIcon() {
    return const Center(
      child: Icon(
        Icons.add_photo_alternate_rounded,
        size: 78,
        color: Colors.white,
      ),
    );
  }

  /// Kolom Kanan: Input Kode, Input Nama, Tombol Simpan, dan Terakhir di edit
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

        // Input Field Kode (Kecil/Kompak)
        SizedBox(
          width: 100,
          height: 38,
          child: TextField(
            key: const Key('admin_edit_code_field'),
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

        // Input Field Nama Produk (Panjang)
        SizedBox(
          width: double.infinity,
          height: 38,
          child: TextField(
            key: const Key('admin_edit_name_field'),
            controller: _nameController,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A4A),
            ),
            decoration: InputDecoration(
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

        // Input Field Hashtag / Kategori Produk (Sesuai Permintaan User)
        SizedBox(
          width: double.infinity,
          height: 38,
          child: TextField(
            key: const Key('admin_edit_hashtag_field'),
            controller: _hashtagController,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A4A),
            ),
            decoration: InputDecoration(
              hintText: '#hashtag (Contoh: #sangkar #jati #jepara)',
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

        // Tombol Simpan & Hapus
        Row(
          children: [
            OutlinedButton(
              key: const Key('admin_save_button'),
              onPressed: _isLoading ? null : _saveProduct,
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
                      'Simpan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            OutlinedButton.icon(
              key: const Key('admin_delete_button'),
              onPressed: _isLoading ? null : _deleteProduct,
              icon: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade700),
              label: Text(
                'Hapus',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Garis Pembatas
        const Divider(
          color: Color(0xFFD0D0D0),
          thickness: 1,
        ),
        const SizedBox(height: 6),

        // Info Terakhir di edit pada : dd-MM-yyyy
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Terakhir di edit pada : $_lastEditedDate',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF555555),
            ),
          ),
        ),
      ],
    );
  }
}
