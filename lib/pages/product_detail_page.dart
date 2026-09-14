import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/cage_service.dart';
import '../services/auth_service.dart';
import '../widgets/top_navbar.dart';

class CageOption {
  final String id;
  final String name;
  int quantity;
  String note;

  CageOption({
    required this.id,
    required this.name,
    this.quantity = 0,
    this.note = '',
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
  final VoidCallback? onSwitchRole;

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
    this.onSwitchRole,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _selectedCageIndex = 0;
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _cageScrollController = ScrollController();

  final List<CageOption> _cages = [];

  @override
  void initState() {
    super.initState();
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
  }

  void _loadCagesFromService() {
    final Map<String, CageOption> existing = {for (final c in _cages) c.id: c};

    final List<CageOption> updated = [];

    if (widget.product.cageVariations != null &&
        widget.product.cageVariations!.isNotEmpty) {
      for (final cv in widget.product.cageVariations!) {
        if (existing.containsKey(cv.id)) {
          final prev = existing[cv.id]!;
          updated.add(
            CageOption(
              id: cv.id,
              name: cv.name,
              quantity: prev.quantity,
              note: prev.note,
            ),
          );
        } else {
          updated.add(
            CageOption(id: cv.id, name: cv.name, quantity: 0, note: ''),
          );
        }
      }
    } else {
      final serviceCages = CageService.instance.cages;
      for (final sc in serviceCages) {
        if (existing.containsKey(sc.id)) {
          final prev = existing[sc.id]!;
          updated.add(
            CageOption(
              id: sc.id,
              name: sc.name,
              quantity: prev.quantity,
              note: prev.note,
            ),
          );
        } else {
          updated.add(
            CageOption(id: sc.id, name: sc.name, quantity: 0, note: ''),
          );
        }
      }
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
    });
  }

  void _addCageByAdmin() {
    final added = CageService.instance.addCage();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_cageScrollController.hasClients) {
        _cageScrollController.animateTo(
          _cageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bentuk ${added.name} berhasil ditambahkan oleh Admin!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _confirmRemoveCage(CageOption cage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Varian Sangkar'),
        content: Text('Apakah Anda yakin ingin menghapus "${cage.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              CageService.instance.removeCage(cage.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Varian "${cage.name}" berhasil dihapus.'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_handleAuthUpdate);
    CageService.instance.removeListener(_handleCageServiceUpdate);
    _noteController.dispose();
    _cageScrollController.dispose();
    super.dispose();
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
    if (_selectedCageIndex == index) return;
    // Simpan catatan bentuk yang sedang aktif
    _cages[_selectedCageIndex].note = _noteController.text;

    setState(() {
      _selectedCageIndex = index;
      // Muat catatan khusus bentuk yang baru dipilih
      _noteController.text = _cages[index].note;
      _noteController.selection = TextSelection.fromPosition(
        TextPosition(offset: _noteController.text.length),
      );
    });
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
        onSwitchRole: () {
          widget.onSwitchRole?.call();
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

  /// Kolom Kiri: Gambar Logo Paling Besar & Bentuk Sangkar + Quantity
  Widget _buildLeftSection() {
    final selectedCage = _cages[_selectedCageIndex];
    final bool showNavButtons = _cages.length > 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gambar Utama Logo / Desain Sangkar Paling Besar
        Container(
          width: double.infinity,
          height: 320,
          decoration: BoxDecoration(
            color: const Color(0xFFC4C4C4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: widget.product.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.product.imageUrl,
                    width: double.infinity,
                    height: 320,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
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
                      const SizedBox(height: 4),
                      Text(
                        selectedCage.name,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 13,
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
                    ...List.generate(_cages.length, (index) {
                      final cage = _cages[index];
                      final isSelected = _selectedCageIndex == index;

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
                                              final sc = CageService
                                                  .instance
                                                  .cages
                                                  .where(
                                                    (c) =>
                                                        c.name.toLowerCase() ==
                                                            cage.name
                                                                .toLowerCase() ||
                                                        c.id == cage.id,
                                                  )
                                                  .firstOrNull;
                                              if (sc != null &&
                                                  (sc.imageBytes != null ||
                                                      (sc.imageUrl != null &&
                                                          sc
                                                              .imageUrl!
                                                              .isNotEmpty))) {
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: sc.buildImage(
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                );
                                              }
                                              return Icon(
                                                Icons.grid_view_rounded,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.white70,
                                                size: 36,
                                              );
                                            },
                                          ),
                                        ),
                                        if (cage.note.trim().isNotEmpty)
                                          Positioned(
                                            top: 5,
                                            right: 5,
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
                                        // Tombol Hapus Bentuk Sangkar Khusus Admin untuk varian tambahan
                                        if (_isAdmin && _cages.length > 4)
                                          Positioned(
                                            top: 3,
                                            left: 3,
                                            child: InkWell(
                                              onTap: () =>
                                                  _confirmRemoveCage(cage),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade600,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 11,
                                                  color: Colors.white,
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

                    // Tombol Tambah Bentuk HANYA UNTUK ADMIN (User Login & Umum TIDAK BISA LIHAT)
                    if (_isAdmin)
                      Container(
                        width: 114,
                        margin: const EdgeInsets.symmetric(horizontal: 5.0),
                        child: InkWell(
                          onTap: _addCageByAdmin,
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              Container(
                                height: 102,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                    width: 1.2,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.add_circle_outline_rounded,
                                    size: 36,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '+ Tambah',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
