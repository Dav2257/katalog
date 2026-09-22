import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model item jadwal kegiatan proses pembuatan sangkar
class ProductionScheduleItem {
  final String id;
  final String title;
  final DateTime date; // Disimpan tanpa komponen jam untuk perbandingan tanggal (YYYY-MM-DD)
  final String? time; // Contoh: "08:30" atau "08:00 - 11:30"
  final String? customer; // Pelanggan / Pemesan
  final String? cageType; // Type Sangkar (Kosan R.10, dsb.)
  final int? qty; // Kuantitas / Qty
  final String? description;
  final String status; // "Belum dimulai", "Sedang berlangsung", "Siap Cetak", "Di Cetak", "Selesai"
  final String? pic; // Penanggung jawab / tukang
  final String? imageUrl; // Cover / file media desain
  final DateTime createdAt;

  ProductionScheduleItem({
    required this.id,
    required this.title,
    required this.date,
    this.time,
    this.customer,
    this.cageType,
    this.qty,
    this.description,
    this.status = 'Sedang berlangsung',
    this.pic,
    this.imageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCompleted => status.toLowerCase() == 'selesai';

  ProductionScheduleItem copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? time,
    String? customer,
    String? cageType,
    int? qty,
    String? description,
    String? status,
    String? pic,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return ProductionScheduleItem(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      customer: customer ?? this.customer,
      cageType: cageType ?? this.cageType,
      qty: qty ?? this.qty,
      description: description ?? this.description,
      status: status ?? this.status,
      pic: pic ?? this.pic,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'time': time,
      'customer': customer,
      'cageType': cageType,
      'qty': qty,
      'description': description,
      'status': status,
      'pic': pic,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProductionScheduleItem.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    if (map['date'] != null) {
      final parts = map['date'].toString().split('-');
      if (parts.length == 3) {
        parsedDate = DateTime(
          int.tryParse(parts[0]) ?? 2026,
          int.tryParse(parts[1]) ?? 1,
          int.tryParse(parts[2]) ?? 1,
        );
      } else {
        parsedDate = DateTime.tryParse(map['date'].toString()) ?? DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return ProductionScheduleItem(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? 'Kegiatan Pembuatan',
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      time: map['time']?.toString(),
      customer: map['customer']?.toString(),
      cageType: map['cageType']?.toString(),
      qty: map['qty'] != null ? int.tryParse(map['qty'].toString()) : null,
      description: map['description']?.toString(),
      status: map['status']?.toString() ?? 'Sedang berlangsung',
      pic: map['pic']?.toString(),
      imageUrl: (map['imageUrl'] ?? map['image_url'] ?? map['gambar_url'])?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Layanan terpusat untuk menyimpan & mengelola jadwal kegiatan proses pembuatan khusus Admin
class ProductionScheduleService extends ChangeNotifier {
  static final ProductionScheduleService instance = ProductionScheduleService._internal();

  ProductionScheduleService._internal() {
    _loadFromLocalPrefs();
  }

  static const String _prefKey = 'admin_production_schedule_items_v1';

  final List<ProductionScheduleItem> _items = [];
  bool _isInitialized = false;

  List<ProductionScheduleItem> get items => List.unmodifiable(_items);
  bool get isInitialized => _isInitialized;

  /// Memuat jadwal dari cache SharedPreferences
  Future<void> _loadFromLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        _items.clear();
        for (final item in list) {
          if (item is Map) {
            _items.add(ProductionScheduleItem.fromMap(Map<String, dynamic>.from(item)));
          }
        }
        _items.sort((a, b) => a.date.compareTo(b.date));
      }
    } catch (e) {
      debugPrint('Catatan muat schedule: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Menyimpan jadwal ke SharedPreferences
  Future<void> _saveToLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_items.map((it) => it.toMap()).toList());
      await prefs.setString(_prefKey, jsonString);
    } catch (e) {
      debugPrint('Catatan simpan schedule: $e');
    }
  }

  /// Mengambil daftar kegiatan untuk tanggal tertentu (YYYY-MM-DD)
  List<ProductionScheduleItem> getItemsForDate(DateTime date) {
    return _items.where((it) =>
      it.date.year == date.year &&
      it.date.month == date.month &&
      it.date.day == date.day
    ).toList();
  }

  /// Mengambil daftar tanggal yang memiliki kegiatan dalam format key 'YYYY-MM-DD'
  Set<String> getDateKeysWithEvents(int year, int month) {
    final set = <String>{};
    for (final it in _items) {
      if (it.date.year == year && it.date.month == month) {
        final key = '${it.date.year}-${it.date.month.toString().padLeft(2, '0')}-${it.date.day.toString().padLeft(2, '0')}';
        set.add(key);
      }
    }
    return set;
  }

  /// Tambah kegiatan baru
  Future<void> addItem(ProductionScheduleItem item) async {
    _items.add(item);
    _items.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
    await _saveToLocalPrefs();
  }

  /// Update kegiatan yang ada
  Future<void> updateItem(ProductionScheduleItem updated) async {
    final index = _items.indexWhere((it) => it.id == updated.id);
    if (index >= 0) {
      _items[index] = updated;
      _items.sort((a, b) => a.date.compareTo(b.date));
      notifyListeners();
      await _saveToLocalPrefs();
    }
  }

  /// Hapus kegiatan berdasarkan ID
  Future<void> deleteItem(String id) async {
    _items.removeWhere((it) => it.id == id);
    notifyListeners();
    await _saveToLocalPrefs();
  }

  /// Toggle status selesai / belum selesai
  Future<void> toggleStatus(String id) async {
    final index = _items.indexWhere((it) => it.id == id);
    if (index >= 0) {
      final cur = _items[index];
      final newStatus = cur.isCompleted ? 'Sedang Berjalan' : 'Selesai';
      _items[index] = cur.copyWith(status: newStatus);
      notifyListeners();
      await _saveToLocalPrefs();
    }
  }
}
