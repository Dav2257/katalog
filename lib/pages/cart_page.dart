import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';

class CartPage extends StatefulWidget {
  final List<CartItem> cartItems;
  final void Function(CartItem item, int newQuantity) onUpdateQuantity;
  final void Function(CartItem item) onRemoveItem;
  final VoidCallback onClearCart;
  final void Function(CartItem item, String newNote)? onUpdateNote;

  const CartPage({
    super.key,
    required this.cartItems,
    required this.onUpdateQuantity,
    required this.onRemoveItem,
    required this.onClearCart,
    this.onUpdateNote,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<CartItem> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    OrderService.instance.addListener(_onOrdersChanged);
    AuthService.instance.addListener(_onOrdersChanged);
  }

  @override
  void dispose() {
    OrderService.instance.removeListener(_onOrdersChanged);
    AuthService.instance.removeListener(_onOrdersChanged);
    super.dispose();
  }

  void _onOrdersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant CartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedItems.removeWhere((item) => !widget.cartItems.contains(item));
  }

  bool get _isAllSelected =>
      widget.cartItems.isNotEmpty && _selectedItems.length == widget.cartItems.length;

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedItems.clear();
      } else {
        _selectedItems.addAll(widget.cartItems);
      }
    });
  }

  void _toggleItem(CartItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  void _updateQuantity(CartItem item, int newQuantity) {
    setState(() {
      item.quantity = newQuantity;
    });
    widget.onUpdateQuantity(item, newQuantity);
  }

  void _removeItem(CartItem item) {
    final itemName = item.product.name;
    final itemCage = item.cageType != null ? ' (${item.cageType})' : '';
    setState(() {
      _selectedItems.remove(item);
      widget.cartItems.remove(item);
    });
    widget.onRemoveItem(item);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$itemName$itemCage telah dihapus dari keranjang.'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEditNoteDialog(CartItem item) {
    final controller = TextEditingController(text: item.note ?? '');

    int wordCount(String text) {
      final t = text.trim();
      return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final count = wordCount(controller.text);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: const [
                  Icon(Icons.edit_note_rounded, color: Colors.black87),
                  SizedBox(width: 8),
                  Text(
                    'Edit Catatan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.product.name}${item.cageType != null ? ' - ${item.cageType}' : ''}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: TextField(
                      controller: controller,
                      maxLines: 4,
                      minLines: 2,
                      onChanged: (val) {
                        final words = val.trim().split(RegExp(r'\s+'));
                        if (words.length > 100 && val.endsWith(' ')) {
                          controller.text = words.take(100).join(' ');
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length),
                          );
                        }
                        setDialogState(() {});
                      },
                      decoration: const InputDecoration(
                        hintText: 'Tuliskan catatan khusus...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '$count / 100',
                      style: TextStyle(
                        fontSize: 11,
                        color: count >= 100 ? Colors.red : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newNote = controller.text.trim();
                    setState(() {
                      item.note = newNote.isNotEmpty ? newNote : null;
                    });
                    if (widget.onUpdateNote != null) {
                      widget.onUpdateNote!(item, newNote);
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Catatan pesanan berhasil diperbarui.'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleCheckout() {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan centang minimal satu produk yang ingin dipesan.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final selectedList = _selectedItems.toList();
    final phoneController = TextEditingController(
      text: AuthService.instance.userPhone.trim().isNotEmpty
          ? AuthService.instance.userPhone.trim()
          : (AuthService.instance.userEmail.trim().isNotEmpty
              ? AuthService.instance.userEmail.trim()
              : '085113123142'),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            WhatsAppLogo(size: 24),
            SizedBox(width: 8),
            Text('Konfirmasi Pesanan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anda akan memesan ${selectedList.length} produk terpilih via WhatsApp:',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ...selectedList.map(
                (it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 42,
                          height: 42,
                          color: const Color(0xFF6E7173),
                          child: Product.buildImageFromSource(
                            it.product.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: const Icon(Icons.image_not_supported, size: 18, color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${it.product.name} [${it.cageType ?? 'Bentuk Sangkar'}] x${it.quantity}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            if (it.note != null && it.note!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  'Catatan: "${it.note}"',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nomor Telepon / WhatsApp Pemesan:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Contoh: 08123456789',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  prefixIcon: const Icon(Icons.phone, size: 18),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final inputVal = phoneController.text.trim();
              final customerPhone = inputVal.isNotEmpty
                  ? inputVal
                  : (AuthService.instance.userPhone.trim().isNotEmpty
                      ? AuthService.instance.userPhone.trim()
                      : (AuthService.instance.userEmail.trim().isNotEmpty
                          ? AuthService.instance.userEmail.trim()
                          : '085113123142'));
              final customerEmail = AuthService.instance.userEmail.trim();

              final orderCode = 'JTM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
              final itemsToRemove = selectedList.toList();

              bool hasUploadedCustomPhoto = false;
              bool hasUploadedToCloud = false;
              final List<String> itemDescriptions = [];

              for (final it in itemsToRemove) {
                final cageStr = it.cageType != null ? ' [${it.cageType}]' : '';
                final noteStr = (it.note != null && it.note!.trim().isNotEmpty) ? '\n   Catatan: ${it.note}' : '';

                // Gunakan URL foto logo produk utama
                String imgUrl = it.product.imageUrl.trim();
                if (imgUrl.isEmpty && it.cageType != null && it.product.cageVariations != null) {
                  for (final v in it.product.cageVariations!) {
                    if (v.name.trim().toLowerCase() == it.cageType!.trim().toLowerCase() &&
                        v.imageUrl.trim().isNotEmpty) {
                      imgUrl = v.imageUrl.trim();
                      break;
                    }
                  }
                }

                String imgStr = '';
                if (imgUrl.isNotEmpty) {
                  if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
                    imgStr = '\n   📸 Foto Desain: $imgUrl';
                  } else {
                    hasUploadedCustomPhoto = true;
                    // Unggah ke Supabase Storage (bucket 'katalog')
                    String? uploadedPublicUrl;
                    try {
                      uploadedPublicUrl = await StorageService.instance.uploadImageIfPossible(imgUrl);
                    } catch (_) {}

                    if (uploadedPublicUrl != null && uploadedPublicUrl.isNotEmpty) {
                      hasUploadedToCloud = true;
                      imgUrl = uploadedPublicUrl;
                      imgStr = '\n   📸 Foto Desain: $uploadedPublicUrl';
                    } else {
                      // Tersimpan di database Supabase tabel pesanan & terbaca di Dashboard Admin
                      imgStr = '\n   📸 Foto Desain: [Foto Custom telah tersimpan di Pesanan Dashboard Admin: #$orderCode]\n   (Mohon lampirkan juga file foto desain ini langsung di chat WA ini)';
                    }
                  }
                }

                // Catat ke pesanan di Supabase
                OrderService.instance.addOrder(
                  UserOrder(
                    id: orderCode,
                    productName: it.product.name,
                    quantity: it.quantity,
                    cageTypeOrDesign: it.cageType != null ? 'Design ${it.cageType}' : 'Design 1 bentuk 1',
                    note: (it.note != null && it.note!.trim().isNotEmpty)
                        ? it.note!
                        : 'Pesanan diproses via WhatsApp',
                    status: 'Tahap 1',
                    currentStep: 1,
                    imageUrl: imgUrl,
                    phone: customerPhone,
                    email: customerEmail,
                  ),
                );

                itemDescriptions.add('${it.product.name}$cageStr x${it.quantity}$imgStr$noteStr');
              }

              setState(() {
                for (final it in itemsToRemove) {
                  widget.cartItems.remove(it);
                }
                _selectedItems.clear();
              });
              for (final it in itemsToRemove) {
                widget.onRemoveItem(it);
              }

              final waUri = AppSettingsService.instance.createOrderWhatsAppUri(
                customerPhone: customerPhone,
                itemDescriptions: itemDescriptions,
                orderCode: orderCode,
              );
              _launchWhatsApp(waUri);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    hasUploadedToCloud
                        ? 'Pesanan #$orderCode dibuat! Foto desain otomatis terlampir di WhatsApp & tersimpan di sistem.'
                        : (hasUploadedCustomPhoto
                            ? 'Pesanan #$orderCode dibuat! Foto tersimpan di database admin. WhatsApp dibuka.'
                            : 'Pesanan #$orderCode diarahkan ke WhatsApp Admin (${AppSettingsService.instance.adminWhatsApp})!'),
                  ),
                  duration: const Duration(seconds: 4),
                  backgroundColor: const Color(0xFF43A047),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43A047),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim Pesanan'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchWhatsApp(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 2,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4A301E),
                Color(0xFF382314),
                Color(0xFF2C190E),
                Color(0xFF482E1C),
                Color(0xFF5A3922),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Keranjang Belanja',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (widget.cartItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.cartItems.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          // Tombol Hapus Semua hanya muncul ketika checkbox dicentang!
          if (_selectedItems.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Produk?'),
                    content: Text(
                      _selectedItems.length == widget.cartItems.length
                          ? 'Semua produk di keranjang belanja akan dihapus.'
                          : '${_selectedItems.length} produk yang dicentang akan dihapus dari keranjang.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          final itemsToDelete = _selectedItems.toList();
                          setState(() {
                            for (final item in itemsToDelete) {
                              widget.cartItems.remove(item);
                            }
                            _selectedItems.clear();
                          });
                          for (final item in itemsToDelete) {
                            widget.onRemoveItem(item);
                          }
                        },
                        child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                'Hapus Semua',
                style: TextStyle(color: Color(0xFFFFAB91), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.cartItems.isEmpty) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Keranjang Belanja Masih Kosong',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Yuk jelajahi katalog dan temukan produk favorit Anda!',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Mulai Belanja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // 1. Pilih Semua Checkbox di Kanan Atas Sesuai Gambar 3
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: _toggleSelectAll,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Pilih semua',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _isAllSelected ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: _isAllSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Daftar Produk di Keranjang
              ...widget.cartItems.map((item) {
                final isSelected = _selectedItems.contains(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Checkbox di Sebelah Kiri untuk Setiap Produk
                      InkWell(
                        onTap: () => _toggleItem(item),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                      ),

                      // Kartu Produk Abu-abu dengan Garis Biru saat Terpilih
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDEDED),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF0088FF), width: 1.5)
                                : Border.all(color: Colors.transparent, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Baris Atas: Thumbnail, Nama, Subtitle, & Kontrol (+ [ 1 ] - 🗑)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Thumbnail Produk
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: 64,
                                      height: 48,
                                      color: const Color(0xFF6E7173),
                                      child: Product.buildImageFromSource(
                                        item.product.imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: const Center(
                                          child: Icon(Icons.inventory_2_outlined,
                                              color: Colors.white70, size: 22),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Nama Produk & Subtitle Bentuk
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF424242),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.cageType != null
                                              ? 'Bentuk: ${item.cageType}'
                                              : 'Bentuk Sangkar',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF757575),
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Kontrol Kuantitas (+ [ 1 ] -) dan Hapus
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Tombol Tambah (+) dengan area sentuh luas
                                      InkWell(
                                        onTap: () => _updateQuantity(
                                            item, item.quantity + 1),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF9E9E9E),
                                            ),
                                            child: const Icon(Icons.add,
                                                size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),

                                      // Kotak Angka Kuantitas
                                      Container(
                                        width: 32,
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                              color: const Color(0xFFBDBDBD), width: 1),
                                        ),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),

                                      // Tombol Kurang (-)
                                      InkWell(
                                        onTap: () {
                                          if (item.quantity > 1) {
                                            _updateQuantity(
                                                item, item.quantity - 1);
                                          } else {
                                            _removeItem(item);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF9E9E9E),
                                            ),
                                            child: const Icon(Icons.remove,
                                                size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Ikon Sampah yang Sangat Responsif & Mudah Ditekan
                                      Tooltip(
                                        message: 'Hapus produk',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _removeItem(item),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFEBEE),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.delete_rounded,
                                                size: 20,
                                                color: Color(0xFFD32F2F),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Baris Catatan (Note) dengan Tombol Edit Catatan
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Catatan :   ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF555555),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item.note != null && item.note!.trim().isNotEmpty
                                          ? item.note!
                                          : 'Belum ada catatan...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: item.note != null &&
                                                item.note!.trim().isNotEmpty
                                            ? const Color(0xFF424242)
                                            : Colors.grey.shade500,
                                        fontStyle: item.note != null &&
                                                item.note!.trim().isNotEmpty
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Tombol Edit Catatan
                                  InkWell(
                                    onTap: () => _showEditNoteDialog(item),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: const Color(0xFFBDBDBD), width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.edit_note_rounded,
                                              size: 14, color: Colors.black87),
                                          SizedBox(width: 3),
                                          Text(
                                            'Edit Catatan',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // 3. Tombol "Pesan" Hijau dengan Logo WhatsApp Resmi di Bawah Kanan
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _handleCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      // Logo WhatsApp Resmi
                      WhatsAppLogo(size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Pesan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // 4. Section Pesanan Anda untuk pengecekan proses pengerjaan pesanan
            _buildOrdersSection(),
          ],
        ),
      ),
    );
  }

  /// Membangun bagian "Pesanan Anda" dengan garis pemisah atas (hanya untuk user yang login)
  Widget _buildOrdersSection() {
    // User umum tidak ada bagian "Pesanan Anda" di keranjang
    if (!AuthService.instance.isLoggedIn) {
      return const SizedBox.shrink();
    }

    final orders = OrderService.instance.orders;
    if (orders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Divider(color: Colors.grey.shade400, thickness: 1, height: 1),
        const SizedBox(height: 18),
        const Text(
          'Pesanan Anda',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF616161),
          ),
        ),
        const SizedBox(height: 12),
        ...orders.map((order) => _buildOrderCard(order)),
      ],
    );
  }

  /// Membangun kartu pesanan abu-abu identik dengan gambar yang diberikan user
  Widget _buildOrderCard(UserOrder order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar / Kotak Abu-abu
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 64,
                  height: 48,
                  color: const Color(0xFF6E7173),
                  child: Product.buildImageFromSource(
                    order.imageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: const Center(
                      child: Icon(Icons.inventory_2_outlined,
                          color: Colors.white70, size: 22),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Nama Produk & Subtitle Desain / Bentuk
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${order.quantity}x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF424242),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.cageTypeOrDesign,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Status: [ Tahap 1 ]
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Status: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF616161),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFBDBDBD), width: 1),
                    ),
                    child: Text(
                      order.status,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Baris Catatan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Catatan :   ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF555555),
                ),
              ),
              Expanded(
                child: Text(
                  order.note.isNotEmpty ? order.note : 'Tidak ada catatan',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF424242),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const String _kWhatsAppBase64 =
    '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';

final Uint8List _whatsAppImageBytes = base64Decode(_kWhatsAppBase64);

/// Logo WhatsApp Resmi
class WhatsAppLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const WhatsAppLogo({super.key, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      _whatsAppImageBytes,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}


