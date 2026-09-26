import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/settings_service.dart';

class HeroBanner extends StatelessWidget {
  final String assetPath;
  final VoidCallback? onTap;

  const HeroBanner({
    super.key,
    this.assetPath = 'assets/images/banner.png',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Banner membentang penuh dari ujung kiri ke ujung kanan tanpa celah
    return AnimatedBuilder(
      animation: AppSettingsService.instance,
      builder: (context, _) {
        final settings = AppSettingsService.instance;
        Widget bannerWidget;

        // Banner aset lokal resmi Jatimas Sangkar (cepat, offline-ready, anti-gagal di semua mode)
        final Widget defaultAssetBanner = Image.asset(
          assetPath,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => _buildEmergencyFallbackBanner(context),
        );

        final customUrl = settings.bannerImageUrl?.trim();
        final hasCustomCloudBanner = customUrl != null &&
            customUrl.isNotEmpty &&
            !customUrl.contains('banner_official.png') &&
            !customUrl.contains('banner_1789710462285');

        if (settings.bannerImageBytes != null && settings.bannerImageBytes!.isNotEmpty) {
          bannerWidget = Image.memory(
            settings.bannerImageBytes!,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => defaultAssetBanner,
          );
        } else if (hasCustomCloudBanner) {
          bannerWidget = Product.buildImageFromSource(
            customUrl,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            placeholder: defaultAssetBanner,
          );
        } else {
          // Default: Selalu tampilkan banner lokal resmi 'assets/images/banner.png'
          bannerWidget = defaultAssetBanner;
        }

        return InkWell(
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            child: bannerWidget,
          ),
        );
      },
    );
  }

  /// Cadangan darurat hanya jika file aset lokal mengalami kegagalan sistem
  Widget _buildEmergencyFallbackBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C1E14), Color(0xFF1C2B1D), Color(0xFF2C1E14)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jatimas sangkar',
                style: TextStyle(
                  color: Color(0xFFE8C88A),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Crafted with Teak, Home to Harmony',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

