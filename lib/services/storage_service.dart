import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_config.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();

  StorageService._internal();

  /// Mengunggah gambar base64 ke Supabase Storage bucket 'katalog'.
  /// Mengembalikan URL publik https://... yang siap digunakan di WhatsApp maupun database.
  /// Jika terjadi kendala jaringan/storage, mengembalikan null secara aman.
  Future<String?> uploadImageIfPossible(String imageSource) async {
    final clean = imageSource.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    if (!clean.startsWith('data:image') && (clean.length <= 100 || clean.startsWith('assets/'))) {
      return null;
    }

    try {
      final commaIdx = clean.indexOf(',');
      final rawB64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
      final normalized = rawB64.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(normalized);

      final isJpg = clean.contains('image/jpeg') || clean.contains('image/jpg');
      final ext = isJpg ? 'jpg' : 'png';
      final mime = isJpg ? 'image/jpeg' : 'image/png';
      final fileName = 'order_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}.$ext';

      final buckets = ['katalog', 'images', 'uploads', 'public', 'photos'];
      for (final bucket in buckets) {
        try {
          await supabase.storage.from(bucket).uploadBinary(
                fileName,
                bytes,
                fileOptions: FileOptions(
                  contentType: mime,
                  upsert: true,
                ),
              );
          final publicUrl = supabase.storage.from(bucket).getPublicUrl(fileName);
          if (publicUrl.isNotEmpty) {
            debugPrint('StorageService: Berhasil upload ke $bucket -> $publicUrl');
            return publicUrl;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('StorageService upload error: $e');
    }
    return null;
  }

  /// Mengunggah file bytes gambar (banner, logo, wallpaper) ke Supabase Storage bucket 'katalog'
  /// dan mengembalikan URL publik permanen https://...
  Future<String?> uploadBytes({
    required Uint8List bytes,
    required String prefix,
    String? originalFilename,
  }) async {
    try {
      final ext = (originalFilename != null &&
              (originalFilename.toLowerCase().endsWith('.jpg') ||
                  originalFilename.toLowerCase().endsWith('.jpeg')))
          ? 'jpg'
          : 'png';
      final mime = ext == 'jpg' ? 'image/jpeg' : 'image/png';
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final fileNames = [
        'settings/${prefix}_$timeStamp.$ext',
        '${prefix}_$timeStamp.$ext',
      ];

      final buckets = ['katalog', 'images', 'uploads', 'public'];
      for (final bucket in buckets) {
        for (final fileName in fileNames) {
          try {
            await supabase.storage.from(bucket).uploadBinary(
                  fileName,
                  bytes,
                  fileOptions: FileOptions(
                    contentType: mime,
                    upsert: true,
                  ),
                );
            final publicUrl = supabase.storage.from(bucket).getPublicUrl(fileName);
            if (publicUrl.isNotEmpty) {
              debugPrint('StorageService: Berhasil upload bytes $prefix ke $bucket/$fileName -> $publicUrl');
              return publicUrl;
            }
          } catch (err) {
            debugPrint('StorageService upload attempt to $bucket/$fileName failed: $err');
          }
        }
      }
    } catch (e) {
      debugPrint('StorageService uploadBytes general error: $e');
    }
    return null;
  }
}

