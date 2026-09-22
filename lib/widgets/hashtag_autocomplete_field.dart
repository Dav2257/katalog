import 'package:flutter/material.dart';
import '../services/hashtag_service.dart';

/// Widget input teks dengan auto-complete pintar untuk penambahan hashtag produk admin.
/// Fitur:
/// - Mengambil saran hashtag dari HashtagService (Supabase & Cache).
/// - Menampilkan dropdown melayang (Overlay) tepat di bawah input field dengan lebar yang sama.
/// - Menghilangkan hashtag yang sudah terpilih agar tidak ganda.
/// - Opsi "Tambah Hashtag Baru" saat mengetik kata yang belum tersimpan di database.
/// - Baris saran cepat (Quick Chips) di bawah input field untuk penambahan 1-klik.
class HashtagAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> currentHashtags;
  final ValueChanged<String> onHashtagSelected;
  final VoidCallback? onSubmitted;
  final String hintText;
  final Key? fieldKey;

  const HashtagAutocompleteField({
    super.key,
    required this.controller,
    required this.currentHashtags,
    required this.onHashtagSelected,
    this.onSubmitted,
    this.hintText = 'Ketik hashtag lalu tekan Enter atau pilih saran...',
    this.fieldKey,
  });

  @override
  State<HashtagAutocompleteField> createState() => _HashtagAutocompleteFieldState();
}

class _HashtagAutocompleteFieldState extends State<HashtagAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    HashtagService.instance.addListener(_onServiceUpdated);
  }

  @override
  void didUpdateWidget(covariant HashtagAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentHashtags != widget.currentHashtags) {
      _updateSuggestions();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    HashtagService.instance.removeListener(_onServiceUpdated);
    _focusNode.dispose();
    super.dispose();
  }

  void _onServiceUpdated() {
    if (mounted) {
      _updateSuggestions();
    }
  }

  void _onTextChanged() {
    _updateSuggestions();
    if (_focusNode.hasFocus) {
      _showOverlay();
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _updateSuggestions();
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _updateSuggestions() {
    final query = widget.controller.text.trim();
    final results = HashtagService.instance.getSuggestions(
      query,
      exclude: widget.currentHashtags,
      limit: 8,
    );
    if (mounted) {
      setState(() {
        _suggestions = results;
      });
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _showOverlay() {
    _removeOverlay();

    final overlay = Overlay.of(context, debugRequiredFor: widget);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final query = widget.controller.text.trim();
        final cleanQuery = query.replaceAll(' ', '');
        final formattedQuery = cleanQuery.isEmpty
            ? ''
            : (cleanQuery.startsWith('#') ? cleanQuery : '#$cleanQuery');

        final showCreateOption = formattedQuery.isNotEmpty &&
            !_suggestions.any((s) => s.toLowerCase() == formattedQuery.toLowerCase()) &&
            !widget.currentHashtags.any((s) => s.toLowerCase() == formattedQuery.toLowerCase());

        final hasItems = _suggestions.isNotEmpty || showCreateOption;

        if (!hasItems) {
          return const SizedBox.shrink();
        }

        return Positioned(
          width: renderBox.size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0.0, 42.0),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              shadowColor: Colors.black26,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDCC8B4), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header kecil indikator database
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9F5EF),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(7),
                          topRight: Radius.circular(7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            query.isEmpty
                                ? 'Pilihan Hashtag Tersimpan'
                                : 'Saran Auto-Complete Database',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7A4B29),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8E0D5)),
                    Flexible(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          // Opsi buat hashtag baru jika belum ada
                          if (showCreateOption)
                            InkWell(
                              onTap: () {
                                _selectTag(formattedQuery);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                color: const Color(0xFFF5ECD7).withValues(alpha: 0.6),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.add_circle,
                                      size: 16,
                                      color: Color(0xFF7A4B29),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          text: 'Gunakan ',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF4A4A4A),
                                          ),
                                          children: [
                                            TextSpan(
                                              text: formattedQuery,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF7A4B29),
                                              ),
                                            ),
                                            const TextSpan(
                                              text: ' (Hashtag Baru)',
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: Color(0xFF888888),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Daftar saran dari database
                          ..._suggestions.map((tag) {
                            return InkWell(
                              onTap: () => _selectTag(tag),
                              hoverColor: const Color(0xFFF5ECD7).withValues(alpha: 0.4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.tag_rounded,
                                      size: 15,
                                      color: Color(0xFF7A4B29),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tag,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 11,
                                      color: Color(0xFFAAAAAA),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectTag(String tag) {
    widget.onHashtagSelected(tag);
    widget.controller.clear();
    _updateSuggestions();
    _removeOverlay();
  }

  void _submitCurrent() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty) {
      final items = text
          .split(RegExp(r'[\s,]+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty);
      for (final item in items) {
        widget.onHashtagSelected(item);
      }
      widget.controller.clear();
      _removeOverlay();
    } else {
      widget.onSubmitted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cari saran cepat (rekomendasi populer yang belum dipilih)
    final quickSuggestions = HashtagService.instance.hashtags
        .where((t) => !widget.currentHashtags.contains(t))
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: SizedBox(
            width: double.infinity,
            height: 38,
            child: TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              focusNode: _focusNode,
              onSubmitted: (_) => _submitCurrent(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A4A4A),
              ),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.tag_rounded,
                  size: 18,
                  color: Color(0xFF7A4B29),
                ),
                hintText: widget.hintText,
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
                    color: Color(0xFF7A4B29),
                  ),
                  tooltip: 'Tambahkan Hashtag',
                  onPressed: _submitCurrent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFAAAAAA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF7A4B29), width: 1.5),
                ),
                isDense: true,
              ),
            ),
          ),
        ),

        // Baris Saran Cepat (Quick Chips) untuk kemudahan 1-klik admin
        if (quickSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Saran Cepat: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                ),
              ),
              ...quickSuggestions.map((tag) {
                return InkWell(
                  onTap: () => _selectTag(tag),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F5EF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF7A4B29).withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7A4B29),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.add,
                          size: 11,
                          color: Color(0xFF7A4B29),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ],
    );
  }
}
