import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import '../models/product.dart';
import '../pages/product_detail_page.dart';
import '../services/ai_assistant_service.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/settings_service.dart';

typedef AddToCartHandler =
    void Function(
      Product product, {
      int quantity,
      String? note,
      String? cageType,
    });

class AiAssistantDialog extends StatefulWidget {
  final AddToCartHandler? onAddToCart;
  final VoidCallback? onOpenCart;

  const AiAssistantDialog({super.key, this.onAddToCart, this.onOpenCart});

  static Future<void> show(
    BuildContext context, {
    AddToCartHandler? onAddToCart,
    VoidCallback? onOpenCart,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: AiAssistantDialog(
            onAddToCart: onAddToCart,
            onOpenCart: onOpenCart,
          ),
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AiAssistantDialog(
                onAddToCart: onAddToCart,
                onOpenCart: onOpenCart,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  State<AiAssistantDialog> createState() => _AiAssistantDialogState();
}

class _AiAssistantDialogState extends State<AiAssistantDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiChatMessage> _messages = [];

  // Voice Modules
  late stt.SpeechToText _speech;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _liveSpokenText = '';

  // Processing state
  bool _isAiThinking = false;

  // Animation untuk Mic berdenyut
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initPulseAnimation();
    _initVoiceEngines();

    // Pesan sambutan awal dari AI
    _messages.add(
      AiChatMessage(
        id: 'welcome',
        text:
            'Halo kak! Saya AI Asisten JatiMas. Ada yang bisa saya bantu? Kakak bisa langsung tekan tombol mikrofon untuk bicara atau ketik pertanyaan di bawah.',
        isUser: false,
      ),
    );
  }

  void _initPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initVoiceEngines() async {
    // Inisialisasi Speech-to-Text (STT)
    _speech = stt.SpeechToText();
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          }
        },
        onError: (errorNotification) {
          if (mounted) {
            setState(() => _isListening = false);
          }
          debugPrint('STT Error: ${errorNotification.errorMsg}');
        },
      );
      if (mounted) {
        setState(() => _speechEnabled = available);
      }
    } catch (e) {
      debugPrint('Speech to text note: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      if (_liveSpokenText.trim().isNotEmpty) {
        _handleSendMessage(_liveSpokenText);
        _liveSpokenText = '';
      }
      return;
    }

    if (!_speechEnabled) {
      // Coba inisialisasi ulang
      try {
        _speechEnabled = await _speech.initialize();
      } catch (_) {}
    }

    if (!_speechEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mikrofon tidak tersedia di peramban/perangkat ini. Silakan gunakan ketik teks.',
          ),
          backgroundColor: Color(0xFFD32F2F),
        ),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _liveSpokenText = '';
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _liveSpokenText = result.recognizedWords;
            });
            if (result.finalResult && _liveSpokenText.trim().isNotEmpty) {
              _speech.stop();
              setState(() => _isListening = false);
              _handleSendMessage(_liveSpokenText);
              _liveSpokenText = '';
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('Listen error: $e');
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _handleSendMessage(String userText) async {
    final query = userText.trim();
    if (query.isEmpty) return;

    _textController.clear();

    setState(() {
      _messages.add(
        AiChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: query,
          isUser: true,
        ),
      );
      _isAiThinking = true;
    });

    _scrollToBottom();

    try {
      final response = await AiAssistantService.instance.sendMessage(
        query,
        history: _messages,
      );

      // Otomatis masukkan ke keranjang belanja jika AI mendeteksi pesanan
      if (response.orderData != null) {
        _processAutoAddToCart(response.orderData!, response.suggestedProducts);
      }

      if (mounted) {
        setState(() {
          _isAiThinking = false;
          _messages.add(
            AiChatMessage(
              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
              text: response.text,
              isUser: false,
              suggestedProducts: response.suggestedProducts,
              pendingOrder: response.orderData,
            ),
          );
        });

        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAiThinking = false;
          _messages.add(
            AiChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text:
                  'Maaf, terjadi kendala saat memproses jawaban. Silakan coba lagi.',
              isUser: false,
            ),
          );
        });
        _scrollToBottom();
      }
    }
  }

  void _processAutoAddToCart(
    Map<String, dynamic> orderData,
    List<Product>? suggestedProducts,
  ) {
    if (widget.onAddToCart == null) return;

    final targetName = (orderData['productName'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final rawQty = orderData['quantity'];
    final qty = (rawQty is int)
        ? rawQty
        : (int.tryParse(rawQty?.toString() ?? '1') ?? 1);
    final note =
        orderData['note']?.toString() ?? 'Dipesan via AI Asisten JatiMas';

    Product? matchedProduct;

    // 1. Cek dari produk rekomendasi yang relevan terlebih dahulu
    if (suggestedProducts != null && suggestedProducts.isNotEmpty) {
      if (targetName.isNotEmpty) {
        try {
          matchedProduct = suggestedProducts.firstWhere(
            (p) =>
                p.name.toLowerCase().contains(targetName) ||
                targetName.contains(p.name.toLowerCase()),
          );
        } catch (_) {
          matchedProduct = suggestedProducts.first;
        }
      } else {
        matchedProduct = suggestedProducts.first;
      }
    }

    // 2. Fallback cek seluruh katalog ProductService jika belum ketemu
    if (matchedProduct == null) {
      final all = ProductService.instance.products;
      if (targetName.isNotEmpty) {
        try {
          matchedProduct = all.firstWhere(
            (p) =>
                p.name.toLowerCase().contains(targetName) ||
                targetName.contains(p.name.toLowerCase()),
          );
        } catch (_) {
          if (all.isNotEmpty) matchedProduct = all.first;
        }
      } else if (all.isNotEmpty) {
        matchedProduct = all.first;
      }
    }

    if (matchedProduct != null) {
      final actualQty = qty > 0 ? qty : 1;
      widget.onAddToCart!(matchedProduct, quantity: actualQty, note: note);
      // Simpan referensi produk untuk tampilan kartu di chat
      orderData['_resolvedProduct'] = matchedProduct;
      orderData['_isAddedToCart'] = true;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleDirectOrderViaWhatsApp(
    Map<String, dynamic> orderData, {
    List<Product>? alternativeProducts,
  }) {
    Product? resolvedProduct = orderData['_resolvedProduct'] as Product?;
    if (resolvedProduct == null) {
      final prodName = (orderData['productName'] ?? '').toString().toLowerCase();
      final all = ProductService.instance.products;
      try {
        resolvedProduct = all.firstWhere((p) =>
            p.name.toLowerCase().contains(prodName) ||
            prodName.contains(p.name.toLowerCase()));
      } catch (_) {
        if (alternativeProducts != null && alternativeProducts.isNotEmpty) {
          resolvedProduct = alternativeProducts.first;
        } else if (all.isNotEmpty) {
          resolvedProduct = all.first;
        }
      }
    }

    final rawQty = orderData['quantity'];
    final qty = (rawQty is int)
        ? rawQty
        : (int.tryParse(rawQty?.toString() ?? '1') ?? 1);
    final note = orderData['note']?.toString();

    if (resolvedProduct != null) {
      _showOrderFormBottomSheet(
        product: resolvedProduct,
        initialQty: qty,
        initialNote: note,
        alternativeProducts: alternativeProducts,
      );
    } else {
      // Fallback kirim langsung jika objek produk kosong
      _sendDirectWhatsAppMessage(
        productName: orderData['productName'] ?? 'Sangkar JatiMas',
        qty: qty,
        note: note ?? '-',
        name: AuthService.instance.userName,
        phone: AuthService.instance.userPhone,
      );
    }
  }

  Future<void> _sendDirectWhatsAppMessage({
    required String productName,
    required int qty,
    required String note,
    String? name,
    String? phone,
    int? totalPrice,
  }) async {
    final targetWa = AppSettingsService.instance.adminWhatsApp;
    final customerName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : (AuthService.instance.userName.isNotEmpty
            ? AuthService.instance.userName
            : 'Pelanggan JatiMas');
    final customerPhone = (phone != null && phone.trim().isNotEmpty)
        ? phone.trim()
        : AuthService.instance.userPhone;

    final text =
        'Halo Admin JatiMas Sangkar Jepara,\n\n'
        'Saya ingin memesan sangkar:\n'
        '• Produk: $productName\n'
        '• Jumlah: $qty pcs\n'
        '${totalPrice != null && totalPrice > 0 ? "• Estimasi Harga: Rp $totalPrice\n" : ""}'
        '• Catatan Khusus: ${note.isNotEmpty ? note : "-"}\n\n'
        'Data Pemesan:\n'
        '• Nama: $customerName\n'
        '${customerPhone.isNotEmpty ? "• No. WA/HP: $customerPhone\n" : ""}'
        '\nMohon info ketersediaan, estimasi pengerjaan, dan totalnya. Terima kasih!';

    final uri = Uri.parse(
      'https://wa.me/$targetWa?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showOrderFormBottomSheet({
    required Product product,
    int initialQty = 1,
    String? initialNote,
    List<Product>? alternativeProducts,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        Product currentProduct = product;
        int qty = initialQty > 0 ? initialQty : 1;
        final nameController = TextEditingController(
          text: AuthService.instance.userName,
        );
        final phoneController = TextEditingController(
          text: AuthService.instance.userPhone,
        );
        final noteController = TextEditingController(
          text: initialNote != null && initialNote != '-' ? initialNote : '',
        );

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final candidates = <Product>[];
            candidates.add(currentProduct);
            if (alternativeProducts != null) {
              for (final alt in alternativeProducts) {
                if (!candidates.any((c) => c.id == alt.id)) {
                  candidates.add(alt);
                }
              }
            }

            return Container(
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF9F6F0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle Indicator
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header Bottom Sheet
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C1A0E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.assignment_outlined,
                            color: Color(0xFFFFD900),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Form Lengkapi Pesanan',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF2C1A0E),
                                ),
                              ),
                              Text(
                                'Periksa produk, catatan, nama & nomor kontak',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8C6D37),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFE8DFD0)),

                    // Opsi Pergantian Produk (jika ada lebih dari 1 pilihan produk)
                    if (candidates.length > 1) ...[
                      const Text(
                        'Pilihan Opsi Produk (Ketuk untuk beralih):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5A4A38),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 72,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: candidates.length,
                          itemBuilder: (_, idx) {
                            final alt = candidates[idx];
                            final isSel = alt.id == currentProduct.id;
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  currentProduct = alt;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 175,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? const Color(0xFF2C1A0E)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFFD4AF37)
                                        : const Color(0xFFDDD2C0),
                                    width: isSel ? 1.8 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (alt.imageUrl.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          alt.imageUrl,
                                          width: 38,
                                          height: 38,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            alt.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSel
                                                  ? const Color(0xFFF5ECD7)
                                                  : const Color(0xFF2C1A0E),
                                            ),
                                          ),
                                          Text(
                                            alt.price > 0
                                                ? 'Rp ${alt.price}'
                                                : 'Custom',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isSel
                                                  ? const Color(0xFFFFD900)
                                                  : const Color(0xFF8C6D37),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Card Produk Terpilih Saat Ini & Stepper Quantity
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0D5C1)),
                      ),
                      child: Row(
                        children: [
                          if (currentProduct.imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                currentProduct.imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 28,
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentProduct.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF2C1A0E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentProduct.price > 0
                                      ? 'Rp ${currentProduct.price * qty} (Rp ${currentProduct.price}/pcs)'
                                      : 'Harga Custom Pengrajin',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Stepper Qty
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5EBE1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (qty > 1) {
                                      setModalState(() => qty--);
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Icon(Icons.remove, size: 16),
                                  ),
                                ),
                                Text(
                                  '$qty',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setModalState(() => qty++);
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Icon(Icons.add, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Input Nama Pemesan
                    const Text(
                      'Nama Pemesan:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A4A38),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Nama pemesan (cth: Budi Jepara)...',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDD2C0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDD2C0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Input No. WhatsApp / HP
                    const Text(
                      'Nomor WhatsApp / HP Aktif:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A4A38),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '08123456789 (untuk konfirmasi pengrajin)',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                        prefixIcon: const Icon(
                          Icons.phone_android_rounded,
                          size: 18,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDD2C0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDD2C0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Input Catatan Khusus
                    const Text(
                      'Catatan Tambahan (Opsional pada produk katalog yang dipilih):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A4A38),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Hanya untuk penambahan tulisan/nama kecil (tidak melayani desain baru dari nol)',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF8C6D37),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText:
                            'Contoh: "di samping karakternya di tambah tulisan GB" atau inisial nama...',
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Icon(Icons.edit_note_rounded, size: 20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDD2C0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDD2C0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Tombol Aksi 1: Ke Keranjang & Tombol Aksi 2: Kirim ke WA
                    Row(
                      children: [
                        // Tombol Ke Keranjang
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final finalNote = noteController.text.trim();
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();

                              String noteWithCustomer = finalNote;
                              if (name.isNotEmpty || phone.isNotEmpty) {
                                noteWithCustomer = [
                                  if (name.isNotEmpty) 'Pemesan: $name',
                                  if (phone.isNotEmpty) 'Kontak: $phone',
                                  if (finalNote.isNotEmpty) 'Catatan: $finalNote',
                                ].join(' | ');
                              }

                              widget.onAddToCart?.call(
                                currentProduct,
                                quantity: qty,
                                note: noteWithCustomer.isNotEmpty
                                    ? noteWithCustomer
                                    : 'Pesanan via AI Asisten',
                              );

                              Navigator.pop(ctx);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$qty' 'x "${currentProduct.name}" berhasil dimasukkan ke keranjang!',
                                  ),
                                  backgroundColor: const Color(0xFF2C1A0E),
                                  duration: const Duration(seconds: 3),
                                  action: widget.onOpenCart != null
                                      ? SnackBarAction(
                                          label: 'Lihat',
                                          textColor: const Color(0xFFFFD900),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            widget.onOpenCart!();
                                          },
                                        )
                                      : null,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 16,
                            ),
                            label: const Text('Ke Keranjang'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2C1A0E),
                              side: const BorderSide(
                                color: Color(0xFF2C1A0E),
                                width: 1.3,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Tombol Kirim ke WhatsApp
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final finalNote = noteController.text.trim();
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();

                              Navigator.pop(ctx);

                              await _sendDirectWhatsAppMessage(
                                productName:
                                    '${currentProduct.name} ${currentProduct.code != null ? '(${currentProduct.code})' : ''}',
                                qty: qty,
                                note: finalNote,
                                name: name,
                                phone: phone,
                                totalPrice: currentProduct.price > 0
                                    ? currentProduct.price * qty
                                    : null,
                              );
                            },
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 16,
                            ),
                            label: const Text('Kirim ke WA'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF9F6F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 1. Header Bar
          _buildHeader(),

          // 2. Chat Conversation Stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isAiThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isAiThinking) {
                  return _buildAiThinkingBubble();
                }
                final message = _messages[index];
                return _buildMessageItem(message);
              },
            ),
          ),

          // 3. Live Voice Transcript Banner (jika sedang mendengarkan mic)
          if (_isListening) _buildLiveTranscriptBanner(),

          // 4. Bottom Input Control
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF2C1A0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Avatar AI Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFDF00), Color(0xFFD4AF37)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD900).withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF2C1A0E),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'AI Asisten JatiMas',
                          style: TextStyle(
                            color: Color(0xFFF5ECD7),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFD4AF37,
                          ).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFD4AF37),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'Hermes AI',
                          style: TextStyle(
                            color: Color(0xFFFFD900),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isListening
                            ? 'Mendengarkan suara...'
                            : 'Online & siap membantu',
                        style: const TextStyle(
                          color: Color(0xFFEDE4D3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tombol Tutup
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFFF5ECD7)),
              onPressed: () {
                _speech.stop();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(AiChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF2C1A0E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: Color(0xFFF5ECD7),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Color(0xFF2C1A0E),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            // Kartu Konfirmasi Pesanan jika AI mendeteksi data order
            if (message.pendingOrder != null)
              _buildOrderConfirmationCard(
                message.pendingOrder!,
                alternativeProducts: message.suggestedProducts,
              ),

            // Kartu Rekomendasi Produk jika ada
            if (message.suggestedProducts != null &&
                message.suggestedProducts!.isNotEmpty)
              _buildSuggestedProducts(message.suggestedProducts!),
          ],
        ),
      ),
    );
  }

  Widget _buildAiThinkingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Hermes AI sedang merespons...',
              style: TextStyle(
                color: Color(0xFF5A4A38),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderConfirmationCard(
    Map<String, dynamic> orderData, {
    List<Product>? alternativeProducts,
  }) {
    final prodName = orderData['productName'] ?? 'Sangkar Jati';
    final rawQty = orderData['quantity'];
    final qty = (rawQty is int)
        ? rawQty
        : (int.tryParse(rawQty?.toString() ?? '1') ?? 1);
    final note = orderData['note'] ?? '-';
    final Product? resolvedProduct = orderData['_resolvedProduct'] as Product?;
    final isAdded = orderData['_isAddedToCart'] == true;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF9F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdded ? const Color(0xFF2E7D32) : const Color(0xFFD4AF37),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAdded ? Colors.green : const Color(0xFFD4AF37))
                .withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isAdded
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAdded
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFFC107),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAdded
                      ? Icons.check_circle_rounded
                      : Icons.shopping_bag_outlined,
                  size: 15,
                  color: isAdded
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF856404),
                ),
                const SizedBox(width: 6),
                Text(
                  isAdded
                      ? '✓ Otomatis Ditambahkan ke Keranjang'
                      : 'Ringkasan Pesanan AI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isAdded
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFF856404),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Detail Produk
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (resolvedProduct != null &&
                  resolvedProduct.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    resolvedProduct.imageUrl,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 58,
                      height: 58,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.inventory_2_outlined, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedProduct?.name ?? prodName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF2C1A0E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resolvedProduct != null && resolvedProduct.price > 0
                          ? 'Rp ${resolvedProduct.price} x $qty pcs'
                          : 'Jumlah: $qty pcs',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8C6D37),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (resolvedProduct != null && resolvedProduct.price > 0)
                      Text(
                        'Total: Rp ${resolvedProduct.price * qty}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    if (note != '-' && note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Catatan: $note',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Opsi Ganti Produk Langsung (jika ada alternatif produk lain)
          if (alternativeProducts != null &&
              alternativeProducts.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: const [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 14,
                  color: Color(0xFF8C6D37),
                ),
                SizedBox(width: 4),
                Text(
                  'Bukan produk ini? Ketuk untuk ganti:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8C6D37),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: alternativeProducts.map((altProd) {
                  final isCurrent =
                      (resolvedProduct?.id == altProd.id) ||
                      (prodName == altProd.name);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          orderData['_resolvedProduct'] = altProd;
                          orderData['productName'] = altProd.name;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFF2C1A0E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent
                                ? const Color(0xFFD4AF37)
                                : const Color(0xFFDDD2C0),
                            width: isCurrent ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          altProd.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrent
                                ? const Color(0xFFFFD900)
                                : const Color(0xFF2C1A0E),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Tombol Aksi: Lengkapi Catatan/Data & Kirim ke WhatsApp
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final currentProd = resolvedProduct ??
                        (alternativeProducts != null &&
                                alternativeProducts.isNotEmpty
                            ? alternativeProducts.first
                            : ProductService.instance.products.firstOrNull);
                    if (currentProd != null) {
                      _showOrderFormBottomSheet(
                        product: currentProd,
                        initialQty: qty,
                        initialNote: note != '-' ? note : '',
                        alternativeProducts: alternativeProducts,
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                  ),
                  label: const Text(
                    'Catatan & Data',
                    style: TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C1A0E),
                    foregroundColor: const Color(0xFFFFD900),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleDirectOrderViaWhatsApp(
                    orderData,
                    alternativeProducts: alternativeProducts,
                  ),
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                  ),
                  label: const Text(
                    'Kirim ke WA',
                    style: TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    side: const BorderSide(
                      color: Color(0xFF2E7D32),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedProducts(List<Product> products) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: products
            .map((p) => _buildSuggestedProductCard(p, products))
            .toList(),
      ),
    );
  }

  Widget _buildSuggestedProductCard(
    Product product,
    List<Product> allSuggestions,
  ) {
    // Penjelasan khusus motif / keistimewaan dari AI
    final explanation = (product.customNote != null &&
            product.customNote!.trim().isNotEmpty)
        ? product.customNote!.trim()
        : (product.description.trim().isNotEmpty
            ? product.description.trim()
            : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0D5C1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Produk: Gambar + Kode + Nama + Harga
          InkWell(
            onTap: () => _navigateToProductDetail(product),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gambar Produk
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 66,
                    height: 66,
                    color: const Color(0xFFF5ECD7),
                    child: product.buildImage(
                      width: 66,
                      height: 66,
                      fit: BoxFit.cover,
                      placeholder: const Center(
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 28,
                          color: Color(0xFF8C6D37),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Nama & Harga
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF2C1A0E),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            product.price > 0
                                ? product.formattedPrice
                                : 'Katalog JatiMas',
                            style: TextStyle(
                              color: product.price > 0
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFF8C6D37),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (product.code != null &&
                              product.code!.isNotEmpty &&
                              !product.displayName.contains(product.code!)) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0EAE1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.code!,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5A4A38),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Kotak Penjelasan / Motif Keunikan (Menggantikan teks Gambar 1)
          if (explanation != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF8F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEBE0D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      explanation,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF4A3E31),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Tombol Aksi: [📝 Pesan] | [🛒 + Keranjang] | [Lihat >]
          Row(
            children: [
              // Tombol Pesan
              Expanded(
                flex: 5,
                child: InkWell(
                  onTap: () {
                    _showOrderFormBottomSheet(
                      product: product,
                      alternativeProducts: allSuggestions,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 14,
                            color: Color(0xFF2C1A0E),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Pesan',
                            style: TextStyle(
                              color: Color(0xFF2C1A0E),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Tombol + Keranjang
              Expanded(
                flex: 6,
                child: InkWell(
                  onTap: () {
                    widget.onAddToCart?.call(
                      product,
                      quantity: 1,
                      note: 'Dipilih dari rekomendasi AI',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '1x "${product.name}" dimasukkan ke keranjang!',
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF2C1A0E),
                        action: widget.onOpenCart != null
                            ? SnackBarAction(
                                label: 'Lihat',
                                textColor: const Color(0xFFFFD900),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onOpenCart!();
                                },
                              )
                            : null,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3),
                          Text(
                            '+ Keranjang',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Tombol Lihat Detail
              InkWell(
                onTap: () => _navigateToProductDetail(product),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C1A0E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 12,
                        color: Color(0xFFF5ECD7),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 9,
                        color: Color(0xFFF5ECD7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: product,
          onAddToCart: (p) {
            widget.onAddToCart?.call(p);
          },
        ),
      ),
    );
  }

  Widget _buildLiveTranscriptBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFFF3CD),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _liveSpokenText.isNotEmpty
                  ? _liveSpokenText
                  : 'Mendengarkan ucapan Anda...',
              style: const TextStyle(
                color: Color(0xFF856404),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8DFD0), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Tombol Mikrofon Suara Utama
            ScaleTransition(
              scale: _isListening
                  ? _pulseAnimation
                  : const AlwaysStoppedAnimation(1.0),
              child: Material(
                color: _isListening
                    ? Colors.redAccent
                    : const Color(0xFFD4AF37),
                shape: const CircleBorder(),
                elevation: _isListening ? 6 : 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggleListening,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _isListening
                          ? Colors.white
                          : const Color(0xFF2C1A0E),
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Input Teks Alternatif
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EBE1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFDDD2C0)),
                ),
                child: TextField(
                  controller: _textController,
                  onSubmitted: _handleSendMessage,
                  decoration: const InputDecoration(
                    hintText: 'Ketik pesan atau tekan mic...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.black45),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Tombol Kirim Teks
            Material(
              color: const Color(0xFF2C1A0E),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _handleSendMessage(_textController.text),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Color(0xFFF5ECD7),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoundedRectangleApp {
  static RoundedRectangleBorder rounded(double radius) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }
}
