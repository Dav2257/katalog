import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/user_service.dart';
import 'admin_dashboard_page.dart';
import 'admin_order_detail_page.dart';

/// Item dalam riwayat pesanan
class CompletedOrderItem {
  final String code;
  final String title;
  final String cage;
  final String note;
  final int quantity;
  final String? imageUrl;

  const CompletedOrderItem({
    required this.code,
    required this.title,
    required this.cage,
    required this.note,
    required this.quantity,
    this.imageUrl,
  });
}

/// Halaman Detail Riwayat Pesanan untuk Admin
/// Menampilkan breadcrumb Kembali / Detail Pesanan,
/// Nomor Pemesanan & Tanggal Pemesanan,
/// Tombol WhatsApp Hubungi (dengan logo WhatsApp asli),
/// Daftar produk dalam riwayat pesanan (Thumbnail Abu-Abu dengan Kode, Judul, Bentuk Sangkar, Note, Kuantitas),
/// dan Status [ Diterima ] beserta Tanggal Diterima.
class AdminCompletedOrderDetailPage extends StatefulWidget {
  final AdminCompletedOrder order;

  const AdminCompletedOrderDetailPage({
    super.key,
    required this.order,
  });

  @override
  State<AdminCompletedOrderDetailPage> createState() =>
      _AdminCompletedOrderDetailPageState();
}

class _AdminCompletedOrderDetailPageState
    extends State<AdminCompletedOrderDetailPage> {
  late List<CompletedOrderItem> _items;
  late String _completedDate;

  @override
  void initState() {
    super.initState();
    _initItemsAndDate();
  }

  String? _resolveProductImage(String productName, String phone, String email) {
    final pName = productName.trim().toLowerCase();

    // 1. Cek dari produk custom user di UserService (khususnya user pemesan)
    final allUsers = UserService.instance.users;
    final cleanPhone = phone.trim();
    final cleanEmail = email.trim().toLowerCase();

    for (final u in allUsers) {
      final matchUser = (cleanPhone.isNotEmpty && u.phone.trim() == cleanPhone) ||
          (cleanEmail.isNotEmpty && u.email.trim().toLowerCase() == cleanEmail);
      if (matchUser) {
        for (final p in u.customProducts) {
          if (p.name.trim().toLowerCase() == pName && p.imageUrl.trim().isNotEmpty) {
            return p.imageUrl.trim();
          }
        }
      }
    }

    // 2. Cek ke semua custom product di semua user jika belum ketemu
    for (final u in allUsers) {
      for (final p in u.customProducts) {
        if (p.name.trim().toLowerCase() == pName && p.imageUrl.trim().isNotEmpty) {
          return p.imageUrl.trim();
        }
      }
    }

    // 3. Cek katalog produk umum di ProductService
    for (final p in ProductService.instance.products) {
      if ((p.name.trim().toLowerCase() == pName ||
              (p.code != null && p.code!.trim().toLowerCase() == pName)) &&
          p.imageUrl.trim().isNotEmpty) {
        return p.imageUrl.trim();
      }
    }

    // 4. Cek adminProducts di ProductService
    for (final p in ProductService.instance.adminProducts) {
      if ((p.name.trim().toLowerCase() == pName ||
              p.code.trim().toLowerCase() == pName) &&
          p.imageUrl.trim().isNotEmpty) {
        return p.imageUrl.trim();
      }
    }

    return null;
  }

  void _initItemsAndDate() {
    _completedDate = _calculateCompletedDate(widget.order.date);

    final productCode =
        widget.order.productCode.isNotEmpty ? widget.order.productCode : 'PROD';
    final codes = productCode.split(',').map((c) => c.trim()).toList();

    // Cari UserOrder matching untuk mendapatkan imageUrl jika ada
    final allUserOrders = OrderService.instance.allOrders;
    UserOrder? matchingOrder;
    if (widget.order.orderId != null && widget.order.orderId!.isNotEmpty) {
      for (final o in allUserOrders) {
        if (o.id == widget.order.orderId) {
          matchingOrder = o;
          break;
        }
      }
    }
    if (matchingOrder == null && widget.order.phone.isNotEmpty) {
      for (final o in allUserOrders) {
        if (o.phone == widget.order.phone) {
          matchingOrder = o;
          break;
        }
      }
    }

    final orderImg = (widget.order.imageUrl != null && widget.order.imageUrl!.trim().isNotEmpty)
        ? widget.order.imageUrl!.trim()
        : (matchingOrder?.imageUrl != null && matchingOrder!.imageUrl!.trim().isNotEmpty
            ? matchingOrder.imageUrl!.trim()
            : null);

    if (codes.length > 1) {
      _items = [];
      for (int i = 0; i < codes.length; i++) {
        final c = codes[i];
        final itemImg = orderImg ?? _resolveProductImage(c, widget.order.phone, widget.order.email);
        _items.add(
          CompletedOrderItem(
            code: c,
            title: '$c-Produk Pilihan ${i + 1}',
            cage: widget.order.cageType.isNotEmpty
                ? widget.order.cageType
                : 'Sangkar Jati',
            note: widget.order.note.isNotEmpty && i == 0
                ? widget.order.note
                : 'Tidak ada',
            quantity: (widget.order.quantity / codes.length).ceil().clamp(1, 99),
            imageUrl: itemImg,
          ),
        );
      }
    } else {
      final itemTitle = widget.order.customerName.isNotEmpty
          ? '$productCode-${widget.order.customerName}'
          : '$productCode-Produk Sangkar';
      final itemImg = orderImg ??
          _resolveProductImage(
            matchingOrder?.productName ?? productCode,
            widget.order.phone,
            widget.order.email,
          );

      _items = [
        CompletedOrderItem(
          code: productCode,
          title: itemTitle,
          cage: widget.order.cageType.isNotEmpty
              ? widget.order.cageType
              : 'Sangkar Jati',
          note: widget.order.note.isNotEmpty
              ? widget.order.note
              : 'Tidak ada',
          quantity: widget.order.quantity,
          imageUrl: itemImg,
        ),
      ];
    }
  }

  String _calculateCompletedDate(String orderDate) {
    try {
      final parts = orderDate.split('-');
      if (parts.length == 3) {
        final d = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        final dt = DateTime(y, m, d).add(const Duration(days: 1));
        return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
      }
    } catch (_) {}
    return orderDate;
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('62')) {
      cleanPhone = '62$cleanPhone';
    }

    final url = Uri.parse(
      'https://wa.me/$cleanPhone?text=Halo%20kami%20dari%20Admin%20Katalog%20Sangkar%20mengenai%20riwayat%20pesanan%20Anda.',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membuka chat WhatsApp ke +$cleanPhone...'),
          backgroundColor: const Color(0xFF25D366),
        ),
      );
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
                  // Avatar Akun Admin di Kanan Atas
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
            horizontal: MediaQuery.of(context).size.width < 600 ? 16.0 : 40.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Breadcrumb: Kembali / Detail Pesanan
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
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF888888),
                    ),
                  ),
                  const Text(
                    'Detail Pesanan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6E6E6E),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 2. Baris Info Pemesan & Tombol Hubungi WhatsApp
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pemesanan: ${widget.order.phone}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tanggal Pemesanan: ${widget.order.date}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),

                  // Tombol Hijau Hubungi dengan Logo WhatsApp Asli
                  ElevatedButton(
                    key: const ValueKey('whatsapp_hubungi_btn'),
                    onPressed: () => _openWhatsApp(widget.order.phone),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43B724), // Hijau terang WhatsApp
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WhatsAppIcon(size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Hubungi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 3. Daftar Produk dalam Riwayat Pesanan
              Column(
                children: _items.map((item) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Kotak Abu-Abu Thumbnail Gambar Logo Pesanan Pelanggan
                            GestureDetector(
                              onTap: () {
                                final img = item.imageUrl?.trim() ?? '';
                                if (img.isNotEmpty) {
                                  _showImagePreviewDialog(context, item.title, img);
                                }
                              },
                              child: Container(
                                width: 104,
                                height: 94,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFA6A6A6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _buildItemImage(item),
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Detail Info Produk
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.cage,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Note :   ${item.note}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF444444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Kuantitas (2x / 1x)
                            Text(
                              '${item.quantity}x',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF444444),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFD6D6D6),
                      ),
                    ],
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // 4. Status : [ Diterima ]   Tanggal Diterima: 11-09-2026
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  const Text(
                    'Status :',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF444444),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF9E9E9E),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      widget.order.status.isNotEmpty
                          ? widget.order.status
                          : 'Diterima',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                  ),
                  Text(
                    'Tanggal Diterima: $_completedDate',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF777777),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemImage(CompletedOrderItem item) {
    final imgUrl = item.imageUrl?.trim() ?? '';

    if (imgUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Product.buildImageFromSource(
            imgUrl,
            width: 104,
            height: 94,
            fit: BoxFit.cover,
            placeholder: const Center(
              child: Icon(Icons.image_outlined, color: Colors.white70, size: 32),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 28, color: Color(0xFF555555)),
          const SizedBox(height: 3),
          Text(
            item.code,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6E6E6E),
            ),
          ),
        ],
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Logo Pesanan: $title',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 380, maxWidth: 380),
                      color: const Color(0xFFF0F0F0),
                      child: InteractiveViewer(
                        child: Product.buildImageFromSource(
                          imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pinch atau geser untuk memperbesar logo',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFEEEEEE),
                  child: Icon(Icons.close, size: 16, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
