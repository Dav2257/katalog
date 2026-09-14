import 'package:flutter/foundation.dart';
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

  // Pesanan untuk pengguna umum (Guest) - tidak ada riwayat pesanan
  final List<UserOrder> _guestOrders = [];

  // Pesanan khusus untuk User yang login (Member)
  final List<UserOrder> _userOrders = [];

  /// Mengembalikan daftar pesanan: Hanya untuk user yang login (user umum tidak ada bagian ini)
  List<UserOrder> get orders => AuthService.instance.isLoggedIn
      ? List.unmodifiable(_userOrders)
      : const [];

  List<UserOrder> get guestOrders => List.unmodifiable(_guestOrders);
  List<UserOrder> get userOrders => List.unmodifiable(_userOrders);

  /// Mengembalikan seluruh pesanan dari semua user (member maupun umum)
  List<UserOrder> get allOrders => [
        ..._guestOrders,
        ..._userOrders,
      ];

  void addOrder(UserOrder order, {bool? forUser}) {
    final isUser = forUser ?? AuthService.instance.isLoggedIn;
    if (isUser) {
      _userOrders.insert(0, order);
    } else {
      _guestOrders.insert(0, order);
    }
    notifyListeners();
  }

  void updateOrderStatus(String orderId, String newStatus, int newStep) {
    var index = _guestOrders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _guestOrders[index].status = newStatus;
      _guestOrders[index].currentStep = newStep;
      notifyListeners();
      return;
    }
    index = _userOrders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _userOrders[index].status = newStatus;
      _userOrders[index].currentStep = newStep;
      notifyListeners();
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
      }
    }
    for (final o in _guestOrders) {
      if (o.phone == phone) {
        o.status = newStatus;
        o.currentStep = newStep;
        updated = true;
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
