import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/cage_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/storage_service.dart';
import '../widgets/hero_banner.dart';

class UserHomePage extends StatefulWidget {
  final List<Product> customLogos;
  final Function(Product newCustomProduct) onAddCustomLogo;
  final Function(Product product) onProductTap;
  final VoidCallback onOpenStandardCatalog;
  final VoidCallback? onCartTap;

  const UserHomePage({
    super.key,
    required this.customLogos,
    required this.onAddCustomLogo,
    required this.onProductTap,
    required this.onOpenStandardCatalog,
    this.onCartTap,
  });

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int _customLogoLimit = 10;
  bool _isLoadingMoreCustom = false;

  void _loadMoreCustomLogos() {
    if (_isLoadingMoreCustom) return;
    final total = widget.customLogos.length;
    if (_customLogoLimit >= total) return;

    setState(() {
      _isLoadingMoreCustom = true;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _customLogoLimit = _customLogoLimit + 10;
          _isLoadingMoreCustom = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant UserHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customLogos.length != widget.customLogos.length) {
      if (_customLogoLimit > widget.customLogos.length &&
          widget.customLogos.length >= 10) {
        _customLogoLimit = 10;
      }
    }
  }

  void _showRequestDialog() {
    final nameController = TextEditingController();
    final hashtagController = TextEditingController();
    final imageController = TextEditingController();
    final noteController = TextEditingController();
    String imageUrl = '';
    String? uploadedFileName;
    String selectedCage = CageService.instance.cages.isNotEmpty
        ? CageService.instance.cages.first.name
        : 'Standar';

    Future<void> pickImageFromFile(StateSetter setModalState) async {
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          final bytes = await picked.readAsBytes();
          final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
          final base64String = 'data:image/$ext;base64,${base64Encode(bytes)}';
          setModalState(() {
            uploadedFileName = picked.name;
            imageUrl = base64String;
            imageController.text = picked.name;
          });
          // Unggah ke Supabase Storage di latar belakang agar mendapatkan URL publik langsung
          StorageService.instance.uploadImageIfPossible(base64String).then((publicUrl) {
            if (publicUrl != null && publicUrl.isNotEmpty) {
              setModalState(() {
                imageUrl = publicUrl;
              });
            }
          });
        }
      } catch (e) {
        debugPrint('Gagal memilih file gambar dari folder: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Dialog
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.brush_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Permintaan Logo Custom Sangkar',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Ajukan motif ukir atau logo identitas Anda',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. Input Nama Logo
                    const Text(
                      'Nama Logo / Desain Custom',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Logo Harimau Putih Juara',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Input Hashtag / Kategori Custom
                    const Text(
                      'Hashtag / Kategori Custom',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: hashtagController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.tag_rounded,
                          size: 18,
                          color: Color(0xFF4A301E),
                        ),
                        hintText: 'Contoh: #LogoCustomUkir atau #HarimauPutih',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Pilihan Bentuk Sangkar Burung
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pilihan Bentuk Sangkar Burung',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            selectedCage,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4A301E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: CageService.instance.cages.isEmpty
                            ? [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4A301E),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Standar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ]
                            : CageService.instance.cages.map((cage) {
                          final isSelected = selectedCage == cage.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedCage = cage.name;
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF4A301E)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF4A301E)
                                        : Colors.grey.shade300,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: Color(0xFFFFD900),
                                      )
                                    else if (cage.imageBytes != null || (cage.imageUrl != null && cage.imageUrl!.isNotEmpty))
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: cage.buildImage(fit: BoxFit.cover),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.view_in_ar_rounded,
                                        size: 16,
                                        color: Colors.black54,
                                      ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cage.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. Insert Gambar (Pilih File dari Folder Komputer / HP)
                    const Text(
                      'Insert Gambar Logo / Desain',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl.isEmpty) ...[
                            // Tombol Utama: Upload File dari Folder Komputer / HP
                            InkWell(
                              key: const ValueKey('upload_logo_from_folder_btn'),
                              onTap: () => pickImageFromFile(setModalState),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF7A4B29).withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFBF6F2),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF7A4B29).withValues(alpha: 0.2)),
                                      ),
                                      child: const Icon(
                                        Icons.drive_folder_upload_rounded,
                                        size: 30,
                                        color: Color(0xFF7A4B29),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Pilih File Gambar dari Folder Anda',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF4A301E),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Klik di sini untuk membuka berkas folder (PNG, JPG, JPEG)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Opsi Tambahan: Tempel URL Web jika dibutuhkan (Opsional, Tanpa Template)
                            TextField(
                              controller: imageController,
                              style: const TextStyle(fontSize: 12.5),
                              onChanged: (val) {
                                setModalState(() {
                                  imageUrl = val.trim();
                                  uploadedFileName = null;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Atau tempel Link / URL gambar web (opsional)',
                                hintStyle: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: const Icon(
                                  Icons.link_rounded,
                                  size: 18,
                                  color: Color(0xFF7A4B29),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Area Pratinjau Gambar yang Diupload
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Product.buildImageFromSource(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    uploadedFileName != null && uploadedFileName!.isNotEmpty
                                        ? 'File: $uploadedFileName'
                                        : 'Gambar siap digunakan',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => pickImageFromFile(setModalState),
                                  icon: const Icon(Icons.folder_open_rounded, size: 14),
                                  label: const Text('Ganti File', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4A301E),
                                    side: const BorderSide(color: Color(0xFF7A4B29)),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: const Size(0, 30),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: 'Hapus Gambar',
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () {
                                    setModalState(() {
                                      imageUrl = '';
                                      uploadedFileName = null;
                                      imageController.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Catatan Khusus Permintaan Logo
                    const Text(
                      'Catatan Desain & Posisi Ukir',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Contoh: Ukir timbul di mahkota atas dan tebok bawah...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Submit Request
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Silakan masukkan nama logo custom Anda',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          if (imageUrl.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Silakan pilih file gambar logo dari folder Anda terlebih dahulu',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          // Format hashtag dari input user
                          String rawHashtag = hashtagController.text.trim();
                          String formattedHashtag;
                          if (rawHashtag.isEmpty) {
                            formattedHashtag = '#LogoCustom';
                          } else {
                            final cleaned = rawHashtag.replaceAll(' ', '');
                            formattedHashtag = cleaned.startsWith('#')
                                ? cleaned
                                : '#$cleaned';
                          }

                          final newProduct = Product(
                            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            price: 0,
                            description: noteController.text.trim().isNotEmpty
                                ? noteController.text.trim()
                                : 'Desain logo custom sangkar buatan user login.',
                            imageUrl: imageUrl,
                            category: formattedHashtag,
                            rating: 5.0,
                            isUserCustom: true,
                            customNote: noteController.text.trim(),
                            selectedCage: selectedCage,
                          );

                          widget.onAddCustomLogo(newProduct);
                          final currentId = AuthService.instance.userPhone.isNotEmpty
                              ? AuthService.instance.userPhone
                              : AuthService.instance.userEmail;
                          if (currentId.isNotEmpty) {
                            UserService.instance.incrementCustomLogoCount(currentId);
                          }
                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Logo custom "$name" ($formattedHashtag - $selectedCage) berhasil disimpan & dimasukkan ke keranjang!',
                              ),
                              action: widget.onCartTap != null
                                  ? SnackBarAction(
                                      label: 'Lihat Keranjang',
                                      textColor: const Color(0xFFFFD900),
                                      onPressed: widget.onCartTap!,
                                    )
                                  : null,
                              backgroundColor: Colors.green.shade800,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'Kirim Permintaan Logo Custom',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A301E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 250) {
          _loadMoreCustomLogos();
        }
        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Banner seperti di Umum dengan tombol Katalog Umum menimpa di atasnya
          Stack(
            children: [
              const HeroBanner(),
              Positioned(
                top: 20,
                right: 16,
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenStandardCatalog,
                  icon: const Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Katalog Umum',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),

        // 2. Katalog di Beranda yang Isinya CUMA Logo Custom Buatan User Login
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Katalog Custom & Tombol Permintaan Logo Custom di sebelah kanan
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 560;

                  final titleSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Katalog Logo Custom Saya',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hanya memuat logo & ukiran custom buatan Anda (${widget.customLogos.length} desain)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  );

                  final requestBtn = ElevatedButton.icon(
                    onPressed: _showRequestDialog,
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Permintaan Logo Custom',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD900),
                      foregroundColor: const Color(0xFF382314),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleSection,
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: requestBtn,
                        ),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: 16),
                      requestBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              if (widget.customLogos.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 40.0,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.palette_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum ada logo custom yang Anda buat',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tekan tombol "Permintaan Logo Custom" di atas untuk membuat desain logo pertama Anda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final int crossAxisCount;
                    final double childAspectRatio;

                    if (width >= 750) {
                      crossAxisCount = 5;
                      childAspectRatio = 0.88;
                    } else if (width >= 540) {
                      crossAxisCount = 3;
                      childAspectRatio = 0.90;
                    } else {
                      crossAxisCount = 2;
                      childAspectRatio = 0.80;
                    }

                    final visibleLogos = widget.customLogos
                        .take(_customLogoLimit)
                        .toList();
                    final hasMoreCustom =
                        widget.customLogos.length > _customLogoLimit;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visibleLogos.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemBuilder: (context, index) {
                            final item = visibleLogos[index];
                            return _buildCustomLogoCard(context, item);
                          },
                        ),
                        const SizedBox(height: 20),
                        if (_isLoadingMoreCustom)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: CircularProgressIndicator(
                                color: Color(0xFF7A4B29),
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        else if (hasMoreCustom)
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: _loadMoreCustomLogos,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF7A4B29),
                              ),
                              label: Text(
                                'Muat Lebih Banyak (${widget.customLogos.length - _customLogoLimit} lagi)',
                                style: const TextStyle(
                                  color: Color(0xFF7A4B29),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xFF7A4B29)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          )
                        else if (widget.customLogos.length > 10)
                          Center(
                            child: Text(
                              'Semua ${widget.customLogos.length} logo custom telah ditampilkan',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildCustomLogoCard(BuildContext context, Product product) {
    return InkWell(
      onTap: () => widget.onProductTap(product),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Logo Custom: Dibuat 100% seragam dengan Positioned.fill dan BoxFit.cover
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey.shade100,
                        child: product.buildImage(fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF382314),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFD900),
                            size: 12,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Custom',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Keterangan Logo Custom dengan dimensi tinggi seragam persis kartu utama
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 6.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Daftar Hashtag Terpisah (Pill/Chip Mandiri untuk Katalog Private)
                  SizedBox(
                    height: 20,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: (product.hashtagList.isNotEmpty
                                ? product.hashtagList
                                : [
                                    product.category.startsWith('#')
                                        ? product.category
                                        : '#${product.category}'
                                  ])
                            .map((tag) {
                          return Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.amber.shade200,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.brown.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Nama Logo (Ditetapkan tinggi pasti 32 untuk 2 baris agar presisi sama persis)
                  SizedBox(
                    height: 32,
                    child: Text(
                      product.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
