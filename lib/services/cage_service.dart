import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const String _prefCagesKey = 'app_cached_cages_list';

  CageService._internal() {
    _loadFromLocalPrefs().then((_) => fetchCages());
  }

  // Dimulai dari 0 data (kosong, tanpa dummy)
  final List<CageData> _cages = [];
  bool _isLoading = false;

  List<CageData> get cages => List.unmodifiable(_cages);

  int get count => _cages.length;
  bool get isLoading => _isLoading;

  /// Memuat sangkar dari cache SharedPreferences lokal (sangat cepat & aman offline)
  Future<void> _loadFromLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCagesKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        if (list.isNotEmpty && _cages.isEmpty) {
          _cages.clear();
          for (final item in list) {
            if (item is Map) {
              _cages.add(CageData.fromMap(Map<String, dynamic>.from(item)));
            }
          }
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Menyimpan sangkar ke SharedPreferences lokal
  Future<void> _saveToLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_cages.map((c) => c.toMap()).toList());
      await prefs.setString(_prefCagesKey, jsonString);
    } catch (_) {}
  }

  /// Mengambil data bentuk sangkar langsung dari database Supabase / Storage / Local cache
  /// Mengambil data bentuk sangkar langsung dari database Supabase / Storage / Local cache
  Future<void> fetchCages() async {
    _isLoading = true;
    notifyListeners();

    try {
      List<dynamic> rows = [];
      String activeSource = 'none';

      // 1. Prioritas Utama: Baca dari tabel database public.app_settings
      try {
        final dbResult = await supabase
            .from('app_settings')
            .select('settings_json')
            .eq('id', 'global_settings')
            .maybeSingle();
        if (dbResult != null && dbResult['settings_json'] is Map) {
          final sJson = dbResult['settings_json'] as Map;
          if (sJson['cages'] is List && (sJson['cages'] as List).isNotEmpty) {
            rows = sJson['cages'] as List;
            activeSource = 'public.app_settings (Database)';
          }
        }
      } catch (_) {}

      // 2. Fallback: Baca dari tabel bentuk_sangkar jika sudah dibuat
      if (rows.isEmpty) {
        try {
          rows = await supabase
              .from('bentuk_sangkar')
              .select()
              .order('created_at', ascending: true);
          if (rows.isNotEmpty) activeSource = 'bentuk_sangkar (Database)';
        } catch (_) {
          try {
            rows = await supabase
                .from('cage_shapes')
                .select()
                .order('created_at', ascending: true);
            if (rows.isNotEmpty) activeSource = 'cage_shapes (Database)';
          } catch (_) {}
        }
      }

      // 3. Fallback: Baca dari app_settings.json di Storage
      if (rows.isEmpty) {
        rows = await _loadCagesFromStorage();
        if (rows.isNotEmpty) activeSource = 'app_settings.json (Storage)';
      }

      // Terapkan data yang didapat
      if (rows.isNotEmpty) {
        _cages.clear();
        for (final r in rows) {
          if (r is Map<String, dynamic>) {
            _cages.add(CageData.fromMap(r));
          } else if (r is Map) {
            _cages.add(CageData.fromMap(Map<String, dynamic>.from(r)));
          }
        }
        await _saveToLocalPrefs();
      } else if (_cages.isEmpty) {
        // Jika cloud kosong tapi lokal punya cache, gunakan cache lokal
        await _loadFromLocalPrefs();
      }
      debugPrint('SUKSES: Berhasil memuat ${_cages.length} bentuk sangkar ($activeSource).');
    } catch (e) {
      debugPrint('Catatan: Tidak dapat memuat bentuk sangkar dari Supabase: $e');
      if (_cages.isEmpty) {
        await _loadFromLocalPrefs();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tambah sangkar baru oleh Admin (tersinkronisasi ke memori, lokal prefs, dan database Supabase)
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
    _saveToLocalPrefs();
    notifyListeners();

    // Simpan permanen ke Supabase Database & Storage
    _syncCagesToCloud();

    return newCage;
  }

  /// Hapus sangkar berdasarkan ID (mendukung hapus sampai 0 data)
  bool removeCage(String id) {
    if (_cages.isEmpty) return false;
    final index = _cages.indexWhere((c) => c.id == id);
    if (index >= 0) {
      _cages.removeAt(index);
      _saveToLocalPrefs();
      notifyListeners();

      // Sinkronkan ke database Supabase
      _syncCagesToCloud();
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
      _cages.removeAt(index);
      _saveToLocalPrefs();
      notifyListeners();

      _syncCagesToCloud();
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
      _saveToLocalPrefs();
      notifyListeners();

      _syncCagesToCloud();
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
      _saveToLocalPrefs();
      notifyListeners();

      _syncCagesToCloud();
    }
  }

  /// Reset data sangkar ke kondisi awal (kosong / 0 data)
  void resetToDefault() {
    _cages.clear();
    _saveToLocalPrefs();
    notifyListeners();
    _syncCagesToCloud();
  }

  // ===========================================================================
  // SINKRONISASI SUPABASE (DATABASE & STORAGE)
  // ===========================================================================

  Future<void> _syncCagesToCloud() async {
    final cagesList = _cages.map((c) => c.toMap()).toList();

    // 1. Simpan langsung ke tabel public.app_settings (Database Supabase)
    try {
      final dbResult = await supabase
          .from('app_settings')
          .select('settings_json')
          .eq('id', 'global_settings')
          .maybeSingle();

      final currentSettings = (dbResult != null && dbResult['settings_json'] is Map)
          ? Map<String, dynamic>.from(dbResult['settings_json'] as Map)
          : <String, dynamic>{};

      currentSettings['cages'] = cagesList;
      currentSettings['updatedAt'] = DateTime.now().toIso8601String();

      await supabase.from('app_settings').upsert({
        'id': 'global_settings',
        'settings_json': currentSettings,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('SUKSES: Cages berhasil disimpan ke tabel public.app_settings');
    } catch (e) {
      debugPrint('Catatan simpan cages ke public.app_settings: $e');
    }

    // 2. Simpan jika ada tabel bentuk_sangkar
    try {
      for (final cage in _cages) {
        try {
          await supabase.from('bentuk_sangkar').upsert({
            'id': cage.id,
            'name': cage.name,
            'image_url': cage.imageUrl ?? '',
          });
        } catch (_) {}
      }
    } catch (_) {}

    // 3. Backup ke Supabase Storage (app_settings.json)
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
