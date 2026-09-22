import 'dart:convert';
import 'package:flutter/material.dart';

/// Helper widget untuk merender gambar pada item jadwal produksi
/// Mendukung:
/// - URL http / https
/// - Data URI Base64 (data:image/...) dari upload file laptop / HP
/// - Fallback placeholder jika kosong atau gagal dimuat
Widget buildScheduleImage(
  String? src, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
}) {
  final defaultPlaceholder = placeholder ??
      Container(
        width: width,
        height: height,
        color: const Color(0xFFF3F4F6),
        child: const Icon(
          Icons.image_outlined,
          size: 22,
          color: Color(0xFF9CA3AF),
        ),
      );

  if (src == null || src.trim().isEmpty) return defaultPlaceholder;
  final clean = src.trim();

  // Dukungan data URI Base64 dari upload perangkat
  if (clean.startsWith('data:image') || (clean.length > 200 && !clean.startsWith('http') && !clean.startsWith('assets/'))) {
    try {
      final commaIdx = clean.indexOf(',');
      final rawB64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
      final normalized = rawB64.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(normalized);
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => defaultPlaceholder,
      );
    } catch (_) {
      return defaultPlaceholder;
    }
  }

  if (clean.startsWith('assets/')) {
    return Image.asset(
      clean,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => defaultPlaceholder,
    );
  }

  return Image.network(
    clean,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => defaultPlaceholder,
  );
}
