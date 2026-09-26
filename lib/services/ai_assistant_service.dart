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
      return _generateSmartOfflineResponse(trimmed, history: history);
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
      return _generateSmartOfflineResponse(trimmed, history: history);
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
- JIKA PELANGGAN HANYA MENYAPA (misal "halo", "hai", "selamat pagi", "permisi", "assalamu'alaikum") ATAU OBROLAN UMUM/SANTAI (misal "terima kasih", "kamu siapa", "tokonya buka jam berapa"):
  CUKUP BALAS DENGAN RAMAH DAN TANYAKAN APA YANG BISA DIBANTU.
  DILARANG KERAS MENYEBUTKAN/MENYODORKAN DAFTAR REKOMENDASI PRODUK (1. [Kode] Nama Produk...) JIKA PELANGGAN BELUM MENANYAKAN ATAU MENCARI PRODUK TERTENTU!
- JIKA PELANGGAN MENANYAKAN PENDAPAT / REVIEW / KONSULTASI (contoh: "menurutmu kalau yang ebod bagus untuk sehari-hari ngga?", "bagusan mana?", "cocok buat harian ngga?", "kelebihannya apa?"):
  CUKUP SAMPAIKAN PENDAPAT, ANALISIS, DAN SARANMU SEBAGAI AHLI SANGKAR JATIMAS DALAM TEKS OBROLAN YANG RAMAH DAN JELAS.
  DILARANG KERAS MENGELUARKAN DAFTAR PRODUK ATAU TAG ORDER_JSON KARENA PELANGGAN HANYA MEMINTA PENDAPATMU, BUKAN MEMINTA KATALOG PRODUK!
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

    final isOpinion = _isAskingOpinion(originalQuery);
    if (isOpinion) {
      // Pengguna hanya menanyakan pendapat/review/saran, jangan tampilkan kartu produk atau order
      return AiResponse(
        text: cleanText,
        suggestedProducts: [],
        orderData: null,
      );
    }

    final hasProductIntent = _hasProductOrOrderIntent(originalQuery);

    // Ekstrak rekomendasi produk beserta penjelasannya langsung dari teks jawaban AI
    final extractedProducts = _extractRecommendedProductsFromAiText(cleanText);
    List<Product> matchedProducts;

    if (hasProductIntent) {
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
        matchedProducts = _findRelevantProducts(originalQuery)
            .take(3)
            .map((p) => p.copyWith(
                  customNote: p.description.trim().isNotEmpty
                      ? p.description.trim()
                      : 'Sangkar kayu jati pilihan khas JatiMas Jepara dengan ukiran halus.',
                ))
            .toList();
      }
    } else {
      // Obrolan umum/sapaan/santai yang tidak ada hubungan dengan produk:
      // JANGAN tampilkan produk rekomendasi sama sekali
      matchedProducts = [];
      orderData = null;
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

  static const Set<String> _stopWords = {
    'mau', 'ada', 'yang', 'bisa', 'kak', 'om', 'saya', 'aku', 'kami', 'kita',
    'dan', 'atau', 'ini', 'itu', 'di', 'ke', 'dari', 'pada', 'untuk', 'dengan',
    'dong', 'ya', 'kan', 'nih', 'tuh', 'saja', 'aja', 'punya', 'apakah', 'gimana',
    'bagaimana', 'kenapa', 'mengapa', 'tolong', 'minta', 'coba', 'halo', 'hai',
    'selamat', 'pagi', 'siang', 'sore', 'malam', 'terima', 'kasih', 'makasih',
    'kalau', 'klo', 'kl', 'kalo', 'apa', 'mana', 'udah', 'sudah', 'belum', 'blm',
    'kok', 'sih', 'deh', 'lah', 'loh', 'mas', 'bang', 'gan', 'min', 'admin',
    'gw', 'gue', 'lu', 'lo', 'bro', 'sis', 'terus', 'trus', 'lalu',
    'cari', 'mencari', 'lihat', 'pengen', 'ingin',
  };

  /// Memeriksa apakah pesan pengguna memiliki maksud mencari, menanyakan, atau memesan produk
  bool _hasProductOrOrderIntent(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return false;

    // 1. Kata kunci pemesanan / transaksi langsung
    const orderKeywords = [
      'pesan', 'beli', 'order', 'keranjang', 'checkout', 'ambil', 'mau yang', 'bungkus', 'keep'
    ];
    for (final kw in orderKeywords) {
      if (lower.contains(kw)) return true;
    }

    // 2. Kata kunci harga & ketersediaan
    const inquiryKeywords = [
      'harga', 'berapa', 'biaya', 'ongkir', 'tarif', 'diskon', 'promo', 'murah', 'stok', 'ready'
    ];
    for (final kw in inquiryKeywords) {
      if (lower.contains(kw)) return true;
    }

    // 3. Kata kunci rekomendasi, perbandingan, atau mencari alternatif lain
    const recommendationKeywords = [
      'rekomendasi', 'rekomendasikan', 'recomendasi', 'recomended', 'recommend',
      'yang lain', 'yg lain', 'pilihan lain', 'opsi lain', 'model lain', 'motif lain',
      'varian lain', 'tipe lain', 'selain ini', 'selain itu', 'ada lagi', 'apa lagi',
      'cari yang', 'mau yang', 'lihat yang', 'tampilkan yang', 'tunjukin yang',
      'kalau yang', 'klo yang', 'kalo yang', 'kl yang', 'gimana kalau yang',
      'katalog', 'pilihan produk', 'daftar produk', 'produk', 'koleksi'
    ];
    for (final kw in recommendationKeywords) {
      if (lower.contains(kw)) return true;
    }

    // 4. Kata kunci kategori burung / sangkar / motif umum
    const productKeywords = [
      'sangkar', 'kandang', 'tebok', 'burung',
      'murai', 'kacer', 'cucak', 'pleci', 'lovebird', 'anis', 'kenari', 'branjangan', 'cendet', 'gelatik',
      'motif', 'ukir', 'ukiran', 'carbon', 'adidas', 'onepiece', 'one piece', 'naruto', 'anime', 'serdadu', 'naga', 'wayang', 'batik',
    ];
    for (final kw in productKeywords) {
      if (lower.contains(kw)) return true;
    }

    // 5. Cek kode produk (contoh A01, A05, A20, dll.)
    if (RegExp(r'\b[a-zA-Z]\d{1,4}\b').hasMatch(lower)) {
      return true;
    }

    // 6. Cek kecocokan dinamis dengan kata-kata dalam nama produk di katalog
    // Contoh: user ketik "kalau yang excellent", kata "excellent" cocok dengan nama produk "Excellent OnePiece"!
    final allProducts = ProductService.instance.products;
    final words = lower
        .split(RegExp(r'[\s,\.\?!/\-]+'))
        .map((w) => w.trim())
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();

    for (final p in allProducts) {
      if (p.code != null && p.code!.isNotEmpty && lower.contains(p.code!.toLowerCase())) {
        return true;
      }
      final pNameLower = p.name.toLowerCase();
      final pDescLower = p.description.toLowerCase();
      final pCatLower = p.category.toLowerCase();
      final pTagsLower = (p.hashtags ?? '').toLowerCase();

      for (final w in words) {
        if (pNameLower.contains(w) ||
            pCatLower.contains(w) ||
            pTagsLower.contains(w) ||
            (pDescLower.contains(w) && w.length >= 4)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Memeriksa apakah pengguna sedang menanyakan pendapat / review / evaluasi sangkar
  bool _isAskingOpinion(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) return false;

    // Pola pertanyaan pendapat eksplisit
    const opinionPatterns = [
      'menurutmu', 'menurut kamu', 'menurut lu', 'menurut mu', 'menurut anda',
      'pendapatmu', 'pendapat kamu', 'gimana menurut', 'bagaimana menurut',
      'bagus ngga', 'bagus gak', 'bagus tidak', 'bagus gk', 'bagus ga', 'baguskah',
      'cocok ngga', 'cocok gak', 'cocok tidak', 'cocok ga', 'cocokkah',
      'awet ngga', 'awet gak', 'awet tidak', 'kuat ngga', 'tahan lama ngga',
      'bagusan mana', 'bagus mana', 'lebih bagus mana', 'mending mana', 'mending yang',
      'kelebihan', 'kekurangan', 'keunggulan', 'kelemahan',
      'worth it', 'recomended ngga', 'recommended ngga',
    ];

    for (final pattern in opinionPatterns) {
      if (lower.contains(pattern)) return true;
    }

    // Kombinasi kata evaluasi dengan kata tanya/ragu
    final hasEvalWord = lower.contains('bagus') ||
        lower.contains('cocok') ||
        lower.contains('enak') ||
        lower.contains('kuat') ||
        lower.contains('awet') ||
        lower.contains('layak') ||
        lower.contains('mending');
    final hasQuestionDoubt = lower.contains('ngga') ||
        lower.contains('gak') ||
        lower.contains('ga') ||
        lower.contains('tidak') ||
        lower.contains('apakah') ||
        lower.contains('gimana') ||
        lower.contains('bagaimana');

    if (hasEvalWord && hasQuestionDoubt) {
      if (!lower.contains('pesan') && !lower.contains('beli') && !lower.contains('order')) {
        return true;
      }
    }

    // Evaluasi spesifik harian vs lomba
    if ((lower.contains('sehari hari') || lower.contains('sehari-hari') || lower.contains('harian')) &&
        (lower.contains('bagus') || lower.contains('cocok') || lower.contains('bisa') || lower.contains('enak'))) {
      return true;
    }

    return false;
  }

  /// Smart Offline / Demo Engine jika API Key belum diisi
  AiResponse _generateSmartOfflineResponse(
    String query, {
    List<AiChatMessage> history = const [],
  }) {
    final lower = query.toLowerCase().trim();
    final allProducts = ProductService.instance.products;
    final phone = AppSettingsService.instance.adminWhatsApp;

    // 1. Sapaan / Salam santai (hanya jika murni sapaan tanpa konteks produk)
    if (lower == 'halo' ||
        lower == 'hai' ||
        lower == 'hi' ||
        lower == 'hei' ||
        lower == 'p' ||
        lower == 'ping' ||
        lower == 'permisi' ||
        lower == 'tes' ||
        lower == 'test' ||
        lower.startsWith('halo') ||
        lower.startsWith('hai ') ||
        lower.startsWith('selamat') ||
        lower.contains('assalamu')) {
      if (!_hasProductOrOrderIntent(lower)) {
        return AiResponse(
          text:
              'Halo kak! Selamat datang di JatiMas Sangkar Jepara. Ada yang bisa saya bantu? Kakak bisa tanyakan motif sangkar, cek harga, atau langsung pesan via suara/teks.',
          suggestedProducts: [],
        );
      }
    }

    // 2. Ucapan terima kasih / konfirmasi santai
    if (lower.contains('terima kasih') ||
        lower.contains('makasih') ||
        lower.contains('thanks') ||
        lower.contains('suwun') ||
        lower == 'ok' ||
        lower == 'oke' ||
        lower == 'siap' ||
        lower == 'baik' ||
        lower == 'sip' ||
        lower == 'mantap') {
      if (!_hasProductOrOrderIntent(lower)) {
        return AiResponse(
          text:
              'Sama-sama kak! Senang bisa membantu. Jika butuh informasi sangkar atau ingin memesan produk JatiMas, silakan kabari saya kapan saja ya kak.',
          suggestedProducts: [],
        );
      }
    }

    // 3. Info Toko / Lokasi / Kontak / Jam Buka
    if (lower.contains('lokasi') ||
        lower.contains('alamat') ||
        lower.contains('dimana') ||
        lower.contains('buka jam') ||
        lower.contains('jam buka') ||
        lower.contains('kontak') ||
        lower.contains('telepon') ||
        lower.contains('wa') ||
        lower.contains('whatsapp')) {
      if (!_hasProductOrOrderIntent(lower)) {
        return AiResponse(
          text:
              'Toko JatiMas Sangkar berpusat di Jepara, Jawa Tengah (Pusat Pengrajin Ukir Jepara Asli). Kami melayani pemesanan ke seluruh Indonesia. Kakak bisa menghubungi admin kami via WhatsApp di $phone.',
          suggestedProducts: [],
        );
      }
    }

    // 4. Tanya identitas AI
    if (lower.contains('kamu siapa') ||
        lower.contains('siapa kamu') ||
        lower.contains('nama kamu') ||
        lower.contains('siapa namamu') ||
        lower.contains('kamu robot') ||
        lower.contains('kamu ai')) {
      return AiResponse(
        text:
            'Saya JatiMas AI Asisten, asisten virtual resmi dari JatiMas Sangkar Jepara. Saya siap membantu kakak mencari info sangkar burung, mengecek motif atau harga katalog, hingga memproses pesanan.',
        suggestedProducts: [],
      );
    }

    // 5. Pertanyaan Pendapat / Konsultasi / Evaluasi Sangkar
    // Contoh: "kalau menurutmu kalau yang ebod bagus untuk sehari hari ngga"
    if (_isAskingOpinion(lower)) {
      final relevant = _findRelevantProducts(lower);
      final prodName = relevant.isNotEmpty
          ? relevant.first.name
          : (lower.contains('ebod')
              ? 'Ebod Diamond Samurai'
              : (lower.contains('excellent')
                  ? 'Excellent OnePiece'
                  : (lower.contains('adidas')
                      ? 'Adidas Carbon'
                      : (lower.contains('carbon')
                          ? 'Serdadu Carbon'
                          : 'sangkar kayu jati'))));

      if (lower.contains('sehari hari') ||
          lower.contains('sehari-hari') ||
          lower.contains('harian')) {
        return AiResponse(
          text:
              'Menurut saya pribadi, sangkar $prodName sangat bagus dan cocok kak untuk harian. Karena dibuat dari kayu jati Jepara pilihan berkualitas tinggi, konstruksinya kokoh, awet, dan tahan cuaca. Rujinya juga presisi sehingga aman untuk burung yang aktif setiap hari, sekaligus motifnya terlihat mewah saat digantung di rumah.',
          suggestedProducts: [],
        );
      }

      if (lower.contains('lomba') || lower.contains('gantangan')) {
        return AiResponse(
          text:
              'Menurut saya, sangkar $prodName sangat recommended kak untuk lomba/gantangan. Ukiran khas Jeparanya detail dan berwibawa, membuat burung kakak tampil lebih menonjol dan percaya diri di arena lomba.',
          suggestedProducts: [],
        );
      }

      return AiResponse(
        text:
            'Menurut saya, sangkar $prodName kualitasnya sangat bagus kak. Dibuat langsung oleh pengrajin profesional JatiMas Jepara dari kayu jati asli, sehingga kuat, presisi, dan awet untuk jangka panjang.',
        suggestedProducts: [],
      );
    }

    // 5. Permintaan rekomendasi lain / opsi produk lain ("cari yang lain", "rekomendasi lain", "ada yang lain", dll.)
    final isAskingAlternative = lower.contains('yang lain') ||
        lower.contains('yg lain') ||
        lower.contains('rekomendasi lain') ||
        lower.contains('pilihan lain') ||
        lower.contains('opsi lain') ||
        lower.contains('model lain') ||
        lower.contains('motif lain') ||
        lower.contains('ada lagi') ||
        lower.contains('selain ini') ||
        lower.contains('selain itu') ||
        (lower.contains('rekomendasi') && lower.contains('lain')) ||
        (lower.contains('cari') && lower.contains('lain')) ||
        (lower.contains('lihat') && lower.contains('lain'));

    if (isAskingAlternative) {
      final previouslyShownIds = <String>{};
      for (final msg in history) {
        if (msg.suggestedProducts != null) {
          for (final p in msg.suggestedProducts!) {
            previouslyShownIds.add(p.id);
            if (p.code != null) previouslyShownIds.add(p.code!);
          }
        }
      }

      var alternatives = allProducts
          .where((p) => !previouslyShownIds.contains(p.id) &&
              (p.code == null || !previouslyShownIds.contains(p.code!)))
          .toList();

      if (alternatives.isEmpty) {
        alternatives = allProducts;
      }

      final chosen = alternatives.take(3).map((item) {
        final explanation = item.description.trim().isNotEmpty
            ? item.description.trim()
            : 'Sangkar ukir jati Jepara berkualitas tinggi dengan ukiran khas ${item.name}.';
        return item.copyWith(customNote: explanation);
      }).toList();

      return AiResponse(
        text:
            'Tentu kak! Berikut beberapa pilihan rekomendasi sangkar lainnya dari katalog JatiMas yang bisa jadi pertimbangan:',
        suggestedProducts: chosen,
      );
    }

    // 6. Cek apakah ada niat mencari / memesan produk
    if (!_hasProductOrOrderIntent(lower)) {
      return AiResponse(
        text:
            'Saya siap membantu kak. Silakan tanyakan motif sangkar, cek harga katalog, atau beri tahu sangkar apa yang sedang kakak cari.',
        suggestedProducts: [],
      );
    }

    // 7. Pertanyaan Custom / Logo / Desain Sendiri
    if (lower.contains('custom') ||
        lower.contains('logo') ||
        lower.contains('ukir nama') ||
        lower.contains('desain sendiri') ||
        lower.contains('buat baru') ||
        lower.contains('buat dari awal')) {
      final relevant = _findRelevantProducts(lower);
      return AiResponse(
        text:
            'Pemesanan di JatiMas dilakukan dengan memilih produk sangkar yang tersedia di katalog kami kak (tidak bisa membuat model/desain baru dari awal). Namun jika kakak ingin sedikit tambahan tulisan pada produk katalog yang dipilih (contoh: di samping karakternya ditambah tulisan inisial nama), kakak bisa menuliskannya di kolom Catatan saat memesan.',
        suggestedProducts: relevant.isNotEmpty ? relevant.take(3).toList() : [],
      );
    }

    // 8. Niat Pemesanan / Order / Masukkan Keranjang
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

        // Jika ada lebih dari 1 pilihan produk dan belum spesifik, tampilkan opsi produk
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
              'Baik kak! Boleh sebutkan nama motif sangkar atau jenis burung apa yang ingin dipesan? Contoh: "Pesan sangkar murai" atau "Beli tebok carbon".',
          suggestedProducts: [],
        );
      }
    }

    // 9. Tanya Harga / Biaya
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
          suggestedProducts: [],
        );
      }
    }

    // 10. Pencarian Produk Berdasarkan Kata Kunci (contoh: "kalau yang excellent", "motif samurai", dll.)
    final matched = _findRelevantProducts(lower);
    if (matched.isNotEmpty) {
      final productsWithExplanations = matched.take(3).map((item) {
        final explanation = item.description.trim().isNotEmpty
            ? item.description.trim()
            : 'Sangkar kayu jati Jepara pilihan dengan ukiran khas ${item.name}.';
        return item.copyWith(customNote: explanation);
      }).toList();

      final firstItem = matched.first;
      return AiResponse(
        text:
            'Berikut pilihan sangkar "${firstItem.name}" yang ada di katalog JatiMas kak:',
        suggestedProducts: productsWithExplanations,
      );
    }

    // 11. Jika meminta rekomendasi umum tanpa kata kunci spesifik
    if (lower.contains('rekomendasi') ||
        lower.contains('recomendasi') ||
        lower.contains('bagus') ||
        lower.contains('terbaik') ||
        lower.contains('pilihan')) {
      final topProducts = allProducts.take(3).map((item) {
        final explanation = item.description.trim().isNotEmpty
            ? item.description.trim()
            : 'Sangkar kayu jati Jepara pilihan dengan ukiran khas ${item.name}.';
        return item.copyWith(customNote: explanation);
      }).toList();

      return AiResponse(
        text:
            'Berikut rekomendasi sangkar terfavorit di katalog JatiMas yang bisa kakak pilih:',
        suggestedProducts: topProducts,
      );
    }

    // 12. Default Fallback untuk pencarian spesifik yang tidak ditemukan
    return AiResponse(
      text:
          'Mohon maaf kak, kami belum menemukan sangkar dengan kata kunci "$query" di katalog. Kakak bisa tanyakan motif lain seperti sangkar murai, Ebod Samurai, Excellent OnePiece, tebok carbon, atau hubungi WhatsApp kami di $phone.',
      suggestedProducts: [],
    );
  }

  List<Product> _findRelevantProducts(String text) {
    final lower = text.toLowerCase();
    final all = ProductService.instance.products;
    final keywords = lower
        .split(RegExp(r'[\s,\.\?!/\-]+'))
        .map((k) => k.trim())
        .where((k) => k.length >= 3 && !_stopWords.contains(k))
        .toList();

    if (keywords.isEmpty && !RegExp(r'\b[a-zA-Z]\d{1,4}\b').hasMatch(lower)) {
      return [];
    }

    return all.where((p) {
      final name = p.name.toLowerCase();
      final cat = p.category.toLowerCase();
      final desc = p.description.toLowerCase();
      final code = (p.code ?? '').toLowerCase();
      final tags = (p.hashtags ?? '').toLowerCase();

      // Cocok langsung seluruh kode produk (A05, A17, dll.)
      if (code.isNotEmpty && lower.contains(code)) return true;
      if (name.length >= 4 && lower.contains(name)) return true;

      // Cocok jika ada kata kunci yang relevan dalam nama, kategori, tags, atau deskripsi
      for (final kw in keywords) {
        if (name.contains(kw) ||
            cat.contains(kw) ||
            tags.contains(kw) ||
            (desc.contains(kw) && kw.length >= 4)) {
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
      if (lower.contains('carbon') && (name.contains('carbon') || desc.contains('carbon') || tags.contains('carbon'))) return true;
      if (lower.contains('adidas') && (name.contains('adidas') || desc.contains('adidas'))) return true;

      return false;
    }).toList();
  }
}
