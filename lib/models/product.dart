import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ProductCageVariation {
  final String id;
  final String name;
  final String imageUrl;
  final Uint8List? imageBytes;

  const ProductCageVariation({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.imageBytes,
  });

  ProductCageVariation copyWith({
    String? id,
    String? name,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    return ProductCageVariation(
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
      'imageUrl': imageUrl,
    };
  }

  factory ProductCageVariation.fromMap(Map<String, dynamic> map) {
    final raw = map['imageUrl']?.toString() ?? map['image_url']?.toString() ?? '';
    final clean = raw.contains('images.unsplash.com') ? '' : raw;
    return ProductCageVariation(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      imageUrl: clean,
    );
  }

  Widget buildImage({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    final defaultPlaceholder = placeholder ??
        const Center(
          child: Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 32),
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

    if (imageUrl.isNotEmpty) {
      return Product.buildImageFromSource(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: defaultPlaceholder,
      );
    }

    return defaultPlaceholder;
  }
}

class Product {
  final String id;
  final String name;
  final int price;
  final String description;
  final String imageUrl;
  final String category;
  final double rating;
  final bool isUserCustom;
  final String? customNote;
  final String? selectedCage;
  final String? code;
  final String? hashtags;
  final List<ProductCageVariation>? cageVariations;
  final String? lastEditedDate;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.category,
    this.rating = 4.8,
    this.isUserCustom = false,
    this.customNote,
    this.selectedCage,
    this.code,
    this.hashtags,
    this.cageVariations,
    this.lastEditedDate,
  });

  Product copyWith({
    String? id,
    String? name,
    int? price,
    String? description,
    String? imageUrl,
    String? category,
    double? rating,
    bool? isUserCustom,
    String? customNote,
    String? selectedCage,
    String? code,
    String? hashtags,
    List<ProductCageVariation>? cageVariations,
    String? lastEditedDate,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      isUserCustom: isUserCustom ?? this.isUserCustom,
      customNote: customNote ?? this.customNote,
      selectedCage: selectedCage ?? this.selectedCage,
      code: code ?? this.code,
      hashtags: hashtags ?? this.hashtags,
      cageVariations: cageVariations ?? this.cageVariations,
      lastEditedDate: lastEditedDate ?? this.lastEditedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kode': code,
      'nama': name,
      'harga': price,
      'deskripsi': description,
      'gambar_url': imageUrl,
      'kategori': category,
      'hashtags': hashtags,
      'rating': rating,
      'stok': 10,
      'variasi': cageVariations?.map((v) => v.toMap()).toList(),
      'last_edited_date': lastEditedDate,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    List<ProductCageVariation>? variations;
    if (map['variasi'] != null && map['variasi'] is List) {
      variations = (map['variasi'] as List)
          .map((v) => ProductCageVariation.fromMap(Map<String, dynamic>.from(v)))
          .toList();
    }

    final codeVal = map['kode']?.toString() ?? map['code']?.toString();
    final nameVal = map['nama']?.toString() ?? map['name']?.toString() ?? 'Produk Sangkar';
    final priceVal = map['harga'] is num
        ? (map['harga'] as num).toInt()
        : (int.tryParse(map['price']?.toString() ?? '') ?? 0);
    final descVal = map['deskripsi']?.toString() ?? map['description']?.toString() ?? '';
    final rawImg = map['gambar_url']?.toString() ?? map['imageUrl']?.toString() ?? '';
    final imgVal = rawImg.contains('images.unsplash.com') ? '' : rawImg;
    final catVal = map['kategori']?.toString() ?? map['category']?.toString() ?? map['hashtags']?.toString() ?? '#sangkar #jati';
    final ratingVal = map['rating'] is num ? (map['rating'] as num).toDouble() : 4.8;
    final hashtagsVal = map['hashtags']?.toString() ?? catVal;
    final lastEditedVal = map['last_edited_date']?.toString() ?? map['lastEditedDate']?.toString();

    return Product(
      id: map['id']?.toString() ?? '',
      name: nameVal,
      price: priceVal,
      description: descVal,
      imageUrl: imgVal,
      category: catVal,
      rating: ratingVal,
      code: codeVal,
      hashtags: hashtagsVal,
      cageVariations: variations,
      lastEditedDate: lastEditedVal,
    );
  }

  /// Mengembalikan daftar hashtag terpisah (misal: ['#sangkar', '#jati', '#serdadu', '#carbon'])
  List<String> get hashtagList {
    final text = (hashtags != null && hashtags!.trim().isNotEmpty)
        ? hashtags!
        : category;
    if (text.trim().isEmpty) return [];
    return text
        .split(RegExp(r'[\s,]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .map((tag) => tag.startsWith('#') ? tag : '#$tag')
        .toList();
  }

  String get displayName {
    if (code == null || code!.trim().isEmpty) return name;
    final c = code!.trim();
    if (name.trim().startsWith(c)) return name;
    return '$c-$name';
  }

  String get formattedPrice {
    // Format harga ke Rupiah
    final priceStr = price.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = priceStr.length - 1; i >= 0; i--) {
      buffer.write(priceStr[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return 'Rp ${buffer.toString().split('').reversed.join('')}';
  }

  Widget buildImage({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    return buildImageFromSource(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
    );
  }

  static final Map<String, Uint8List> _base64Cache = {};

  static Widget buildImageFromSource(
    String src, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    final defaultPlaceholder = placeholder ??
        const Center(
          child: Icon(Icons.image_outlined, color: Colors.grey, size: 28),
        );

    final clean = src.trim();
    if (clean.isEmpty) return defaultPlaceholder;

    if (clean.startsWith('data:image') || (clean.length > 200 && !clean.startsWith('http') && !clean.startsWith('assets/'))) {
      try {
        final commaIdx = clean.indexOf(',');
        final rawB64 = commaIdx != -1 ? clean.substring(commaIdx + 1) : clean;
        final normalized = rawB64.replaceAll(RegExp(r'\s+'), '');
        final bytes = _base64Cache.putIfAbsent(normalized, () => base64Decode(normalized));
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (ctx, err, stack) => defaultPlaceholder,
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
        gaplessPlayback: true,
        errorBuilder: (ctx, err, stack) => defaultPlaceholder,
      );
    }

    return Image.network(
      clean,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return defaultPlaceholder;
      },
      errorBuilder: (ctx, err, stack) => defaultPlaceholder,
    );
  }
}

class CartItem {
  final Product product;
  int quantity;
  final String? cageType;
  String? note;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.cageType,
    this.note,
  });

  int get subtotal => product.price * quantity;
}

/// Daftar katalog awal (Dikosongkan dari data dummy, produk diisi lewat Admin & database Supabase)
final List<Product> sampleProducts = [];

/// Daftar katalog logo custom user login (Dikosongkan dari data dummy)
final List<Product> sampleUserCustomLogos = [];

