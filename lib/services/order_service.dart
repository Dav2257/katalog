import 'package:flutter/foundation.dart';
import '../supabase_config.dart';
import 'auth_service.dart';

class OrderProgressStep {
  final int step;
  final String title;
  final String description;

  const OrderProgressStep({
    required this.step,
    required this.title,
    required this.description,
  });
}

class UserOrder {
  final String id;
  final String productName;
  final int quantity;
  final String cageTypeOrDesign;
  final String note;
  String status;
  int currentStep;
  final String? imageUrl;
  final DateTime orderDate;
  final String phone;
  final String email;
  final String customerName;

  UserOrder({
    required this.id,
    required this.productName,
    this.quantity = 1,
    required this.cageTypeOrDesign,
    required this.note,
    this.status = 'Tahap 1',
    this.currentStep = 1,
    this.imageUrl,
    DateTime? orderDate,
    String? phone,
    this.email = '',
    this.customerName = '',
  })  : orderDate = orderDate ?? DateTime.now(),
        phone = phone ?? '085732257048';

  static const List<OrderProgressStep> allSteps = [
    OrderProgressStep(
      step: 1,
      title: 'Tahap 1: Verifikasi & Desain',
      description: 'Konfirmasi motif ukir, logo, dan spesifikasi bentuk sangkar.',
    ),
    OrderProgressStep(
      step: 2,
      title: 'Tahap 2: Pemilihan Kayu Jati',
      description: 'Seleksi kayu jati Jepara pilihan dan pemotongan bahan baku.',
    ),
    OrderProgressStep(
      step: 3,
      title: 'Tahap 3: Proses Ukir & Grafir',
      description: 'Pengerjaan ukiran timbul atau grafir logo oleh pengrajin ahli.',
    ),
    OrderProgressStep(
      step: 4,
      title: 'Tahap 4: Perakitan & Finishing',
      description: 'Perakitan sangkar, pengamplasan halus, dan pelapisan melamin.',
    ),
    OrderProgressStep(
      step: 5,
      title: 'Tahap 5: Quality Check & Kirim',
      description: 'Pemeriksaan kualitas akhir dan sangkar siap dikirim ke alamat Anda.',
    ),
  ];
}

class OrderService extends ChangeNotifier {
  static final OrderService instance = OrderService._internal();

  OrderService._internal() {
    AuthService.instance.addListener(_handleAuthChange);
  }

  void _handleAuthChange() {
    notifyListeners();
  }

  // Pesanan untuk pengguna umum (Guest)
  final List<UserOrder> _guestOrders = [];

  // Pesanan khusus untuk User yang login (Member)
  final List<UserOrder> _userOrders = [];

  /// Mengembalikan daftar pesanan: Hanya untuk user yang login dan sesuai identitas akunnya
  List<UserOrder> get orders {
    if (!AuthService.instance.isLoggedIn) return const [];
    final p = AuthService.instance.userPhone.trim();
    final e = AuthService.instance.userEmail.trim().toLowerCase();
    return List.unmodifiable(_userOrders.where((o) {
      if (p.isNotEmpty && o.phone.trim() == p) return true;
      if (e.isNotEmpty && o.email.trim().toLowerCase() == e) return true;
      return false;
    }));
  }

  List<UserOrder> get guestOrders => List.unmodifiable(_guestOrders);
  List<UserOrder> get userOrders => List.unmodifiable(_userOrders);

  /// Mengembalikan seluruh pesanan dari semua user (tanpa duplikasi)
  List<UserOrder> get allOrders {
    final Map<String, UserOrder> map = {};
    for (final o in _userOrders) {
      map[o.id] = o;
    }
    for (final o in _guestOrders) {
      if (!map.containsKey(o.id)) {
        map[o.id] = o;
      }
    }
    return List.unmodifiable(map.values);
  }

  /// Mengambil seluruh pesanan dari database Supabase
  Future<void> fetchOrders() async {
    try {
      final rows = await supabase
          .from('pesanan')
          .select()
          .order('created_at', ascending: false);

      final List<UserOrder> loaded = [];
      for (final r in rows) {
        final id = r['id']?.toString() ?? '';
        final phone = r['phone']?.toString() ?? '';
        final email = r['email']?.toString() ?? '';
        final orderDateStr = r['order_date']?.toString() ?? '';
        final status = r['status']?.toString() ?? 'Tahap 1';
        final step = (r['stage_number'] is num)
            ? (r['stage_number'] as num).toInt()
            : 1;

        String custName = r['customer_name']?.toString() ?? '';

        String prodName = 'Sangkar Custom';
        int qty = 1;
        String cageType = 'Sangkar 1';
        String note = '';
        String? imgUrl;

        final items = r['items'];
        if (items is List && items.isNotEmpty) {
          final firstItem = items.first;
          if (firstItem is Map) {
            prodName = firstItem['product_name']?.toString() ?? prodName;
            qty = (firstItem['quantity'] is num)
                ? (firstItem['quantity'] as num).toInt()
                : qty;
            cageType = firstItem['cage_type']?.toString() ?? cageType;
            note = firstItem['note']?.toString() ?? '';
            imgUrl = firstItem['image_url']?.toString();
            if (custName.isEmpty && firstItem['customer_name'] != null) {
              custName = firstItem['customer_name'].toString();
            }
          }
        }

        DateTime orderDate = DateTime.now();
        try {
          if (orderDateStr.isNotEmpty) {
            orderDate = DateTime.tryParse(orderDateStr) ?? DateTime.now();
          }
        } catch (_) {}

        loaded.add(UserOrder(
          id: id,
          productName: prodName,
          quantity: qty,
          cageTypeOrDesign: cageType,
          note: note,
          status: status,
          currentStep: step,
          imageUrl: imgUrl,
          orderDate: orderDate,
          phone: phone,
          email: email,
          customerName: custName,
        ));
      }

      _guestOrders.clear();
      _userOrders.clear();
      _userOrders.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Catatan: Gagal memuat pesanan dari Supabase: $e');
    }
  }

  /// Menambahkan pesanan baru dan menyimpannya ke database Supabase
  Future<void> addOrder(UserOrder order, {bool? forUser}) async {
    final isUser = forUser ?? AuthService.instance.isLoggedIn;
    if (isUser) {
      _userOrders.insert(0, order);
    } else {
      _guestOrders.insert(0, order);
    }
    notifyListeners();

    // Simpan ke Supabase tabel pesanan
    final dateStr =
        '${order.orderDate.day.toString().padLeft(2, '0')}-${order.orderDate.month.toString().padLeft(2, '0')}-${order.orderDate.year}';

    final itemsPayload = [
      {
        'product_name': order.productName,
        'quantity': order.quantity,
        'cage_type': order.cageTypeOrDesign,
        'note': order.note,
        'image_url': order.imageUrl,
        'customer_name': order.customerName,
      }
    ];

    try {
      await supabase.from('pesanan').insert({
        'phone': order.phone,
        'customer_name': order.customerName,
        'email': order.email,
        'order_date': dateStr,
        'status': order.status,
        'stage_number': order.currentStep,
        'is_completed': false,
        'total_amount': 0,
        'items': itemsPayload,
      });
      debugPrint('SUKSES: Pesanan ${order.id} berhasil disimpan ke tabel pesanan di Supabase');
      await fetchOrders();
    } catch (e) {
      // Fallback jika kolom customer_name belum di-migrate di Supabase SQL Editor
      try {
        await supabase.from('pesanan').insert({
          'phone': order.phone,
          'email': order.email,
          'order_date': dateStr,
          'status': order.status,
          'stage_number': order.currentStep,
          'is_completed': false,
          'total_amount': 0,
          'items': itemsPayload,
        });
        await fetchOrders();
      } catch (e2) {
        debugPrint('PERINGATAN: Gagal menyimpan pesanan ke Supabase: $e2');
        debugPrint('Pastikan Anda telah menjalankan skrip tabel "pesanan" di Supabase SQL Editor.');
      }
    }
  }

  /// Memperbarui status tahap pengerjaan pesanan dan menyinkronkannya ke Supabase
  void updateOrderStatus(String orderId, String newStatus, int newStep) {
    var index = _guestOrders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _guestOrders[index].status = newStatus;
      _guestOrders[index].currentStep = newStep;
      notifyListeners();
      _syncStatusToSupabase(orderId, newStatus, newStep);
      return;
    }
    index = _userOrders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _userOrders[index].status = newStatus;
      _userOrders[index].currentStep = newStep;
      notifyListeners();
      _syncStatusToSupabase(orderId, newStatus, newStep);
    }
  }

  Future<void> _syncStatusToSupabase(String orderId, String newStatus, int newStep) async {
    final isDone = newStatus.toLowerCase().contains('diterima') ||
        newStatus.toLowerCase().contains('selesai') ||
        newStep >= 5;

    try {
      await supabase.from('pesanan').update({
        'status': newStatus,
        'stage_number': newStep,
        'is_completed': isDone,
      }).eq('id', orderId);
      debugPrint('SUKSES: Status pesanan $orderId berhasil diupdate ke Supabase');
    } catch (e) {
      debugPrint('Catatan: Gagal update status pesanan di Supabase: $e');
    }
  }

  /// Update status pesanan berdasarkan nomor telepon
  void updateOrderStatusByPhone(String phone, String newStatus, int newStep) {
    bool updated = false;
    for (final o in _userOrders) {
      if (o.phone == phone) {
        o.status = newStatus;
        o.currentStep = newStep;
        updated = true;
        _syncStatusToSupabase(o.id, newStatus, newStep);
      }
    }
    for (final o in _guestOrders) {
      if (o.phone == phone) {
        o.status = newStatus;
        o.currentStep = newStep;
        updated = true;
        _syncStatusToSupabase(o.id, newStatus, newStep);
      }
    }
    if (updated) {
      notifyListeners();
    }
  }

  void resetForTesting() {
    _guestOrders.clear();
    _userOrders.clear();
    notifyListeners();
  }
}
