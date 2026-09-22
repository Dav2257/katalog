import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../supabase_config.dart';

/// Layanan terpusat untuk menyimpan & mengelola database hashtag produk.
/// Mendukung sinkronisasi hybrid:
/// 1. Local Cache (SharedPreferences) untuk performa instan tanpa delay.
/// 2. Database Supabase (tabel public.hashtags) untuk sinkronisasi antar perangkat.
/// 3. Auto-harvesting dari katalog produk yang sedang aktif.
class HashtagService extends ChangeNotifier {
  static final HashtagService instance = HashtagService._internal();

  static const String _prefHashtagsKey = 'cached_hashtags_list_v1';

  // Seed default hashtag Jatimas Sangkar
  static const List<String> _seedHashtags = [
    '#sangkar',
    '#jati',
    '#jepara',
    '#ukir',
    '#cungkok',
    '#kacer',
    '#murai',
    '#kenari',
    '#pleci',
    '#kosan',
    '#replika',
    '#finishing',
    '#natural',
    '#mentahan',
    '#kayu',
    '#bambu',
    '#serdadu',
    '#carbon',
  ];

  final Set<String> _hashtags = {};
  bool _isLoading = false;

  HashtagService._internal() {
    _init();
  }

  bool get isLoading => _isLoading;

  /// Mengembalikan seluruh hashtag yang tersimpan (diurutkan alfabet)
  List<String> get hashtags {
    final list = _hashtags.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return List.unmodifiable(list);
  }

  Future<void> _init() async {
    _hashtags.addAll(_seedHashtags);
    await _loadFromLocalPrefs();
    fetchHashtags();
  }

  /// Memuat daftar hashtag dari SharedPreferences
  Future<void> _loadFromLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefHashtagsKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        for (final item in decoded) {
          final str = item.toString().trim();
          if (str.isNotEmpty) {
            _hashtags.add(_formatTag(str));
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('HashtagService._loadFromLocalPrefs error: $e');
    }
  }

  /// Menyimpan daftar hashtag ke SharedPreferences
  Future<void> _saveToLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _hashtags.toList();
      await prefs.setString(_prefHashtagsKey, jsonEncode(list));
    } catch (e) {
      debugPrint('HashtagService._saveToLocalPrefs error: $e');
    }
  }

  /// Format hashtag standar: diawali '#' dan tanpa spasi
  static String _formatTag(String raw) {
    var clean = raw.trim().replaceAll(' ', '');
    if (clean.isEmpty) return '';
    if (!clean.startsWith('#')) {
      clean = '#$clean';
    }
    return clean;
  }

  /// Mengambil daftar hashtag dari tabel Supabase `public.hashtags`
  Future<void> fetchHashtags() async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<dynamic> data = await supabase
          .from('hashtags')
          .select('name')
          .order('name', ascending: true);

      for (final item in data) {
        if (item is Map<String, dynamic> && item['name'] != null) {
          final formatted = _formatTag(item['name'].toString());
          if (formatted.isNotEmpty) {
            _hashtags.add(formatted);
          }
        }
      }
      await _saveToLocalPrefs();
    } catch (e) {
      // Tabel mungkin belum dibuat atau offline, gunakan data cache yang sudah ada
      debugPrint('HashtagService.fetchHashtags Supabase info: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Menambahkan satu hashtag baru dan menyimpannya ke local cache & Supabase
  Future<void> addHashtag(String tag) async {
    final formatted = _formatTag(tag);
    if (formatted.isEmpty) return;

    final isNew = _hashtags.add(formatted);
    notifyListeners();

    if (isNew) {
      await _saveToLocalPrefs();
    }

    // Simpan ke Supabase jika memungkinkan
    try {
      await supabase.from('hashtags').upsert(
        {
          'name': formatted,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'name',
      );
    } catch (e) {
      debugPrint('HashtagService.addHashtag Supabase info: $e');
    }
  }

  /// Menambahkan beberapa hashtag sekaligus (misal saat produk disimpan)
  Future<void> addHashtags(Iterable<String> tags) async {
    bool hasNew = false;
    final List<Map<String, dynamic>> upsertPayload = [];

    for (final tag in tags) {
      final formatted = _formatTag(tag);
      if (formatted.isNotEmpty) {
        if (_hashtags.add(formatted)) {
          hasNew = true;
        }
        upsertPayload.add({
          'name': formatted,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }

    if (hasNew) {
      notifyListeners();
      await _saveToLocalPrefs();
    }

    if (upsertPayload.isNotEmpty) {
      try {
        await supabase.from('hashtags').upsert(
          upsertPayload,
          onConflict: 'name',
        );
      } catch (e) {
        debugPrint('HashtagService.addHashtags Supabase info: $e');
      }
    }
  }

  /// Mengambil saran hashtag berdasarkan teks yang diketik admin
  /// - `query`: Teks pencarian (contoh: 'ja' atau '#ja')
  /// - `exclude`: Daftar hashtag yang sudah terpilih agar tidak disarankan ulang
  /// - `limit`: Batas maksimal saran (default 10)
  List<String> getSuggestions(
    String query, {
    List<String>? exclude,
    int limit = 10,
  }) {
    final cleanQuery = query.trim().replaceAll('#', '').toLowerCase();
    final excludedSet = exclude != null ? Set<String>.from(exclude) : <String>{};

    final available = _hashtags.where((tag) => !excludedSet.contains(tag)).toList();

    if (cleanQuery.isEmpty) {
      // Jika query kosong, kembalikan rekomendasi default
      return available.take(limit).toList();
    }

    // Prioritaskan yang berawalan (prefix) sama, lalu yang mengandung substring
    final prefixMatches = <String>[];
    final containsMatches = <String>[];

    for (final tag in available) {
      final tagClean = tag.replaceAll('#', '').toLowerCase();
      if (tagClean.startsWith(cleanQuery)) {
        prefixMatches.add(tag);
      } else if (tagClean.contains(cleanQuery)) {
        containsMatches.add(tag);
      }
    }

    prefixMatches.sort((a, b) => a.compareTo(b));
    containsMatches.sort((a, b) => a.compareTo(b));

    return [...prefixMatches, ...containsMatches].take(limit).toList();
  }
}
