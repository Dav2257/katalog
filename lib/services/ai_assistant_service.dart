import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import 'product_service.dart';
import 'settings_service.dart';

class AiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Product>? suggestedProducts;
  final Map<String, dynamic>? pendingOrder;

  AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.suggestedProducts,
    this.pendingOrder,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiResponse {
  final String text;
  final List<Product> suggestedProducts;
  final Map<String, dynamic>? orderData;

  AiResponse({
    required this.text,
    this.suggestedProducts = const [],
    this.orderData,
  });
}

class AiAssistantService extends ChangeNotifier {
  static final AiAssistantService instance = AiAssistantService._internal();

  AiAssistantService._internal();

  // ===========================================================================
  // KONFIGURASI BACKEND AI (Terkunci aman di backend / codingan)
  // Model utama: Nous Hermes 3 (Llama 3.1 8B)
  // ===========================================================================
  static const String backendProvider = 'openrouter'; // 'openrouter' / 'groq'
  static const String backendModel = 'nousresearch/hermes-3-llama-3.1-70b';
  static const String backendGroqModel = 'llama-3.3-70b-versatile';

  // API Key yang bisa diisi dari environment compile-time atau fallback aman
  static String get backendApiKey {
    const envKey = String.fromEnvironment('AI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    try {
      return utf8.decode(base64.decode(
        'c2stb3ItdjEtNWZjMjkxMjQ2MjM0Mzc1YWViMjQ3MGFjYzRjYzg0MTY1ZWNhNWNkM2IwODcxZjRlYWNhMzVhYTJjOTFjMDZh',
      ));
    } catch (_) {
      return '';
    }
  }

  // Keys SharedPreferences lokal (fallback)
  static const String _prefApiKey = 'hermes_ai_api_key';

  String _localApiKey = '';
  final bool _isAutoVoice = true;

  String get apiKey => _localApiKey.isNotEmpty ? _localApiKey : backendApiKey;
  String get provider => backendProvider;
  String get model => backendModel;
  bool get isEnabled => AppSettingsService.instance.aiAssistantEnabled;
  bool get isAutoVoice => _isAutoVoice;
  bool get hasApiKey => apiKey.trim().isNotEmpty;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _localApiKey = prefs.getString(_prefApiKey) ?? '';
      notifyListeners();
    } catch (e) {
      debugPrint('Error init AiAssistantService: $e');
    }
  }

  void setEnabled(bool value) {
    AppSettingsService.instance.updateSettings(aiAssistantEnabled: value);
    notifyListeners();
  }

  /// Membangun konteks katalog toko JatiMas untuk dikirim ke AI
  String _buildStoreContext() {
    final products = ProductService.instance.products;

    final buffer = StringBuffer();
    buffer.writeln('INFORMASI TOKO:');
    buffer.writeln(
      '- Nama Toko: JatiMas Sangkar (Pusat Pengrajin Sangkar Burung Ukir Jepara Asli)',
    );
    buffer.writeln('- Bahan Baku: Kayu Jati Jepara Pilihan Berkualitas Tinggi');
    buffer.writeln(
      '- Layanan Khusus: Menyediakan sangkar siap kirim dan pembuatan sangkar custom ukir (nama, motif anime, logo komunitas, wayang, batik, dll.).',
    );
    buffer.writeln('\nDAFTAR PRODUK YANG TERSEDIA DI KATALOG SAAT INI:');

    if (products.isEmpty) {
      buffer.writeln('- Belum ada produk yang dimuat.');
    } else {
      for (var i = 0; i < products.length; i++) {
        final p = products[i];
        final priceFormatted = p.price > 0
            ? 'Rp ${p.price}'
            : 'Harga Sesuai Spesifikasi/Custom';
        buffer.writeln(
          '${i + 1}. [${p.code ?? '-'}] ${p.name} | Kategori: ${p.category} | Harga: $priceFormatted | ${p.description}',
        );
      }
    }

    return buffer.toString();
  }

  /// Mengirim pesan ke Hermes AI (atau offline engine jika API Key belum ada)
  Future<AiResponse> sendMessage(
    String userText, {
    List<AiChatMessage> history = const [],
  }) async {
    final trimmed = userText.trim();
    if (trimmed.isEmpty) {
      return AiResponse(
        text: 'Maaf, saya tidak mendengar suara atau pesan Anda.',
      );
    }

    // Jika belum mengisi API Key, gunakan Offline NLP Engine cerdas JatiMas
    if (!hasApiKey) {
      return _generateSmartOfflineResponse(trimmed);
    }

    try {
      if (provider == 'groq') {
        return await _callGroqApi(trimmed, history);
      } else {
        // Default OpenRouter (Hermes 3 / Hermes 2 Pro)
        return await _callOpenRouterApi(trimmed, history);
      }
    } catch (e) {
      debugPrint(
        'Gagal memanggil API AI: $e. Beralih ke respons cerdas lokal.',
      );
      return _generateSmartOfflineResponse(trimmed);
    }
  }

  /// Membangun Prompt Sistem terpadu untuk AI
  String _getSystemPrompt() {
    return '''
Kamu adalah "JatiMas AI Asisten", pramuniaga cerdas, sopan, dan ramah dari toko JatiMas Sangkar Jepara (Pusat Pengrajin Sangkar Burung Kayu Jati Jepara Asli).

TUGAS UTAMAMU:
1. Membantu pelanggan mencari dan merekomendasikan produk sangkar burung yang ada di katalog toko JatiMas (Murai, Kacer, Cucak Ijo, Pleci, Anis Merah, Sangkar Ukir Jepara, Tebok Lovebird, dll.).
2. Menjelaskan detail produk katalog, bahan kayu jati pilihan, motif ukiran yang sudah tersedia, dan keunggulan kualitas toko JatiMas.
3. Membantu pelanggan memilih produk yang sesuai dan menjelaskan bahwa pemesanan hanya untuk produk katalog yang tersedia.

GAYA PERCAKAPAN (WAJIB DIPATUHI):
- Jawab secara interaktif, santai, dan alami seperti mengobrol langsung (panggil "kak" atau "om").
- DILARANG KERAS MENGGUNAKAN SALAM PENUTUP SURAT:
  Jangan pernah menulis salam penutup formal seperti:
  "Terima kasih,"
  "JatiMas AI Asisten"
  "WhatsApp: ..."
  karena ini obrolan chat interaktif, bukan surat atau email. Pelanggan baru sedang bertanya dan belum menyelesaikan pesanan. Tombol WhatsApp dan keranjang belanja sudah tersedia otomatis di layar aplikasi, sehingga kamu TIDAK PERLU mencantumkan tanda tangan atau nomor telepon di akhir balasan.

ATURAN KATALOG & BATASAN PEMESANAN (SANGAT PENTING & MUTLAK DIPATUHI):
1. PELANGGAN UMUM HANYA BISA MEMESAN DARI PRODUK YANG SUDAH ADA DI KATALOG TOKO:
   - DILARANG KERAS mengatakan bahwa pelanggan bisa membuat logo sendiri, mendesain motif baru, atau memesan model sangkar baru dari nol/awal!
   - Toko JatiMas TIDAK MELAYANI pembuatan model/desain dari nol untuk pembeli umum.
   - Pembeli umum HANYA BISA MEMILIH PRODUK YANG SUDAH TERSEDIA di katalog toko JatiMas (misalnya produk tebok OnePiece [A05] Excellent OnePiece, Serdadu Carbon, Sangkar Murai, dll.).
   - Jangan pernah bertanya "nama karakter apa yang ingin diukir" atau "jenis tebok apa yang ingin dibuat dari nol". Sebaliknya, sebutkan produk katalog yang cocok dengan tema yang dicari.
2. FUNGSI KOLOM CATATAN (NOTES):
   - Kolom catatan HANYA DIGUNAKAN ketika pelanggan ingin menambahkan sedikit tulisan atau inisial pada produk katalog yang mereka pilih.
   - Contoh catatan yang diperbolehkan: "ini di samping karakternya di tambah tulisan GB", atau penambahan inisial nama pemilik burung pada produk tersebut.
   - Jika pelanggan bertanya tentang custom, jelaskan dengan sopan: "Pemesanan di JatiMas dilakukan dengan memilih produk yang tersedia di katalog kami kak (tidak bisa membuat desain/model baru dari awal). Namun jika kakak ingin sedikit tambahan tulisan pada produk yang dipilih (misal di samping karakternya ditambah tulisan inisial nama), kakak bisa menuliskannya di kolom Catatan saat memesan."
3. DILARANG MEMINTA ALAMAT PENGIRIMAN:
   - JANGAN PERNAH meminta alamat pengiriman kepada pembeli dalam percakapan! Alamat pengiriman akan diisi pelanggan sendiri nanti pada formulir checkout di keranjang belanja.

ATURAN PILIHAN PRODUK & PEMESANAN (SANGAT KETAT):
1. JANGAN PERNAH MENYIMPULKAN 1 PRODUK TERTENTU jika pelanggan hanya menanyakan tema umum, jenis, atau motif (contoh: "tebok anime", "motif naga", "sangkar murai", "sangkar lovebird", "mau pesan sangkar", "carbon").
   - DILARANG MENGELUARKAN TAG ORDER_JSON untuk pertanyaan atau pencarian produk umum!
   - Berikan rekomendasi ramah dan sebutkan beberapa pilihan sangkar yang relevan yang ada di katalog toko JatiMas dengan format bernomor:
     1. [Kode] Nama Produk - Penjelasan singkat keunikan motif atau keistimewaan sangkar ini.
     2. [Kode] Nama Produk - Penjelasan singkat keunikan motif atau keistimewaan sangkar ini.
   - Sistem aplikasi kami akan secara otomatis mengubah daftar tersebut menjadi KARTU PRODUK INTERAKTIF LENGKAP DENGAN FOTO ASLI KATALOG DAN PENJELASAN TERSEBUT.
2. HANYA keluarkan tag <<<ORDER_JSON...>>> JIKA DAN HANYA JIKA pelanggan SUDAH SECARA EKSPLISIT DAN TEGAS menyebut nama atau kode produk spesifik yang sudah pasti ingin dibeli (misal: "Saya mau beli yang [A05] Excellent OnePiece", "Pesan [A01] Sangkar Murai 1 pcs"). Jika masih eksplorasi atau belum memilih produk pasti, JANGAN gunakan ORDER_JSON!
<<<ORDER_JSON{"action":"add_to_cart","productName":"Nama Lengkap Sangkar Sesuai Katalog","quantity":1,"note":"Pemesanan via AI"}ORDER_JSON>>>

${_buildStoreContext()}
''';
  }

  /// Panggilan ke OpenRouter API (Hermes AI)
  Future<AiResponse> _callOpenRouterApi(
    String userText,
    List<AiChatMessage> history,
  ) async {
    final systemPrompt = _getSystemPrompt();

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    // Sertakan 4 pesan terakhir untuk riwayat konteks
    final recentHistory = history.length > 4
        ? history.sublist(history.length - 4)
        : history;
    for (final msg in recentHistory) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      });
    }

    messages.add({'role': 'user', 'content': userText});

    final candidateModels = [
      model,
      if (model != 'nousresearch/hermes-3-llama-3.1-70b') 'nousresearch/hermes-3-llama-3.1-70b',
      'nvidia/nemotron-3.5-lightning:free',
      'google/gemma-4-31b-it:free',
    ];

    for (final candidate in candidateModels) {
      try {
        final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
        final response = await http
            .post(
              url,
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://jatimas-sangkar.com',
                'X-Title': 'JatiMas AI Voice Assistant',
              },
              body: jsonEncode({
                'model': candidate,
                'messages': messages,
                'temperature': 0.7,
                'max_tokens': 450,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final json =
              jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['message']?['content']?.toString() ?? '';
            return _parseAiOutput(content, userText);
          }
        } else {
          debugPrint('Model OpenRouter $candidate returned code ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('Error trying OpenRouter model $candidate: $e');
      }
    }

    throw Exception('Semua model OpenRouter sedang sibuk atau memerlukan kredit.');
  }

  /// Panggilan ke Groq API (Inference super cepat)
  Future<AiResponse> _callGroqApi(
    String userText,
    List<AiChatMessage> history,
  ) async {
    final systemPrompt = _getSystemPrompt();

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    final recentHistory = history.length > 4
        ? history.sublist(history.length - 4)
        : history;
    for (final msg in recentHistory) {
      messages.add({
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      });
    }
    messages.add({'role': 'user', 'content': userText});

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': backendGroqModel,
            'messages': messages,
            'temperature': 0.7,
            'max_tokens': 400,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final content = choices[0]['message']?['content']?.toString() ?? '';
        return _parseAiOutput(content, userText);
      }
    }

    throw Exception(
      'Groq API returned code ${response.statusCode}: ${response.body}',
    );
  }

  /// Ekstraksi tag ORDER_JSON dan mencocokkan produk rekomendasi
  AiResponse _parseAiOutput(String rawContent, String originalQuery) {
    String cleanText = rawContent;
    Map<String, dynamic>? orderData;

    final regex = RegExp(r'<<<ORDER_JSON(.*?)ORDER_JSON>>>', dotAll: true);
    final match = regex.firstMatch(rawContent);
    if (match != null) {
      try {
        final jsonStr = match.group(1)?.trim() ?? '';
        orderData = jsonDecode(jsonStr) as Map<String, dynamic>?;
        cleanText = rawContent.replaceAll(regex, '').trim();
      } catch (e) {
        debugPrint('Error parsing order JSON from AI: $e');
      }
    }

    // 1. Bersihkan penutup surat formal (Terima kasih, JatiMas AI Asisten, WhatsApp)
    cleanText = cleanText
        .replaceAll(
          RegExp(
            r'\n+\s*(?:Terima kasih|Salam hangat|Hormat kami)[,\.\!]?\s*(?:\n+JatiMas\s*AI\s*(?:Asisten)?)?\s*(?:\n+(?:Kontak|WhatsApp|WA):?\s*[\d\+\s\-]+)?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\n+\s*JatiMas\s*AI\s*(?:Asisten)?\s*(?:\n+(?:Kontak|WhatsApp|WA):?\s*[\d\+\s\-]+)?\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\n+\s*(?:Kontak|WhatsApp|WA):?\s*[\d\+\s\-]+$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'\n+\s*Terima kasih[,\.\!]?\s*$', caseSensitive: false),
          '',
        )
        // 2. Bersihkan jika AI tidak sengaja menanyakan alamat pengiriman di poin chat
        .replaceAll(
          RegExp(
            r'\s*(?:dan\s+|serta\s+)?alamat\s+(?:lengkap\s+)?(?:pengiriman|rumah)?\s*',
            caseSensitive: false,
          ),
          ' ',
        )
        .trim();

    // Ekstrak rekomendasi produk beserta penjelasannya langsung dari teks jawaban AI
    final extractedProducts = _extractRecommendedProductsFromAiText(cleanText);
    List<Product> matchedProducts;

    if (extractedProducts.isNotEmpty) {
      matchedProducts = extractedProducts;

      // Hapus baris-baris daftar teks "1. [A05] ... | Penjelasan" dari balon obrolan
      // agar langsung digantikan oleh kartu produk visual bergambar lengkap dengan penjelasannya
      cleanText = cleanText.replaceAll(
        RegExp(
          r'(?:^|\n)\s*(?:\d+[\.\)]|\-|\*)\s*(?:[\[\(][A-Za-z0-9]+[\]\)]|[A-Za-z]\d{1,4}\b)?\s*[^|\n:\-–—]+?\s*(?:\||[-:–—])\s*[^\n]+(?:\n(?!\s*(?:\d+[\.\)]|\-|\*|\n))[^\n]+)*',
          multiLine: true,
        ),
        '',
      );

      // Bersihkan baris kosong berlebih
      cleanText = cleanText.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

      if (cleanText.isEmpty) {
        cleanText = 'Berikut pilihan sangkar yang cocok untuk kakak:';
      }
    } else {
      matchedProducts = _findRelevantProducts('$originalQuery $cleanText')
          .take(3)
          .map((p) => p.copyWith(
                customNote: p.description.trim().isNotEmpty
                    ? p.description.trim()
                    : 'Sangkar kayu jati pilihan khas JatiMas Jepara dengan ukiran halus.',
              ))
          .toList();
    }

    // Pengaman: Jangan tampilkan ringkasan pesanan sepihak jika user hanya menanyakan info/kategori/tema umum
    if (orderData != null) {
      final qLower = originalQuery.toLowerCase();
      final hasOrderIntent = qLower.contains('pesan') ||
          qLower.contains('beli') ||
          qLower.contains('order') ||
          qLower.contains('keranjang') ||
          qLower.contains('checkout') ||
          qLower.contains('ambil');

      final prodName =
          (orderData['productName'] ?? '').toString().toLowerCase();
      final hasExactProdMention = prodName.isNotEmpty &&
          (qLower.contains(prodName) ||
              (matchedProducts.isNotEmpty &&
                  matchedProducts.any(
                    (p) =>
                        p.code != null &&
                        p.code!.isNotEmpty &&
                        qLower.contains(p.code!.toLowerCase()),
                  )));

      // Jika user tidak berniat pesan langsung atau tidak menyebut produk spesifik, berikan opsi produk saja
      if (!hasOrderIntent && !hasExactProdMention) {
        orderData = null;
      }
    }

    return AiResponse(
      text: cleanText,
      suggestedProducts: matchedProducts,
      orderData: orderData,
    );
  }

  /// Mengekstrak produk rekomendasi bernomor beserta penjelasan motifnya dari teks AI
  List<Product> _extractRecommendedProductsFromAiText(String text) {
    final allProducts = ProductService.instance.products;
    if (allProducts.isEmpty) return [];

    final result = <Product>[];
    final seenIds = <String>{};

    // Regex mencocokkan pola rekomendasi bernomor/poin dengan berbagai pemisah (| atau - atau : atau – atau —):
    // Contoh 1: 1. [A05] Excellent OnePiece | Sangkar ukir berkualitas tinggi dengan motif karakter OnePiece...
    // Contoh 2: 1. [A18] Serdadu Carbon - Sangkar ini memiliki motif...
    // Contoh 3: 2. [A15] Ebod Diamond Onepiece: Motif karakter...
    final itemRegex = RegExp(
      r'(?:^|\n)\s*(?:\d+[\.\)]|\-|\*)\s*(?:[\[\(]([A-Za-z0-9]+)[\]\)]|([A-Za-z]\d{1,4})\b)?\s*([^|\n:\-–—]+?)\s*(?:\||[-:–—])\s*([^\n]+(?:\n(?!\s*(?:\d+[\.\)]|\-|\*|\n))[^\n]+)*)',
      multiLine: true,
    );

    final matches = itemRegex.allMatches(text);
    for (final match in matches) {
      final codeGroup = (match.group(1) ?? match.group(2))?.trim();
      final nameGroup = match.group(3)?.trim();
      final explanationGroup = match.group(4)?.trim();

      Product? matched;

      // 1. Prioritas cari berdasarkan kode produk (cth: A05, A15, A17, A18, A20)
      if (codeGroup != null && codeGroup.isNotEmpty) {
        final cLower = codeGroup.toLowerCase();
        try {
          matched = allProducts.firstWhere(
            (p) => p.code != null && p.code!.toLowerCase() == cLower,
          );
        } catch (_) {}
      }

      // 2. Jika belum ketemu, cari apakah kode produk ada di dalam nameGroup
      if (matched == null && nameGroup != null && nameGroup.isNotEmpty) {
        final nLower = nameGroup.toLowerCase();
        try {
          matched = allProducts.firstWhere(
            (p) =>
                p.code != null &&
                p.code!.isNotEmpty &&
                RegExp(r'\b' + RegExp.escape(p.code!.toLowerCase()) + r'\b')
                    .hasMatch(nLower),
          );
        } catch (_) {}
      }

      // 3. Jika belum ketemu, cari berdasarkan nama produk
      if (matched == null && nameGroup != null && nameGroup.isNotEmpty) {
        final cleanName = nameGroup
            .replaceAll(RegExp(r'^[-:–—\s]+|[-:–—\s]+$'), '')
            .toLowerCase();
        try {
          matched = allProducts.firstWhere(
            (p) =>
                p.name.toLowerCase() == cleanName ||
                p.name.toLowerCase().contains(cleanName) ||
                cleanName.contains(p.name.toLowerCase()),
          );
        } catch (_) {}
      }

      if (matched != null && !seenIds.contains(matched.id)) {
        seenIds.add(matched.id);
        final explanation =
            (explanationGroup != null && explanationGroup.isNotEmpty)
                ? explanationGroup
                : (matched.description.isNotEmpty
                    ? matched.description
                    : 'Sangkar kayu jati pilihan khas JatiMas Jepara.');
        result.add(matched.copyWith(customNote: explanation));
      }
    }

    return result;
  }

  /// Smart Offline / Demo Engine jika API Key belum diisi
  AiResponse _generateSmartOfflineResponse(String query) {
    final lower = query.toLowerCase();
    final allProducts = ProductService.instance.products;
    final phone = AppSettingsService.instance.adminWhatsApp;

    // 1. Sapaan / Salam
    if (lower.contains('halo') ||
        lower.contains('hai') ||
        lower.contains('selamat') ||
        lower.contains('pagi') ||
        lower.contains('siang') ||
        lower.contains('malam') ||
        lower.contains('assalamu')) {
      return AiResponse(
        text:
            'Halo kak! Selamat datang di JatiMas Sangkar Jepara. Ada yang bisa saya bantu? Kakak bisa tanyakan motif sangkar, cek harga, atau langsung pesan via suara/teks.',
        suggestedProducts: allProducts.take(2).toList(),
      );
    }

    // 2. Pertanyaan Custom / Logo Pribadi
    // 2. Pertanyaan Custom / Logo / Desain Sendiri
    if (lower.contains('custom') ||
        lower.contains('logo') ||
        lower.contains('ukir nama') ||
        lower.contains('desain sendiri') ||
        lower.contains('buat baru') ||
        lower.contains('buat dari awal')) {
      final relevant = _findRelevantProducts(lower);
      return AiResponse(
        text:
            'Pemesanan di JatiMas dilakukan dengan memilih produk sangkar yang tersedia di katalog kami kak (tidak bisa membuat model/desain baru dari awal). Namun jika kakak ingin sedikit tambahan tulisan pada produk katalog yang dipilih (contoh: di samping karakternya ditambah tulisan "GB" atau inisial nama), kakak bisa menuliskannya di kolom Catatan saat memesan.',
        suggestedProducts: relevant.isNotEmpty
            ? relevant.take(3).toList()
            : allProducts.take(3).toList(),
      );
    }

    // 3. Niat Pemesanan / Order / Masukkan Keranjang
    if (lower.contains('pesan') ||
        lower.contains('beli') ||
        lower.contains('order') ||
        lower.contains('keranjang') ||
        lower.contains('taruh') ||
        lower.contains('checkout')) {
      final relevant = _findRelevantProducts(lower);
      if (relevant.isNotEmpty) {
        // Cek apakah query spesifik menyebut kode produk atau nama lengkap persis
        final isExactSpecific = relevant.any((p) =>
            (p.code != null && lower.contains(p.code!.toLowerCase())) ||
            lower.contains(p.name.toLowerCase()));

        // Jika ada lebih dari 1 pilihan produk dan belum spesifik, tampilkan opsi produk!
        if (relevant.length > 1 && !isExactSpecific) {
          final productsWithExplanations = relevant.take(4).map((item) {
            final explanation = item.description.trim().isNotEmpty
                ? item.description.trim()
                : 'Sangkar kayu jati Jepara berkualitas tinggi dengan ukiran ${item.name}.';
            return item.copyWith(customNote: explanation);
          }).toList();

          return AiResponse(
            text:
                'Ada beberapa opsi sangkar yang cocok dengan pencarian Anda kak. Silakan pilih sangkar di bawah ini:',
            suggestedProducts: productsWithExplanations,
          );
        }

        final p = relevant.first;
        int quantity = 1;
        final qtyMatch = RegExp(r'(\d+)\s*(pcs|buah|biji|ekor|sangkar|item)?').firstMatch(lower);
        if (qtyMatch != null) {
          quantity = int.tryParse(qtyMatch.group(1) ?? '1') ?? 1;
          if (quantity <= 0) quantity = 1;
        }

        return AiResponse(
          text:
              'Siap kak! Produk "${p.name}" (sebanyak $quantity pcs) siap diproses. Anda bisa melengkapi catatan, nama, atau langsung masukkan ke keranjang/WhatsApp.',
          suggestedProducts: relevant.take(4).toList(),
          orderData: {
            'action': 'add_to_cart',
            'productName': p.name,
            'quantity': quantity,
            'note': 'Dipesan via AI Asisten JatiMas',
          },
        );
      } else {
        return AiResponse(
          text:
              'Baik kak! Boleh sebutkan nama sangkar apa yang ingin dimasukkan ke keranjang? Contoh: "Pesan sangkar murai 1 pcs" atau "Beli sangkar ukir naga".',
          suggestedProducts: allProducts.take(3).toList(),
        );
      }
    }

    // 4. Tanya Harga / Biaya
    if (lower.contains('harga') ||
        lower.contains('berapa') ||
        lower.contains('biaya') ||
        lower.contains('ongkir')) {
      final matched = _findRelevantProducts(lower);
      if (matched.isNotEmpty) {
        final p = matched.first;
        final price = p.price > 0
            ? 'Rp ${p.price}'
            : 'menyesuaikan spesifikasi custom';
        return AiResponse(
          text:
              'Untuk produk "${p.name}", harganya adalah $price dengan pengerjaan kayu jati Jepara pilihan kak.',
          suggestedProducts: matched.take(2).toList(),
        );
      } else {
        return AiResponse(
          text:
              'Harga sangkar di JatiMas sangat bervariasi tergantung ukuran dan tingkat kerumitan ukiran jati Jepara. Sangkar apa yang ingin kakak cek harganya?',
          suggestedProducts: allProducts.take(3).toList(),
        );
      }
    }

    // 5. Pencarian Produk Berdasarkan Kata Kunci
    final matched = _findRelevantProducts(lower);
    if (matched.isNotEmpty) {
      final productsWithExplanations = matched.take(3).map((item) {
        final explanation = item.description.trim().isNotEmpty
            ? item.description.trim()
            : 'Sangkar kayu jati Jepara pilihan dengan ukiran khas ${item.name}.';
        return item.copyWith(customNote: explanation);
      }).toList();

      return AiResponse(
        text:
            'Berikut beberapa pilihan sangkar yang cocok dengan pencarian "$query" di katalog JatiMas kak:',
        suggestedProducts: productsWithExplanations,
      );
    }

    // 6. Default Fallback
    return AiResponse(
      text:
          'Saya siap membantu kak. Kakak bisa tanyakan seperti: "Cari sangkar murai", "Berapa harga sangkar jati?", atau "Saya mau pesan sangkar". Kakak juga bisa hubungi langsung WhatsApp kami di $phone.',
      suggestedProducts: allProducts.take(2).toList(),
    );
  }

  List<Product> _findRelevantProducts(String text) {
    final lower = text.toLowerCase();
    final all = ProductService.instance.products;
    final keywords = lower
        .split(RegExp(r'[\s,\.\?!]+'))
        .map((k) => k.trim())
        .where((k) => k.length >= 3)
        .toList();

    return all.where((p) {
      final name = p.name.toLowerCase();
      final cat = p.category.toLowerCase();
      final desc = p.description.toLowerCase();
      final code = (p.code ?? '').toLowerCase();
      final tags = (p.hashtags ?? '').toLowerCase();

      // Cocok langsung seluruh nama atau kode
      if (lower.contains(name) || name.contains(lower)) return true;
      if (code.isNotEmpty && lower.contains(code)) return true;

      // Cocok jika ada kata kunci yang relevan
      for (final kw in keywords) {
        if (name.contains(kw) ||
            cat.contains(kw) ||
            desc.contains(kw) ||
            tags.contains(kw)) {
          return true;
        }
      }

      // Kategori spesifik umum
      if (lower.contains('murai') && (name.contains('murai') || cat.contains('murai'))) return true;
      if (lower.contains('kacer') && (name.contains('kacer') || cat.contains('kacer'))) return true;
      if (lower.contains('cucak') && (name.contains('cucak') || cat.contains('cucak'))) return true;
      if (lower.contains('pleci') && (name.contains('pleci') || cat.contains('pleci'))) return true;
      if (lower.contains('lovebird') && (name.contains('lovebird') || cat.contains('lovebird') || name.contains('tebok'))) return true;
      if (lower.contains('tebok') && (name.contains('tebok') || cat.contains('tebok') || desc.contains('tebok'))) return true;
      if (lower.contains('anime') && (name.contains('anime') || desc.contains('anime') || name.contains('onepiece') || name.contains('naruto'))) return true;
      if (lower.contains('jati') && (desc.contains('jati') || name.contains('jati'))) return true;
      if (lower.contains('ukir') && (desc.contains('ukir') || name.contains('ukir'))) return true;

      return false;
    }).toList();
  }
}
