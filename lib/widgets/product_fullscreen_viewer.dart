import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal Viewer Fullscreen Interaktif untuk Gambar Produk & Bentuk Sangkar
class ProductFullscreenViewer extends StatefulWidget {
  final int initialIndex;
  final int totalSlides;
  final Widget Function(BuildContext context, int index) slideBuilder;
  final String Function(int index) titleBuilder;
  final void Function(int index)? onPageChanged;

  const ProductFullscreenViewer({
    super.key,
    required this.initialIndex,
    required this.totalSlides,
    required this.slideBuilder,
    required this.titleBuilder,
    this.onPageChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required int initialIndex,
    required int totalSlides,
    required Widget Function(BuildContext context, int index) slideBuilder,
    required String Function(int index) titleBuilder,
    void Function(int index)? onPageChanged,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup Layar Penuh',
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return ProductFullscreenViewer(
          initialIndex: initialIndex,
          totalSlides: totalSlides,
          slideBuilder: slideBuilder,
          titleBuilder: titleBuilder,
          onPageChanged: onPageChanged,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  State<ProductFullscreenViewer> createState() =>
      _ProductFullscreenViewerState();
}

class _ProductFullscreenViewerState extends State<ProductFullscreenViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _controllers = {};
  bool _isZoomed = false;
  TapDownDetails? _doubleTapDetails;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _getController(_currentIndex).addListener(_handleTransformationChange);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _getController(int index) {
    if (!_controllers.containsKey(index)) {
      final controller = TransformationController();
      _controllers[index] = controller;
    }
    return _controllers[index]!;
  }

  void _handleTransformationChange() {
    final scale = _getController(_currentIndex).value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    if (_isZoomed != isZoomed) {
      setState(() {
        _isZoomed = isZoomed;
      });
    }
  }

  void _onPageChanged(int index) {
    _getController(_currentIndex).removeListener(_handleTransformationChange);
    setState(() {
      _currentIndex = index;
      _isZoomed = _getController(index).value.getMaxScaleOnAxis() > 1.05;
    });
    _getController(index).addListener(_handleTransformationChange);
    widget.onPageChanged?.call(index);
  }

  void _zoomIn() {
    final controller = _getController(_currentIndex);
    final currentScale = controller.value.getMaxScaleOnAxis();
    if (currentScale < 5.0) {
      final newScale = (currentScale + 0.5).clamp(1.0, 5.0);
      controller.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
    }
  }

  void _zoomOut() {
    final controller = _getController(_currentIndex);
    final currentScale = controller.value.getMaxScaleOnAxis();
    if (currentScale > 1.0) {
      final newScale = (currentScale - 0.5).clamp(1.0, 5.0);
      controller.value = newScale <= 1.05
          ? Matrix4.identity()
          : Matrix4.diagonal3Values(newScale, newScale, 1.0);
    }
  }

  void _resetZoom() {
    _getController(_currentIndex).value = Matrix4.identity();
  }

  void _handleDoubleTap(int index) {
    final controller = _getController(index);
    if (!controller.value.isIdentity()) {
      controller.value = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails?.localPosition ?? Offset.zero;
      final matrix = Matrix4.diagonal3Values(2.5, 2.5, 1.0)
        ..setTranslationRaw(-pos.dx * 1.5, -pos.dy * 1.5, 0.0);
      controller.value = matrix;
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
          _currentIndex > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
          _currentIndex < widget.totalSlides - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // 1. Slider Gambar Utama
                Positioned.fill(
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      physics: _isZoomed
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      itemCount: widget.totalSlides,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        final controller = _getController(index);
                        return GestureDetector(
                          onDoubleTapDown: (details) =>
                              _doubleTapDetails = details,
                          onDoubleTap: () => _handleDoubleTap(index),
                          child: InteractiveViewer(
                            transformationController: controller,
                            minScale: 0.8,
                            maxScale: 5.0,
                            panEnabled: true,
                            scaleEnabled: true,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isNarrow ? 8.0 : 16.0,
                                  vertical: isNarrow ? 55.0 : 70.0,
                                ),
                                child: widget.slideBuilder(context, index),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 2. Bar Kontrol Atas (Header Responsif)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isNarrow ? 12 : 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          // Badge Slide
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white24,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${widget.totalSlides}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isNarrow ? 11 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Judul Slide
                          Expanded(
                            child: Text(
                              widget.titleBuilder(_currentIndex),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isNarrow ? 13 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // Tombol Zoom In & Out khusus layar desktop/lebar
                          if (!isNarrow) ...[
                            IconButton(
                              tooltip: 'Perkecil',
                              icon: const Icon(
                                Icons.zoom_out_rounded,
                                color: Colors.white,
                              ),
                              onPressed: _zoomOut,
                            ),
                            IconButton(
                              tooltip: 'Perbesar',
                              icon: const Icon(
                                Icons.zoom_in_rounded,
                                color: Colors.white,
                              ),
                              onPressed: _zoomIn,
                            ),
                          ],

                          // Tombol Reset Zoom
                          if (_isZoomed)
                            IconButton(
                              tooltip: 'Kembalikan Ukuran',
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                                color: Color(0xFFFFD900),
                              ),
                              onPressed: _resetZoom,
                            ),

                          const SizedBox(width: 4),

                          // Tombol Tutup
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Tombol Panah Kiri (<)
                if (_currentIndex > 0)
                  Positioned(
                    left: isNarrow ? 8 : 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: InkWell(
                        onTap: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: isNarrow ? 36 : 44,
                          height: isNarrow ? 36 : 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: isNarrow ? 16 : 20,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 4. Tombol Panah Kanan (>)
                if (_currentIndex < widget.totalSlides - 1)
                  Positioned(
                    right: isNarrow ? 8 : 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: InkWell(
                        onTap: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: isNarrow ? 36 : 44,
                          height: isNarrow ? 36 : 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 1),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: isNarrow ? 16 : 20,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 5. Petunjuk di Bawah
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12, width: 0.8),
                      ),
                      child: Text(
                        isNarrow
                            ? 'Cubit layar atau klik ganda untuk memperbesar'
                            : 'Scroll mouse atau klik ganda untuk memperbesar gambar',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
