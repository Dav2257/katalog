import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/product.dart';
import '../services/cage_service.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../widgets/top_navbar.dart';

class CageOption {
  final String id;
  final String name;
  int quantity;
  String note;
  String? imageUrl;
  Uint8List? imageBytes;

  CageOption({
    required this.id,
    required this.name,
    this.quantity = 0,
    this.note = '',
    this.imageUrl,
    this.imageBytes,
  });
}

class ProductDetailPage extends StatefulWidget {
  final Product product;
  final void Function(List<CartItem> items)? onAddItemsToCart;
  final void Function(
    Product product, {
    String? cageSummary,
    String? note,
    int totalQuantity,
  })?
  onAddCustomToCart;
  final void Function(Product product)? onAddToCart;
  final int cartItemCount;
  final int Function()? getCartItemCount;
  final bool isLoggedIn;
  final bool isAdmin;
  final VoidCallback? onCartTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogout;

  const ProductDetailPage({
    super.key,
    required this.product,
    this.onAddItemsToCart,
    this.onAddCustomToCart,
    this.onAddToCart,
    this.cartItemCount = 0,
    this.getCartItemCount,
    this.isLoggedIn = false,
    this.isAdmin = false,
    this.onCartTap,
    this.onProfileTap,
    this.onLogout,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final PageController _slideController;
  int _currentSlideIndex = 0;

  int _selectedCageIndex = 0;
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _cageScrollController = ScrollController();

  final List<CageOption> _cages = [];

  @override
  void initState() {
    super.initState();
    _slideController = PageController();
    // Sinkronisasi status autentikasi awal jika widget diberikan parameter eksplisit
    if (widget.isLoggedIn && !AuthService.instance.isLoggedIn) {
      AuthService.instance.login(isAdmin: widget.isAdmin);
    }
    AuthService.instance.addListener(_handleAuthUpdate);
    _loadCagesFromService();
    CageService.instance.addListener(_handleCageServiceUpdate);

    // Jika produk memiliki selectedCage dari pembuatan custom logo
    if (widget.product.selectedCage != null &&
        widget.product.selectedCage!.isNotEmpty) {
      final matchIndex = _cages.indexWhere(
        (c) =>
            c.name.toLowerCase() == widget.product.selectedCage!.toLowerCase(),
      );
      if (matchIndex >= 0) {
        _selectedCageIndex = matchIndex;
      }
    }

    // Jika produk memiliki catatan desain & posisi ukir (customNote),
    // pre-fill ke dalam catatan bentuk sangkar yang aktif
    if (widget.product.customNote != null &&
        widget.product.customNote!.trim().isNotEmpty) {
      if (_selectedCageIndex < _cages.length) {
        final note = widget.product.customNote!.trim();
        _cages[_selectedCageIndex].note = note.length > 100
            ? note.substring(0, 100)
            : note;
      }
    }

    if (_cages.isNotEmpty) {
      _noteController.text = _cages[_selectedCageIndex].note;
    }

    _precacheImages();
  }

  void _precacheImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.product.imageUrl.isNotEmpty) {
        _precacheSource(widget.product.imageUrl);
      }
      for (final cage in _cages) {
        if (cage.imageBytes != null && cage.imageBytes!.isNotEmpty) {
          precacheImage(MemoryImage(cage.imageBytes!), context).catchError((_) {});
        } else if (cage.imageUrl != null && cage.imageUrl!.isNotEmpty) {
          _precacheSource(cage.imageUrl!);
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

  void _loadCagesFromService() {
    final Map<String, CageOption> existing = {for (final c in _cages) c.id: c};
    final List<CageOption> updated = [];

    final serviceCages = CageService.instance.cages;
    final productVariations = widget.product.cageVariations ?? [];

    if (serviceCages.isNotEmpty) {
      for (final sc in serviceCages) {
        final matchCustom = productVariations.where(
          (cv) => cv.name.toLowerCase() == sc.name.toLowerCase() || cv.id == sc.id,
        ).firstOrNull;

        final prev = existing[sc.id];
        updated.add(
          CageOption(
            id: sc.id,
            name: sc.name,
            quantity: prev?.quantity ?? 0,
            note: prev?.note ?? '',
            imageUrl: (matchCustom != null && matchCustom.imageUrl.isNotEmpty)
                ? matchCustom.imageUrl
                : sc.imageUrl,
            imageBytes: matchCustom?.imageBytes ?? sc.imageBytes,
          ),
        );
      }
    } else if (productVariations.isNotEmpty) {
      for (final cv in productVariations) {
        final prev = existing[cv.id];
        updated.add(
          CageOption(
            id: cv.id,
            name: cv.name,
            quantity: prev?.quantity ?? 0,
            note: prev?.note ?? '',
            imageUrl: cv.imageUrl,
            imageBytes: cv.imageBytes,
          ),
        );
      }
    }

    if (updated.isEmpty) {
      updated.add(
        CageOption(
          id: 'standard',
          name: 'Standar',
          quantity: existing['standard']?.quantity ?? 0,
          note: existing['standard']?.note ?? '',
          imageUrl: widget.product.imageUrl,
        ),
      );
    }

    _cages
      ..clear()
      ..addAll(updated);

    if (_selectedCageIndex >= _cages.length) {
      _selectedCageIndex = (_cages.length - 1).clamp(0, 999);
    }
  }

  void _handleCageServiceUpdate() {
    if (!mounted) return;
    setState(() {
      _loadCagesFromService();
      if (_selectedCageIndex < _cages.length) {
        _noteController.text = _cages[_selectedCageIndex].note;
      }
      _precacheImages();
    });
  }

  /// Ganti foto bentuk sangkar khusus produk ini (tidak mengubah produk lain)
  void _changeCageImageForProduct(int cageIndex) {
    if (cageIndex >= _cages.length) return;
    final cage = _cages[cageIndex];
    final urlCtrl = TextEditingController(text: cage.imageUrl ?? '');
    Uint8List? pickedBytes;
    String? pickedName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                const Icon(Icons.camera_alt_rounded, color: Color(0xFF7A4B29)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ganti Foto ${cage.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Foto ini hanya diterapkan untuk produk "${widget.product.name}" dan tidak akan mengubah produk lain.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 14),

                  // Opsi Upload File dari Galeri / Komputer
                  InkWell(
                    onTap: () async {
                      try {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          setDialogState(() {
                            pickedBytes = bytes;
                            pickedName = picked.name;
                            urlCtrl.clear();
                          });
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Gagal upload: $e')),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: pickedBytes != null ? const Color(0xFFE8F5E9) : const Color(0xFFFBF6F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: pickedBytes != null ? const Color(0xFF4CAF50) : const Color(0xFF7A4B29).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            pickedBytes != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                            color: pickedBytes != null ? const Color(0xFF2E7D32) : const Color(0xFF7A4B29),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              pickedBytes != null ? '✓ ${pickedName ?? "Foto Terpilih"}' : 'Pilih Foto dari Galeri / File',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: pickedBytes != null ? const Color(0xFF2E7D32) : const Color(0xFF7A4B29),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text('Atau Masukkan URL Gambar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: urlCtrl,
                    onChanged: (val) {
                      if (val.trim().isNotEmpty) {
                        setDialogState(() {
                          pickedBytes = null;
                          pickedName = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      prefixIcon: const Icon(Icons.link, size: 16, color: Color(0xFF7A4B29)),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
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
                  final newUrl = urlCtrl.text.trim();
                  setState(() {
                    cage.imageUrl = newUrl.isNotEmpty ? newUrl : null;
                    cage.imageBytes = pickedBytes;
                  });

                  // Update ProductService agar tersimpan khusus produk ini
                  final updatedVariations = _cages.map((c) => ProductCageVariation(
                    id: c.id,
                    name: c.name,
                    imageUrl: c.imageUrl ?? '',
                    imageBytes: c.imageBytes,
                  )).toList();

                  ProductService.instance.updateProduct(
                    id: widget.product.id,
                    name: widget.product.name,
                    code: widget.product.code ?? 'A01',
                    hashtags: widget.product.hashtags,
                    cageVariations: updatedVariations,
                  );

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Foto ${cage.name} untuk "${widget.product.name}" berhasil diubah!'),
                      backgroundColor: const Color(0xFF7A4B29),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A4B29),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Simpan Foto'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_handleAuthUpdate);
    CageService.instance.removeListener(_handleCageServiceUpdate);
    _noteController.dispose();
    _cageScrollController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _scrollCageThumbToVisible(int slideIdx) {
    if (!_cageScrollController.hasClients) return;
    const itemWidth = 124.0;
    final targetIndex = (slideIdx > 0) ? (slideIdx - 1) : 0;
    final targetOffset = (targetIndex * itemWidth) - 40.0;
    _cageScrollController.animateTo(
      targetOffset.clamp(0.0, _cageScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _handleAuthUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isLoggedIn => AuthService.instance.isLoggedIn;
  bool get _isAdmin => AuthService.instance.isAdmin;

  int get _charCount => _noteController.text.length;

  int get _currentCartCount => widget.getCartItemCount != null
      ? widget.getCartItemCount!()
      : widget.cartItemCount;

  int get _totalQuantity => _cages.fold(0, (sum, cage) => sum + cage.quantity);

  void _selectCage(int index) {
    if (_selectedCageIndex == index && _currentSlideIndex == index + 1) return;
    // Simpan catatan bentuk yang sedang aktif
    _cages[_selectedCageIndex].note = _noteController.text;

    setState(() {
      _selectedCageIndex = index;
      _currentSlideIndex = index + 1;
      // Muat catatan khusus bentuk yang baru dipilih
      _noteController.text = _cages[index].note;
      _noteController.selection = TextSelection.fromPosition(
        TextPosition(offset: _noteController.text.length),
      );
    });

    if (_slideController.hasClients) {
      _slideController.animateToPage(
        index + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleNoteChanged(String text) {
    if (text.length > 100) {
      // Batasi maksimal 100 huruf / karakter
      final truncated = text.substring(0, 100);
      _noteController.text = truncated;
      _noteController.selection = TextSelection.fromPosition(
        TextPosition(offset: _noteController.text.length),
      );
      _cages[_selectedCageIndex].note = truncated;
    } else {
      _cages[_selectedCageIndex].note = text;
    }
    setState(() {});
  }

  void _submitToCart() {
    // Pastikan catatan pada bentuk aktif tersimpan
    _cages[_selectedCageIndex].note = _noteController.text;

    // Jika pengguna belum menentukan kuantitas, otomatis berikan kuantitas 1 pada bentuk yang dipilih
    if (_totalQuantity == 0) {
      _cages[_selectedCageIndex].quantity = 1;
    }

    // Filter bentuk-bentuk sangkar yang jumlah pesanan > 0
    final orderedCages = _cages.where((c) => c.quantity > 0).toList();

    // Buat daftar CartItem terpisah untuk setiap bentuk sangkar yang dipesan
    final List<CartItem> separateItems = orderedCages.map((cage) {
      String? finalNote = cage.note.trim().isNotEmpty ? cage.note.trim() : null;

      // Jika produk memiliki catatan desain/posisi ukir (customNote) dan belum ada di finalNote,
      // satukan menjadi 1 dengan catatan pesanan di keranjang
      if (widget.product.customNote != null &&
          widget.product.customNote!.trim().isNotEmpty) {
        final cNote = widget.product.customNote!.trim();
        if (finalNote == null) {
          finalNote = cNote;
        } else if (!finalNote.contains(cNote)) {
          finalNote = '$cNote | $finalNote';
        }
      }

      return CartItem(
        product: widget.product,
        quantity: cage.quantity,
        cageType: cage.name,
        note: finalNote,
      );
    }).toList();

    if (widget.onAddItemsToCart != null) {
      widget.onAddItemsToCart!(separateItems);
    } else if (widget.onAddCustomToCart != null) {
      for (final item in separateItems) {
        widget.onAddCustomToCart!(
          item.product,
          cageSummary: item.cageType,
          note: item.note,
          totalQuantity: item.quantity,
        );
      }
    } else if (widget.onAddToCart != null) {
      widget.onAddToCart!(widget.product);
    }

    final summaryText = separateItems
        .map((c) => '${c.cageType} (${c.quantity}x)')
        .join(', ');

    // Reset formulir pemesanan agar tidak meninggalkan jejak pesanan yang sudah masuk keranjang
    setState(() {
      for (final cage in _cages) {
        cage.quantity = 0;
        cage.note = '';
      }
      _noteController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.product.name} [$summaryText] berhasil ditambahkan terpisah ke keranjang!',
        ),
        backgroundColor: Colors.green.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: TopNavbar(
        cartItemCount: _currentCartCount,
        isLoggedIn: _isLoggedIn,
        isAdmin: _isAdmin,
        onCartTap: () {
          widget.onCartTap?.call();
          if (mounted) {
            setState(() {});
          }
        },
        onProfileTap: () {
          widget.onProfileTap?.call();
          if (mounted) setState(() {});
        },
        onLogout: () {
          widget.onLogout?.call();
          if (mounted) setState(() {});
        },
        onLogoTap: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 780;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Breadcrumb: Kembali / Detail Produk
                  _buildBreadcrumb(context),
                  const SizedBox(height: 20),

                  // 2. Konten Utama: 2 Kolom pada layar lebar, 1 Kolom pada layar sempit
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kolom Kiri: Gambar Utama Besar & Pilihan Sangkar dengan Quantity
                        Expanded(flex: 6, child: _buildLeftSection()),
                        const SizedBox(width: 36),
                        // Kolom Kanan: Nama Desain, Tombol Keranjang, dan Note Produk
                        Expanded(flex: 5, child: _buildRightSection()),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeftSection(),
                        const SizedBox(height: 28),
                        _buildRightSection(),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 1. Breadcrumb "Kembali / Detail Produk"
  Widget _buildBreadcrumb(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(4),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
            child: Text(
              'Kembali',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const Text('  /  ', style: TextStyle(color: Colors.grey, fontSize: 16)),
        const Text(
          'Detail Produk',
          style: TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  /// Kolom Kiri: Gambar Logo Paling Besar & Bentuk Sangkar (Bisa Digeser) + Quantity
  Widget _buildLeftSection() {
    final int totalSlides = 1 + _cages.length;
    final bool isLogoSlide = _currentSlideIndex == 0;
    final bool showNavButtons = (_cages.length + 1) > 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kotak Slider Foto Produk & Bentuk Sangkar (Slide 1: Logo, Slide 2 dst: Bentuk Sangkar)
        Container(
          width: double.infinity,
          height: 350,
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
                // 1. PageView Slider dengan dukungan Drag Mouse di Web/Desktop & Touch di HP
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
                    onPageChanged: (slideIdx) {
                      setState(() {
                        _currentSlideIndex = slideIdx;
                        if (slideIdx > 0 && slideIdx - 1 < _cages.length) {
                          final cageIdx = slideIdx - 1;
                          if (_selectedCageIndex != cageIdx) {
                            _cages[_selectedCageIndex].note = _noteController.text;
                            _selectedCageIndex = cageIdx;
                            _noteController.text = _cages[cageIdx].note;
                            _noteController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _noteController.text.length),
                            );
                          }
                        }
                      });
                      if (slideIdx > 0) {
                        _scrollCageThumbToVisible(slideIdx);
                      } else {
                        _scrollCageThumbToVisible(0);
                      }
                    },
                    itemBuilder: (context, index) {
                      final slideKey = ValueKey('detail_slide_${index}_${index == 0 ? widget.product.imageUrl : (_cages[index - 1].imageUrl ?? _cages[index - 1].imageBytes.hashCode)}');
                      if (index == 0) {
                        // Slide 1: Logo Produk
                        return _KeepAliveWrapper(
                          key: slideKey,
                          child: widget.product.imageUrl.isNotEmpty
                              ? Product.buildImageFromSource(
                                  widget.product.imageUrl,
                                  width: double.infinity,
                                  height: 350,
                                  fit: BoxFit.contain,
                                  placeholder: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image_rounded,
                                          size: 48,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          widget.product.name,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_outlined,
                                        size: 48,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.product.name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        );
                      } else {
                        // Slide 2 dst: Bentuk Sangkar
                        final cageIdx = index - 1;
                        final cage = _cages[cageIdx];
                        return _KeepAliveWrapper(
                          key: slideKey,
                          child: Builder(
                            builder: (context) {
                              if (cage.imageBytes != null && cage.imageBytes!.isNotEmpty) {
                                return Image.memory(
                                  cage.imageBytes!,
                                  width: double.infinity,
                                  height: 350,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                );
                              }
                              if (cage.imageUrl != null && cage.imageUrl!.isNotEmpty) {
                                return Product.buildImageFromSource(
                                  cage.imageUrl!,
                                  width: double.infinity,
                                  height: 350,
                                  fit: BoxFit.contain,
                                  placeholder: Center(
                                    child: Icon(Icons.grid_view_rounded, color: Colors.grey.shade600, size: 54),
                                  ),
                                );
                              }
                              final sc = CageService.instance.cages
                                  .where((c) => c.name.toLowerCase() == cage.name.toLowerCase() || c.id == cage.id)
                                  .firstOrNull;
                              if (sc != null && (sc.imageBytes != null || (sc.imageUrl != null && sc.imageUrl!.isNotEmpty))) {
                                return sc.buildImage(
                                  width: double.infinity,
                                  height: 350,
                                  fit: BoxFit.contain,
                                );
                              }
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.grid_view_rounded, color: Colors.grey.shade600, size: 54),
                                    const SizedBox(height: 8),
                                    Text(
                                      cage.name,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
                          '(${_currentSlideIndex + 1}/$totalSlides)',
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

                // 5. Dot Indicators di Tengah Bawah
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

        const SizedBox(height: 10),

        // Pilihan Bentuk Sangkar dengan Tombol Previous & Next (HANYA MUNCUL JIKA SANGKAR LEBIH DARI 4)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tombol Previous (<) hanya ada jika sangkar > 4
            if (showNavButtons) ...[
              InkWell(
                onTap: () {
                  if (_cageScrollController.hasClients) {
                    _cageScrollController.animateTo(
                      (_cageScrollController.offset - 120).clamp(
                        0.0,
                        _cageScrollController.position.maxScrollExtent,
                      ),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Daftar Bentuk Sangkar yang Dapat Digeser (Scrollable Horizontal)
            Expanded(
              child: SingleChildScrollView(
                controller: _cageScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    // Bentuk Sangkar
                    ...List.generate(_cages.length, (index) {
                      final cage = _cages[index];
                      final isSelected = _currentSlideIndex == index + 1;

                      return Container(
                        width: 114,
                        margin: const EdgeInsets.symmetric(horizontal: 5.0),
                        child: Column(
                          children: [
                            // Pilihan Bentuk Sangkar (Thumbnail + Nama)
                            InkWell(
                              onTap: () => _selectCage(index),
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: 102,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF6E7173)
                                          : const Color(0xFFB5B7B9),
                                      borderRadius: BorderRadius.circular(16),
                                      border: isSelected
                                          ? Border.all(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              width: 2.5,
                                            )
                                          : null,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Center(
                                          child: Builder(
                                            builder: (context) {
                                              if (cage.imageBytes != null && cage.imageBytes!.isNotEmpty) {
                                                return ClipRRect(
                                                  borderRadius: BorderRadius.circular(14),
                                                  child: Image.memory(
                                                    cage.imageBytes!,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                );
                                              }
                                              if (cage.imageUrl != null && cage.imageUrl!.isNotEmpty) {
                                                return ClipRRect(
                                                  borderRadius: BorderRadius.circular(14),
                                                  child: Product.buildImageFromSource(
                                                    cage.imageUrl!,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                    placeholder: const Center(
                                                      child: Icon(Icons.grid_view_rounded, color: Colors.white70, size: 36),
                                                    ),
                                                  ),
                                                );
                                              }
                                              final sc = CageService.instance.cages
                                                  .where((c) => c.name.toLowerCase() == cage.name.toLowerCase() || c.id == cage.id)
                                                  .firstOrNull;
                                              if (sc != null && (sc.imageBytes != null || (sc.imageUrl != null && sc.imageUrl!.isNotEmpty))) {
                                                return ClipRRect(
                                                  borderRadius: BorderRadius.circular(14),
                                                  child: sc.buildImage(
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                );
                                              }
                                              return Icon(
                                                Icons.grid_view_rounded,
                                                color: isSelected ? Colors.white : Colors.white70,
                                                size: 36,
                                              );
                                            },
                                          ),
                                        ),
                                        if (cage.note.trim().isNotEmpty)
                                          Positioned(
                                            top: 5,
                                            left: 5,
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: const BoxDecoration(
                                                color: Colors.amber,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.edit_note,
                                                size: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        // Tombol Ganti Foto Khusus Admin untuk varian ini pada produk ini
                                        if (_isAdmin)
                                          Positioned(
                                            top: 5,
                                            right: 5,
                                            child: Tooltip(
                                              message: 'Ganti foto ${cage.name} untuk produk ini',
                                              child: InkWell(
                                                onTap: () => _changeCageImageForProduct(index),
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.65),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.camera_alt_rounded,
                                                    size: 13,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cage.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.black87
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Counter Quantity (+ [ 0 ] -)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Tombol Tambah (+)
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      cage.quantity++;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade400,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),

                                // Kotak Angka Quantity
                                Container(
                                  width: 28,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${cage.quantity}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),

                                // Tombol Kurang (-)
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (cage.quantity > 0) cage.quantity--;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade400,
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Tombol Next (>) hanya ada jika sangkar > 4
            if (showNavButtons) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  if (_cageScrollController.hasClients) {
                    _cageScrollController.animateTo(
                      (_cageScrollController.offset + 120).clamp(
                        0.0,
                        _cageScrollController.position.maxScrollExtent,
                      ),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Kolom Kanan: Nama Desain Logo, Tombol Keranjang, dan Note Produk
  Widget _buildRightSection() {
    final selectedCage = _cages[_selectedCageIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nama Desain Logo
        Text(
          widget.product.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 14),

        // Tombol Keranjang untuk Memesan
        OutlinedButton(
          onPressed: _submitToCart,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            side: BorderSide(color: Colors.grey.shade500, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Keranjang',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),

        const SizedBox(height: 18),

        // Garis Pembatas
        Divider(color: Colors.grey.shade300, thickness: 1),

        const SizedBox(height: 12),

        // Judul Catatan Produk yang Dinamis Sesuai Bentuk Sangkar yang Dipilih
        Text(
          'Catatan ${selectedCage.name}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 12),

        // Kotak Input Note Produk
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3F5),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _noteController,
                maxLength: 100,
                buildCounter:
                    (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                maxLines: 7,
                minLines: 5,
                onChanged: _handleNoteChanged,
                decoration: InputDecoration(
                  hintText:
                      'Tambahkan catatan khusus untuk ${selectedCage.name} (contoh: ukiran tokoh, motif, finishing warna)...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),

              const SizedBox(height: 8),

              // Indikator Maksimal 100 Huruf
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '$_charCount / 100',
                  style: TextStyle(
                    fontSize: 13,
                    color: _charCount >= 100
                        ? Colors.red
                        : Colors.grey.shade600,
                    fontWeight: _charCount >= 100
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
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
