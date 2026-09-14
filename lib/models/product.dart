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
    return ProductCageVariation(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? map['image_url']?.toString() ?? '',
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
        errorBuilder: (context, error, stackTrace) => defaultPlaceholder,
      );
    }

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => defaultPlaceholder,
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
    final imgVal = map['gambar_url']?.toString() ?? map['imageUrl']?.toString() ?? '';
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

  String get displayName => code != null && code!.isNotEmpty ? '$code-$name' : name;

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

