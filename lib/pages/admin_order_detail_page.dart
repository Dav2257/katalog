import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/user_service.dart';
import 'admin_dashboard_page.dart';

/// Ikon Logo WhatsApp Khas & Presisi
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppIcon({super.key, this.size = 18, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _WhatsAppBubblePainter(color: color),
          ),
          Transform.translate(
            offset: Offset(size * 0.04, -size * 0.04),
            child: Transform.rotate(
              angle: -0.4,
              child: Icon(
                Icons.phone,
                size: size * 0.54,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppBubblePainter extends CustomPainter {
  final Color color;

  _WhatsAppBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final radius = w * 0.40;
    final center = Offset(w * 0.52, h * 0.48);

    final path = Path();
    path.addArc(
      Rect.fromCircle(center: center, radius: radius),
      0.85,
      4.95,
    );
    path.lineTo(w * 0.12, h * 0.88);
    path.lineTo(w * 0.32, h * 0.78);

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _WhatsAppBubblePainter oldDelegate) =>
      color != oldDelegate.color;
}

/// Halaman Detail Pesanan Masuk untuk Admin
/// Menampilkan info pemesan (nomor HP & tanggal), tombol Hubungi WhatsApp,
/// daftar produk dalam pesanan, pengaturan status progres (Tahap 1, 2, 3, Finishing, Diterima, serta tambah & hapus tahap),
/// dan tombol Simpan.
class AdminOrderDetailPage extends StatefulWidget {
  final AdminIncomingOrder order;

  const AdminOrderDetailPage({super.key, required this.order});

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _OrderItemDetail {
  final String id;
  final String productCode;
  final String productName;
  final String cageType;
  final String note;
  final int quantity;
  String selectedStatus;
  List<String> stages;
  final String? imageUrl;

  _OrderItemDetail({
    required this.id,
    required this.productCode,
    required this.productName,
    required this.cageType,
    required this.note,
    required this.quantity,
    required this.selectedStatus,
    List<String>? stages,
    this.imageUrl,
  }) : stages = stages ?? ['Tahap 1', 'Tahap 2', 'Tahap 3', 'Finishing', 'Diterima'];
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  late List<_OrderItemDetail> _items;

  @override
  void initState() {
    super.initState();
    _initItems();
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

  void _initItems() {
    final allUserOrders = OrderService.instance.allOrders;
    List<UserOrder> matchingOrders = [];
    if (widget.order.orderId.isNotEmpty) {
      matchingOrders = allUserOrders.where((o) => o.id == widget.order.orderId).toList();
    }
    if (matchingOrders.isEmpty) {
      matchingOrders = allUserOrders.where((o) => o.phone == widget.order.phone).toList();
    }

    if (matchingOrders.isNotEmpty) {
      _items = matchingOrders.map((o) {
        final codeMatch = RegExp(r'^([A-Za-z0-9]+)').firstMatch(o.productName.trim());
        final code = (codeMatch != null && codeMatch.group(1)!.length <= 6)
            ? codeMatch.group(1)!
            : (widget.order.productCode.isNotEmpty ? widget.order.productCode : 'PROD');

        String? img = (o.imageUrl != null && o.imageUrl!.trim().isNotEmpty)
            ? o.imageUrl!.trim()
            : _resolveProductImage(o.productName, o.phone, o.email);

        return _OrderItemDetail(
          id: o.id,
          productCode: code,
          productName: o.productName,
          cageType: o.cageTypeOrDesign,
          note: o.note,
          quantity: o.quantity,
          selectedStatus: o.status,
          imageUrl: img,
        );
      }).toList();
    } else {
      String? img = (widget.order.imageUrl != null && widget.order.imageUrl!.trim().isNotEmpty)
          ? widget.order.imageUrl!.trim()
          : _resolveProductImage(widget.order.productCode, widget.order.phone, widget.order.email);

      _items = [
        _OrderItemDetail(
          id: widget.order.orderId.isNotEmpty ? widget.order.orderId : 'ITEM-1',
          productCode: widget.order.productCode.isNotEmpty ? widget.order.productCode : 'PROD',
          productName: widget.order.productCode,
          cageType: widget.order.cageType,
          note: widget.order.note,
          quantity: widget.order.quantity,
          selectedStatus: widget.order.status,
          imageUrl: img,
        ),
      ];
    }
  }

  int _extractStepNumber(String status) {
    if (status.contains('1')) return 1;
    if (status.contains('2')) return 2;
    if (status.contains('3')) return 3;
    if (status.contains('4') || status.toLowerCase().contains('finishing')) return 4;
    if (status.contains('5') || status.toLowerCase().contains('diterima') || status.toLowerCase().contains('selesai')) return 5;
    return 1;
  }

  void _onStageSelected(_OrderItemDetail item, String stage) {
    setState(() {
      item.selectedStatus = stage;
    });
    final stepNumber = _extractStepNumber(stage);
    OrderService.instance.updateOrderStatus(item.id, stage, stepNumber);
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('62')) {
      cleanPhone = '62$cleanPhone';
    }

    final url = Uri.parse(
      'https://wa.me/$cleanPhone?text=Halo%20kami%20dari%20Jatimas%20Sangkar%20mengenai%20pesanan%20Anda.',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Membuka chat WhatsApp ke +$cleanPhone...'),
            backgroundColor: const Color(0xFF25D366),
          ),
        );
      }
    }
  }

  void _showAddStageDialog(_OrderItemDetail item) {
    final stageController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF7A4B29)),
            SizedBox(width: 8),
            Text('Tambah Tahap Baru'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nama tahap pengerjaan baru:',
              style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: stageController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Contoh: Quality Check, Packing Kayu',
                filled: true,
                fillColor: const Color(0xFFF7F7F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCCCCCC)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              final newStage = stageController.text.trim();
              if (newStage.isNotEmpty && !item.stages.contains(newStage)) {
                setState(() {
                  item.stages.add(newStage);
                  item.selectedStatus = newStage;
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7A4B29),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _deleteStage(_OrderItemDetail item, String stage) {
    if (item.stages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal harus ada 1 tahap pengerjaan!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      item.stages.remove(stage);
      if (item.selectedStatus == stage) {
        item.selectedStatus = item.stages.first;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tahap "$stage" berhasil dihapus!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteStageDialog(_OrderItemDetail item) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Row(
              children: [
                Icon(Icons.delete_sweep_rounded, color: Color(0xFFD32F2F)),
                SizedBox(width: 8),
                Text('Hapus Tahap Pengerjaan'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih tahap yang ingin dihapus:',
                    style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                  ),
                  const SizedBox(height: 12),
                  ...item.stages.map((stage) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            stage,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFD32F2F), size: 20),
                            tooltip: 'Hapus $stage',
                            onPressed: () {
                              _deleteStage(item, stage);
                              setDialogState(() {});
                              if (item.stages.length <= 1) {
                                Navigator.pop(ctx);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Selesai'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveOrderProgress() {
    for (final item in _items) {
      final stepNumber = _extractStepNumber(item.selectedStatus);
      OrderService.instance.updateOrderStatus(item.id, item.selectedStatus, stepNumber);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Status proses pengerjaan berhasil disimpan!'),
        backgroundColor: Color(0xFF2E7D32),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
  }

  void _completeOrder() {
    for (final item in _items) {
      item.selectedStatus = 'Diterima';
      OrderService.instance.updateOrderStatus(item.id, 'Diterima', 5);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pesanan #${widget.order.no} (${widget.order.phone}) berhasil diselesaikan!'),
        backgroundColor: const Color(0xFF7A4B29),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5A3825), Color(0xFF2C1810)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'JATIMAS SANGKAR - ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white24,
                    ),
                    child: const Icon(
                      Icons.account_circle,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width < 600 ? 16 : 32,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb Navigasi: Kembali / Detail Pesanan dan Tombol Tutup
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
                      '  /  ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7A7A7A),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const Text(
                      'Detail Pesanan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A4A4A),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFF757575)),
                  label: const Text(
                    'Tutup',
                    style: TextStyle(color: Color(0xFF757575), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Baris Info Pemesan & Tombol Hubungi WhatsApp
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: 16,
              runSpacing: 12,
              children: [
                // Info Pemesan & Tanggal Pemesanan
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Pemesanan: ',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E2E2E),
                        ),
                        children: [
                          TextSpan(
                            text: widget.order.customerName.trim().isNotEmpty
                                ? '${widget.order.customerName} (${widget.order.phone})'
                                : widget.order.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tanggal Pemesanan: ${widget.order.date}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),

                // Tombol Hubungi WhatsApp (Hijau dengan Ikon WhatsApp Asli)
                ElevatedButton.icon(
                  key: const ValueKey('hubungi_whatsapp_button'),
                  onPressed: () => _openWhatsApp(widget.order.phone),
                  icon: const WhatsAppIcon(size: 18, color: Colors.white),
                  label: const Text(
                    'Hubungi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Daftar Item Produk dalam Pesanan
            ..._items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Baris Item Produk (Kotak Abu Kode Produk + Info + Kuantitas)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kotak Abu-abu Berisi Gambar Logo dari Pesanan Pelanggan (Bukan sekadar tulisan)
                      GestureDetector(
                        onTap: () {
                          final img = item.imageUrl?.trim() ?? '';
                          if (img.isNotEmpty) {
                            _showImagePreviewDialog(context, item.productName, img);
                          }
                        },
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: const Color(0xFFA6A6A6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildItemImage(item),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Info Nama Produk, Bentuk Sangkar, dan Catatan
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.cageType,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Note :   ${item.note}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF616161),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Jumlah Kuantitas (2x, 1x persis di gambar)
                      Text(
                        '${item.quantity}x',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF424242),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Baris Pilihan Status (Tahap 1, Tahap 2, Tahap 3, Finishing, Diterima, + Tambah Tahap, - Hapus Tahap)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Status :   ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...item.stages.map((stage) {
                                final isSelected = item.selectedStatus.toLowerCase() == stage.toLowerCase();

                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF7A4B29) : Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF7A4B29) : const Color(0xFFC0C0C0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _onStageSelected(item, stage),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                            child: Text(
                                              stage,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected ? Colors.white : const Color(0xFF4A4A4A),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (item.stages.length > 1)
                                          InkWell(
                                            key: ValueKey('delete_stage_${stage}_$idx'),
                                            onTap: () => _deleteStage(item, stage),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                                              child: Icon(
                                                Icons.close,
                                                size: 14,
                                                color: isSelected ? Colors.white70 : const Color(0xFF888888),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),

                              // Tombol Tambah Tahap Baru
                              InkWell(
                                onTap: () => _showAddStageDialog(item),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F0F0),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFD0D0D0)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, size: 14, color: Color(0xFF7A4B29)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tambah Tahap',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF7A4B29),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Tombol Hapus Tahap
                              InkWell(
                                key: ValueKey('hapus_tahap_btn_$idx'),
                                onTap: () => _showDeleteStageDialog(item),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0F0),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFFCDD2)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.remove_circle_outline, size: 14, color: Color(0xFFD32F2F)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Hapus Tahap',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFD32F2F),
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
                    ],
                  ),

                  const SizedBox(height: 18),
                  // Garis Pemisah Antar Item Produk
                  if (idx < _items.length - 1) ...[
                    const Divider(color: Color(0xFFE0E0E0), thickness: 1, height: 28),
                    const SizedBox(height: 8),
                  ] else ...[
                    const Divider(color: Color(0xFFE0E0E0), thickness: 1, height: 28),
                  ],
                ],
              );
            }),

            const SizedBox(height: 24),

            // Tombol Selesaikan Pesanan & Simpan di Kanan Bawah
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 14,
              runSpacing: 10,
              children: [
                // Tombol Selesaikan Pesanan (Langsung ke Riwayat)
                ElevatedButton.icon(
                  key: const ValueKey('selesaikan_pesanan_button'),
                  onPressed: _completeOrder,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text(
                    'Selesaikan Pesanan',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A4B29),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),

                // Tombol Simpan (Merah persis seperti di gambar 2)
                ElevatedButton(
                  key: const ValueKey('simpan_order_status_button'),
                  onPressed: _saveOrderProgress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE52525),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Simpan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemImage(_OrderItemDetail item) {
    final imgUrl = item.imageUrl?.trim() ?? '';

    if (imgUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Product.buildImageFromSource(
            imgUrl,
            width: 78,
            height: 78,
            fit: BoxFit.cover,
            placeholder: const Center(
              child: Icon(Icons.image_outlined, color: Colors.white70, size: 28),
            ),
          ),
          Positioned(
            right: 3,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 26, color: Color(0xFF555555)),
          const SizedBox(height: 2),
          Text(
            item.productCode,
            style: const TextStyle(
              color: Color(0xFF555555),
              fontSize: 12,
              fontWeight: FontWeight.bold,
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
