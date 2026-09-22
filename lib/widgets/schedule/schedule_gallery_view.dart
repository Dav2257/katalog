import 'package:flutter/material.dart';
import '../../services/schedule_service.dart';
import 'schedule_image_helper.dart';

/// Tampilan Gallery View (Notion-style Grid) untuk Schedule Produksi
/// Mengadopsi tata letak dari https://jatimas.beelink.web.id/
class ScheduleGalleryView extends StatelessWidget {
  final List<ProductionScheduleItem> items;
  final ValueChanged<ProductionScheduleItem> onItemTap;
  final VoidCallback? onAddNew;
  final Color Function(String status) getStatusBgColor;
  final Color Function(String status) getStatusTextColor;

  const ScheduleGalleryView({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onAddNew,
    required this.getStatusBgColor,
    required this.getStatusTextColor,
  });

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.collections_bookmark_outlined,
                size: 54,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tidak ada pesanan / kegiatan ditemukan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Coba ubah kata kunci pencarian atau filter status.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              if (onAddNew != null) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: onAddNew,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Buat Pesanan Baru'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6E3D20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (screenWidth >= 1200) {
      crossAxisCount = 4;
    } else if (screenWidth >= 850) {
      crossAxisCount = 3;
    } else if (screenWidth >= 550) {
      crossAxisCount = 2;
    }

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalSpacing = (crossAxisCount - 1) * 16.0;
            final cardWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;

            return Align(
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: items.map((item) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildGalleryCard(item),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGalleryCard(ProductionScheduleItem item) {
    final bgStatus = getStatusBgColor(item.status);
    final textStatus = getStatusTextColor(item.status);

    return InkWell(
      onTap: () => onItemTap(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image / Notion Icon Placeholder
            Container(
              height: 140,
              width: double.infinity,
              color: const Color(0xFFF7F6F3),
              child: buildScheduleImage(
                item.imageUrl,
                width: double.infinity,
                height: 140,
                placeholder: _buildPlaceholder(),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📄 ',
                        style: TextStyle(fontSize: 13),
                      ),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Status Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bgStatus,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: textStatus,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              item.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textStatus,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.qty != null)
                        Text(
                          '${item.qty} pcs',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),

                  // Customer Pill
                  if (item.customer != null && item.customer!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE7F3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.customer!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFBE185D),
                        ),
                      ),
                    ),
                  ],

                  // Type Sangkar
                  if (item.cageType != null && item.cageType!.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Text('🏷️ ', style: TextStyle(fontSize: 10)),
                        Expanded(
                          child: Text(
                            item.cageType!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Tanggal & PIC
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(item.date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.pic != null && item.pic!.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.pic!.trim(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7E22CE),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            '📄',
            style: TextStyle(fontSize: 32),
          ),
          SizedBox(height: 4),
          Text(
            'Jatimas Design',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
