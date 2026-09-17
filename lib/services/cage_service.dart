import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

class CageData {
  final String id;
  final String name;
  final String? imageUrl;
  final Uint8List? imageBytes;

  const CageData({
    required this.id,
    required this.name,
    this.imageUrl,
    this.imageBytes,
  });

  CageData copyWith({
    String? id,
    String? name,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    return CageData(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl ?? '',
    };
  }

  factory CageData.fromMap(Map<String, dynamic> map) {
    return CageData(
      id: map['id']?.toString() ?? '',
      name: (map['name'] ?? map['nama'] ?? 'Sangkar').toString(),
      imageUrl: (map['image_url'] ?? map['imageUrl'] ?? map['icon_url'])?.toString(),
    );
  }

  /// Helper untuk merender gambar sangkar baik dari upload file (Uint8List)
  /// maupun dari URL jaringan, dengan fallback placeholder yang aman.
  Widget buildImage({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    final defaultPlaceholder = placeholder ??
        const Center(
          child: Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 28),
        );

    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return Image.memory(
        imageBytes!,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => defaultPlaceholder,
      );
    }

    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return Image.network(
        imageUrl!.trim(),
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => defaultPlaceholder,
      );
    }

    return defaultPlaceholder;
  }
}

/// Layanan terpusat untuk menyimpan & mengelola varian bentuk sangkar oleh Admin.
/// Terhubung langsung ke basis data Supabase (tabel bentuk_sangkar) dan dimulai dari 0 data.
class CageService extends ChangeNotifier {
  static final CageService instance = CageService._internal();

  CageService._internal() {
    fetchCages();
  }

  // Dimulai dari 0 data (kosong, tanpa dummy)
  final List<CageData> _cages = [];
  bool _isLoading = false;

  List<CageData> get cages => List.unmodifiable(_cages);

  int get count => _cages.length;
  bool get isLoading => _isLoading;

  /// Mengambil data bentuk sangkar langsung dari database Supabase
  Future<void> fetchCages() async {
    _isLoading = true;
    notifyListeners();

    try {
      List<dynamic> rows = [];
      String activeTable = 'bentuk_sangkar';

      try {
        rows = await supabase
            .from('bentuk_sangkar')
            .select()
            .order('created_at', ascending: true);
      } catch (_) {
        // Fallback jika pengguna menggunakan nama tabel cage_shapes
        try {
          rows = await supabase
              .from('cage_shapes')
              .select()
              .order('created_at', ascending: true);
          activeTable = 'cage_shapes';
        } catch (_) {
          // Jika tabel database belum dibuat, coba baca dari app_settings.json di Storage
          rows = await _loadCagesFromStorage();
        }
      }

      _cages.clear();
      for (final r in rows) {
        if (r is Map<String, dynamic>) {
          _cages.add(CageData.fromMap(r));
        } else if (r is Map) {
          _cages.add(CageData.fromMap(Map<String, dynamic>.from(r)));
        }
      }
      debugPrint('SUKSES: Berhasil memuat ${_cages.length} bentuk sangkar dari Supabase ($activeTable).');
    } catch (e) {
      debugPrint('Catatan: Tidak dapat memuat bentuk sangkar dari Supabase: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tambah sangkar baru oleh Admin (tersinkronisasi ke memori dan database Supabase)
  CageData addCage({String? name, String? imageUrl, Uint8List? imageBytes}) {
    final nextNumber = _cages.length + 1;
    final generatedId = 'cage_${DateTime.now().millisecondsSinceEpoch}_$nextNumber';
    final cleanName = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Sangkar $nextNumber';

    final newCage = CageData(
      id: generatedId,
      name: cleanName,
      imageUrl: imageUrl?.trim(),
      imageBytes: imageBytes,
    );

    _cages.add(newCage);
    notifyListeners();

    // Simpan asinkron ke database Supabase
    _syncAddCageToSupabase(newCage);

    return newCage;
  }

  /// Hapus sangkar berdasarkan ID (mendukung hapus sampai 0 data)
  bool removeCage(String id) {
    if (_cages.isEmpty) return false;
    final index = _cages.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final removed = _cages.removeAt(index);
      notifyListeners();

      // Hapus dari database Supabase
      _syncDeleteCageFromSupabase(removed.id, removed.name);
      return true;
    }
    return false;
  }

  /// Hapus sangkar berdasarkan Nama
  bool removeCageByName(String name) {
    if (_cages.isEmpty) return false;
    final cleanName = name.trim().toLowerCase();
    final index = _cages.indexWhere((c) => c.name.trim().toLowerCase() == cleanName);
    if (index >= 0) {
      final removed = _cages.removeAt(index);
      notifyListeners();

      _syncDeleteCageFromSupabase(removed.id, removed.name);
      return true;
    }
    return false;
  }

  /// Update data sangkar (nama atau foto)
  void updateCage({required String id, String? name, String? imageUrl, Uint8List? imageBytes}) {
    final index = _cages.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final old = _cages[index];
      final updated = old.copyWith(
        name: name?.trim(),
        imageUrl: imageUrl?.trim(),
        imageBytes: imageBytes,
      );
      _cages[index] = updated;
      notifyListeners();

      _syncUpdateCageToSupabase(updated);
    }
  }

  /// Update foto sangkar berdasarkan nama
  void updateCageImageByName(String name, String imageUrl, {Uint8List? imageBytes}) {
    final cleanName = name.trim().toLowerCase();
    final index = _cages.indexWhere((c) => c.name.trim().toLowerCase() == cleanName);
    if (index >= 0) {
      final old = _cages[index];
      final updated = old.copyWith(
        imageUrl: imageUrl.trim(),
        imageBytes: imageBytes,
      );
      _cages[index] = updated;
      notifyListeners();

      _syncUpdateCageToSupabase(updated);
    }
  }

  /// Reset data sangkar ke kondisi awal (kosong / 0 data)
  void resetToDefault() {
    _cages.clear();
    notifyListeners();
  }

  // ===========================================================================
  // SINKRONISASI SUPABASE (DATABASE & STORAGE)
  // ===========================================================================

  Future<void> _syncAddCageToSupabase(CageData cage) async {
    try {
      try {
        await supabase.from('bentuk_sangkar').insert({
          'id': cage.id,
          'name': cage.name,
          'image_url': cage.imageUrl ?? '',
        });
      } catch (_) {
        await supabase.from('cage_shapes').insert({
          'id': cage.id,
          'name': cage.name,
          'image_url': cage.imageUrl ?? '',
        });
      }
    } catch (e) {
      debugPrint('Catatan insert bentuk_sangkar di Supabase: $e');
    }
    _backupCagesToStorage();
  }

  Future<void> _syncDeleteCageFromSupabase(String id, String name) async {
    try {
      try {
        await supabase.from('bentuk_sangkar').delete().match({'id': id});
      } catch (_) {
        await supabase.from('cage_shapes').delete().match({'id': id});
      }
    } catch (e) {
      debugPrint('Catatan delete bentuk_sangkar di Supabase: $e');
    }
    _backupCagesToStorage();
  }

  Future<void> _syncUpdateCageToSupabase(CageData cage) async {
    try {
      try {
        await supabase.from('bentuk_sangkar').update({
          'name': cage.name,
          'image_url': cage.imageUrl ?? '',
        }).match({'id': cage.id});
      } catch (_) {
        await supabase.from('cage_shapes').update({
          'name': cage.name,
          'image_url': cage.imageUrl ?? '',
        }).match({'id': cage.id});
      }
    } catch (e) {
      debugPrint('Catatan update bentuk_sangkar di Supabase: $e');
    }
    _backupCagesToStorage();
  }

  /// Backup daftar sangkar ke Storage Supabase (app_settings.json) sebagai lapisan persistensi tambahan
  Future<void> _backupCagesToStorage() async {
    try {
      final downloadedBytes = await supabase.storage.from('katalog').download('app_settings.json');
      final jsonMap = jsonDecode(utf8.decode(downloadedBytes)) as Map<String, dynamic>;
      jsonMap['cages'] = _cages.map((c) => c.toMap()).toList();

      final updatedBytes = Uint8List.fromList(utf8.encode(jsonEncode(jsonMap)));
      await supabase.storage.from('katalog').uploadBinary(
            'app_settings.json',
            updatedBytes,
            fileOptions: const FileOptions(contentType: 'application/json', upsert: true),
          );
    } catch (_) {}
  }

  Future<List<dynamic>> _loadCagesFromStorage() async {
    try {
      final downloadedBytes = await supabase.storage.from('katalog').download('app_settings.json');
      final jsonMap = jsonDecode(utf8.decode(downloadedBytes)) as Map<String, dynamic>;
      if (jsonMap['cages'] is List) {
        return jsonMap['cages'] as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }
}
