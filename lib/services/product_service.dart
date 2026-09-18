import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../supabase_config.dart';

/// Model Produk Khusus Tampilan List Produk User Umum di Dashboard Admin
class AdminPublicProduct {
  final String code;
  final String name;
  final String hashtags;
  final String id;
  final String imageUrl;
  final List<ProductCageVariation>? cageVariations;
  final String? lastEditedDate;

  const AdminPublicProduct({
    required this.code,
    required this.name,
    required this.hashtags,
    this.id = '',
    this.imageUrl = '',
    this.cageVariations,
    this.lastEditedDate,
  });

  String get displayName => '$code-$name';

  AdminPublicProduct copyWith({
    String? code,
    String? name,
    String? hashtags,
    String? id,
    String? imageUrl,
    List<ProductCageVariation>? cageVariations,
    String? lastEditedDate,
  }) {
    return AdminPublicProduct(
      code: code ?? this.code,
      name: name ?? this.name,
      hashtags: hashtags ?? this.hashtags,
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      cageVariations: cageVariations ?? this.cageVariations,
      lastEditedDate: lastEditedDate ?? this.lastEditedDate,
    );
  }
}

/// Layanan terpusat untuk menyimpan & mengelola katalog produk umum.
/// Produk yang ditambahkan oleh Admin melalui Dashboard Admin akan langsung
/// tersimpan di database Supabase (tabel public.produk) dan tersinkronisasi
/// secara real-time ke seluruh aplikasi (Admin & User).
class ProductService extends ChangeNotifier {
  static final ProductService instance = ProductService._internal();

  ProductService._internal();

  // Data katalog awal untuk user umum (dikosongkan dari data dummy)
  final List<Product> _products = [];

  // Data list produk user umum di dashboard admin (dikosongkan dari data dummy)
  final List<AdminPublicProduct> _adminProducts = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<Product> get products => List.unmodifiable(_products);
  List<AdminPublicProduct> get adminProducts => List.unmodifiable(_adminProducts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Mengambil daftar produk dari database Supabase (tabel public.produk)
  Future<void> fetchProducts() async {
    _isLoading = true;
    _errorMessage = null;
    Future.microtask(() => notifyListeners());

    try {
      final List<dynamic> data = await supabase
          .from('produk')
          .select()
          .order('created_at', ascending: false);

      _products.clear();
      _adminProducts.clear();

      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final product = Product.fromMap(item);
          _products.add(product);
          _adminProducts.add(
            AdminPublicProduct(
              code: product.code ?? 'A01',
              name: product.name,
              hashtags: product.hashtags ?? product.category,
              id: product.id,
              imageUrl: product.imageUrl,
              cageVariations: product.cageVariations,
              lastEditedDate: product.lastEditedDate,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ProductService.fetchProducts error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Menambahkan produk baru oleh Admin di Dashboard Admin dan menyimpannya ke Supabase
  Future<Product> addProduct({
    required String name,
    required String code,
    required String hashtags,
    int price = 0,
    String? description,
    String? imageUrl,
    List<ProductCageVariation>? cageVariations,
  }) async {
    final cleanCode = code.trim().isNotEmpty ? code.trim() : 'A0${_products.length + 1}';
    final cleanName = name.trim();
    String formattedHashtags = hashtags.trim();
    if (formattedHashtags.isEmpty) {
      formattedHashtags = '#sangkar #jati #jepara';
    } else if (!formattedHashtags.startsWith('#')) {
      formattedHashtags = '#${formattedHashtags.replaceAll(' ', ' #')}';
    }

    final finalImage = (imageUrl != null && imageUrl.trim().isNotEmpty)
        ? imageUrl.trim()
        : '';

    final finalDescription = (description != null && description.trim().isNotEmpty)
        ? description.trim()
        : 'Sangkar burung ukir berkualitas tinggi buatan pengrajin profesional Jatimas Sangkar.';

    final editDate = _formatCurrentDate();

    final Map<String, dynamic> insertData = {
      'kode': cleanCode,
      'nama': cleanName,
      'harga': price,
      'deskripsi': finalDescription,
      'gambar_url': finalImage,
      'kategori': formattedHashtags,
      'hashtags': formattedHashtags,
      'rating': 4.8,
      'stok': 10,
      'last_edited_date': editDate,
      if (cageVariations != null && cageVariations.isNotEmpty)
        'variasi': cageVariations.map((v) => v.toMap()).toList(),
    };

    String generatedId = 'prod_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Simpan ke database Supabase
    try {
      final List<dynamic> result = await supabase
          .from('produk')
          .insert(insertData)
          .select();

      if (result.isNotEmpty && result.first is Map<String, dynamic>) {
        final saved = result.first as Map<String, dynamic>;
        if (saved['id'] != null) {
          generatedId = saved['id'].toString();
        }
      }
    } catch (e) {
      debugPrint('Error inserting product to Supabase: $e');
      // Lempar error agar caller (AdminAddProductPage) dapat menampilkan SnackBar/informasi yang jelas
      rethrow;
    }

    final newProduct = Product(
      id: generatedId,
      name: cleanName,
      price: price,
      description: finalDescription,
      imageUrl: finalImage,
      category: formattedHashtags,
      code: cleanCode,
      hashtags: formattedHashtags,
      cageVariations: cageVariations,
      lastEditedDate: editDate,
    );

    // 2. Tambahkan ke urutan terdepan katalog user umum agar langsung muncul
    _products.insert(0, newProduct);

    // 3. Tambahkan ke urutan terdepan list produk user umum di dashboard admin
    _adminProducts.insert(
      0,
      AdminPublicProduct(
        code: cleanCode,
        name: cleanName,
        hashtags: formattedHashtags,
        id: generatedId,
        imageUrl: finalImage,
        cageVariations: cageVariations,
        lastEditedDate: editDate,
      ),
    );

    notifyListeners();
    return newProduct;
  }

  /// Mencari produk di katalog umum berdasarkan ID
  Product? findProductById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Memperbarui detail produk oleh Admin di AdminEditProductPage dan menyimpannya ke Supabase
  Future<void> updateProduct({
    required String id,
    required String name,
    required String code,
    String? imageUrl,
    String? hashtags,
    List<ProductCageVariation>? cageVariations,
    String? lastEditedDate,
  }) async {
    final cleanCode = code.trim().isNotEmpty ? code.trim() : 'A01';
    final cleanName = name.trim().isNotEmpty ? name.trim() : 'Produk Sangkar';
    String? cleanHashtags = hashtags?.trim();
    if (cleanHashtags != null && cleanHashtags.isNotEmpty && !cleanHashtags.startsWith('#')) {
      cleanHashtags = '#${cleanHashtags.replaceAll(' ', ' #')}';
    }
    final editDate = (lastEditedDate != null && lastEditedDate.trim().isNotEmpty)
        ? lastEditedDate.trim()
        : _formatCurrentDate();

    // 1. Simpan pembaruan ke Supabase
    try {
      final Map<String, dynamic> updateData = {
        'kode': cleanCode,
        'nama': cleanName,
        'last_edited_date': editDate,
        if (imageUrl != null && imageUrl.trim().isNotEmpty) 'gambar_url': imageUrl.trim(),
        if (cleanHashtags != null) ...{
          'kategori': cleanHashtags,
          'hashtags': cleanHashtags,
        },
        if (cageVariations != null)
          'variasi': cageVariations.map((v) => v.toMap()).toList(),
      };

      await supabase.from('produk').update(updateData).eq('id', id);
    } catch (e) {
      debugPrint('Error updating product in Supabase: $e');
      rethrow;
    }

    // 2. Update di katalog umum (_products)
    final prodIndex = _products.indexWhere((p) => p.id == id);
    if (prodIndex != -1) {
      final old = _products[prodIndex];
      _products[prodIndex] = old.copyWith(
        code: cleanCode,
        name: cleanName,
        imageUrl: (imageUrl != null && imageUrl.trim().isNotEmpty)
            ? imageUrl.trim()
            : old.imageUrl,
        hashtags: cleanHashtags ?? old.hashtags,
        category: cleanHashtags ?? old.category,
        cageVariations: cageVariations ?? old.cageVariations,
        lastEditedDate: editDate,
      );
    }

    // 3. Update di list produk dashboard admin (_adminProducts)
    final adminIndex = _adminProducts.indexWhere((p) => p.id == id);
    if (adminIndex != -1) {
      final old = _adminProducts[adminIndex];
      _adminProducts[adminIndex] = old.copyWith(
        code: cleanCode,
        name: cleanName,
        imageUrl: (imageUrl != null && imageUrl.trim().isNotEmpty)
            ? imageUrl.trim()
            : old.imageUrl,
        hashtags: cleanHashtags ?? old.hashtags,
        cageVariations: cageVariations ?? old.cageVariations,
        lastEditedDate: editDate,
      );
    }

    notifyListeners();
  }

  /// Menghapus produk dari database Supabase dan state aplikasi
  Future<void> deleteProduct(String id) async {
    try {
      await supabase.from('produk').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting product from Supabase: $e');
      rethrow;
    }

    _products.removeWhere((p) => p.id == id);
    _adminProducts.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString();
    return '$day-$month-$year';
  }
}
