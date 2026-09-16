import 'dart:typed_data';
import 'package:flutter/material.dart';

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
/// Perubahan yang dilakukan Admin (tambah/hapus sangkar) akan tersinkronisasi
/// ke seluruh tampilan produk untuk pengguna login maupun umum dan di semua halaman.
class CageService extends ChangeNotifier {
  static final CageService instance = CageService._internal();

  CageService._internal();

  static const List<String> sampleCageImages = [
    'https://images.unsplash.com/photo-1541701494587-cb58502866ab?w=600',
    'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=600',
    'https://images.unsplash.com/photo-1522858547137-f1dcec554f55?w=600',
    'https://images.unsplash.com/photo-1555169062-013468b47731?w=600',
    'https://images.unsplash.com/photo-1535083783855-76ae62b2914e?w=600',
    'https://images.unsplash.com/photo-1516734212186-a967f81ad0d7?w=600',
  ];

  final List<CageData> _cages = [
    const CageData(
      id: '1',
      name: 'Sangkar 1',
      imageUrl: 'https://images.unsplash.com/photo-1541701494587-cb58502866ab?w=600',
    ),
    const CageData(
      id: '2',
      name: 'Sangkar 2',
      imageUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=600',
    ),
    const CageData(
      id: '3',
      name: 'Sangkar 3',
      imageUrl: 'https://images.unsplash.com/photo-1522858547137-f1dcec554f55?w=600',
    ),
    const CageData(
      id: '4',
      name: 'Sangkar 4',
      imageUrl: 'https://images.unsplash.com/photo-1555169062-013468b47731?w=600',
    ),
  ];

  List<CageData> get cages => List.unmodifiable(_cages);

  int get count => _cages.length;

  /// Tambah sangkar baru oleh Admin (tersinkronisasi secara global)
  CageData addCage({String? name, String? imageUrl, Uint8List? imageBytes}) {
    final nextNumber = _cages.length + 1;
    final defaultImage = sampleCageImages[(nextNumber - 1) % sampleCageImages.length];
    final selectedImage = (imageUrl != null && imageUrl.trim().isNotEmpty)
        ? imageUrl.trim()
        : (imageBytes == null ? defaultImage : null);

    final newCage = CageData(
      id: '$nextNumber',
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : 'Sangkar $nextNumber',
      imageUrl: selectedImage,
      imageBytes: imageBytes,
    );
    _cages.add(newCage);
    notifyListeners();
    return newCage;
  }

  /// Hapus sangkar berdasarkan ID (hanya diperbolehkan jika sangkar > 1)
  bool removeCage(String id) {
    if (_cages.length <= 1) return false;
    final index = _cages.indexWhere((c) => c.id == id);
    if (index >= 0) {
      _cages.removeAt(index);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Hapus sangkar berdasarkan Nama (untuk sinkronisasi dari halaman edit produk)
  bool removeCageByName(String name) {
    if (_cages.length <= 1) return false;
    final cleanName = name.trim().toLowerCase();
    final index = _cages.indexWhere((c) => c.name.trim().toLowerCase() == cleanName);
    if (index >= 0) {
      _cages.removeAt(index);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Update data sangkar (nama atau foto / bytes)
  void updateCage({required String id, String? name, String? imageUrl, Uint8List? imageBytes}) {
    final index = _cages.indexWhere((c) => c.id == id);
    if (index >= 0) {
      final old = _cages[index];
      _cages[index] = old.copyWith(
        name: name?.trim(),
        imageUrl: imageUrl?.trim(),
        imageBytes: imageBytes,
      );
      notifyListeners();
    }
  }

  /// Update foto sangkar berdasarkan nama
  void updateCageImageByName(String name, String imageUrl, {Uint8List? imageBytes}) {
    final cleanName = name.trim().toLowerCase();
    final index = _cages.indexWhere((c) => c.name.trim().toLowerCase() == cleanName);
    if (index >= 0) {
      final old = _cages[index];
      _cages[index] = old.copyWith(
        imageUrl: imageUrl.trim(),
        imageBytes: imageBytes,
      );
      notifyListeners();
    }
  }

  /// Reset ke 4 sangkar default
  void resetToDefault() {
    _cages
      ..clear()
      ..addAll([
        const CageData(
          id: '1',
          name: 'Sangkar 1',
          imageUrl: 'https://images.unsplash.com/photo-1541701494587-cb58502866ab?w=600',
        ),
        const CageData(
          id: '2',
          name: 'Sangkar 2',
          imageUrl: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=600',
        ),
        const CageData(
          id: '3',
          name: 'Sangkar 3',
          imageUrl: 'https://images.unsplash.com/photo-1522858547137-f1dcec554f55?w=600',
        ),
        const CageData(
          id: '4',
          name: 'Sangkar 4',
          imageUrl: 'https://images.unsplash.com/photo-1555169062-013468b47731?w=600',
        ),
      ]);
    notifyListeners();
  }
}
