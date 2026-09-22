import 'package:flutter/material.dart';
import '../../services/schedule_service.dart';
import 'schedule_image_helper.dart';

/// Tampilan Board View (Kanban 5 Kolom Status) untuk Schedule Produksi
/// Mengadopsi tata letak dari https://jatimas.beelink.web.id/
class ScheduleBoardView extends StatelessWidget {
  final List<ProductionScheduleItem> items;
  final ValueChanged<ProductionScheduleItem> onItemTap;
  final void Function(String defaultStatus)? onAddNewWithStatus;
  final Color Function(String status) getStatusBgColor;
  final Color Function(String status) getStatusTextColor;

  const ScheduleBoardView({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onAddNewWithStatus,
    required this.getStatusBgColor,
    required this.getStatusTextColor,
  });

  static const List<String> _statuses = [
    'Belum dimulai',
    'Sedang berlangsung',
    'Siap Cetak',
    'Di Cetak',
    'Selesai',
  ];

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _statuses.map((status) {
              final columnItems = items.where((it) => it.status.toLowerCase() == status.toLowerCase()).toList();
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 14),
                child: _buildColumn(context, status, columnItems),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildColumn(BuildContext context, String status, List<ProductionScheduleItem> columnItems) {
    final bgColor = getStatusBgColor(status);
    final textColor = getStatusTextColor(status);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: Row(
              children: [
                // Status Pill
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: textColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            status,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${columnItems.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Spacer(),
                if (onAddNewWithStatus != null)
                  InkWell(
                    onTap: () => onAddNewWithStatus!(status),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 17,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Cards List
          Flexible(
            child: columnItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                    child: Center(
                      child: Text(
                        'Tidak ada item',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8.0),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: columnItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = columnItems[index];
                      return _buildBoardCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardCard(ProductionScheduleItem item) {
    final hasImage = item.imageUrl != null && item.imageUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: () => onItemTap(item),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail mini jika ada
            if (hasImage)
              Container(
                height: 80,
                width: double.infinity,
                color: const Color(0xFFF3F4F6),
                child: buildScheduleImage(
                  item.imageUrl,
                  width: double.infinity,
                  height: 80,
                  placeholder: const SizedBox.shrink(),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📄 ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Customer Pill
                  if (item.customer != null && item.customer!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE7F3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.customer!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFBE185D),
                        ),
                      ),
                    ),
                  ],

                  // Details row
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (item.cageType != null && item.cageType!.trim().isNotEmpty)
                        Expanded(
                          child: Text(
                            '🏷️ ${item.cageType!.trim()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (item.qty != null)
                        Text(
                          '📦 ${item.qty} pcs',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),

                  // Date & PIC
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(item.date),
                        style: const TextStyle(
                          fontSize: 10,
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
                              fontSize: 9.5,
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
}
