import 'package:flutter/material.dart';
import '../../services/schedule_service.dart';
import 'schedule_image_helper.dart';

/// Tampilan Table View (Notion-style Grouped Table) untuk Schedule Produksi
/// Mengadopsi tata letak dari https://jatimas.beelink.web.id/
class ScheduleTableView extends StatefulWidget {
  final List<ProductionScheduleItem> items;
  final ValueChanged<ProductionScheduleItem> onItemTap;
  final VoidCallback? onAddNew;
  final Color Function(String status) getStatusBgColor;
  final Color Function(String status) getStatusTextColor;

  const ScheduleTableView({
    super.key,
    required this.items,
    required this.onItemTap,
    this.onAddNew,
    required this.getStatusBgColor,
    required this.getStatusTextColor,
  });

  @override
  State<ScheduleTableView> createState() => _ScheduleTableViewState();
}

class _ScheduleTableViewState extends State<ScheduleTableView> {
  final Set<String> _collapsedGroups = {};

  String _formatDate(DateTime d) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  // Mendapatkan label range minggu (Minggu - Sabtu)
  String _getWeekLabel(DateTime d) {
    const monthsShort = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final dayOfWeek = d.weekday % 7; // 0 = Minggu
    final sun = d.subtract(Duration(days: dayOfWeek));
    final sat = sun.add(const Duration(days: 6));

    final sunM = monthsShort[sun.month - 1];
    final satM = monthsShort[sat.month - 1];

    if (sun.year == sat.year) {
      if (sun.month == sat.month) {
        return '$sunM ${sun.day} – ${sat.day} ${sun.year}';
      } else {
        return '$sunM ${sun.day} – $satM ${sat.day} ${sun.year}';
      }
    } else {
      return '$sunM ${sun.day} ${sun.year} – $satM ${sat.day} ${sat.year}';
    }
  }

  String _getWeekKey(DateTime d) {
    final dayOfWeek = d.weekday % 7;
    final sun = d.subtract(Duration(days: dayOfWeek));
    return '${sun.year}-${sun.month.toString().padLeft(2, '0')}-${sun.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.table_chart_outlined,
                size: 54,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tidak ada data pesanan pada tabel',
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
              if (widget.onAddNew != null) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: widget.onAddNew,
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

    // Urutkan item dari tanggal terbaru ke terlama
    final sortedItems = [...widget.items]..sort((a, b) => b.date.compareTo(a.date));

    // Kelompokkan berdasarkan minggu
    final Map<String, List<ProductionScheduleItem>> groups = {};
    final Map<String, String> groupLabels = {};

    for (final item in sortedItems) {
      final key = _getWeekKey(item.date);
      if (!groups.containsKey(key)) {
        groups[key] = [];
        groupLabels[key] = _getWeekLabel(item.date);
      }
      groups[key]!.add(item);
    }

    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minTableWidth = 1160.0;
          final tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                children: groups.entries.map((entry) {
              final key = entry.key;
              final label = groupLabels[key] ?? key;
              final groupItems = entry.value;
              final isCollapsed = _collapsedGroups.contains(key);

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Group Toggle Header (Notion Style)
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isCollapsed) {
                            _collapsedGroups.remove(key);
                          } else {
                            _collapsedGroups.add(key);
                          }
                        });
                      },
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(7),
                            topRight: const Radius.circular(7),
                            bottomLeft: isCollapsed ? const Radius.circular(7) : Radius.zero,
                            bottomRight: isCollapsed ? const Radius.circular(7) : Radius.zero,
                          ),
                          border: Border(
                            bottom: isCollapsed
                                ? BorderSide.none
                                : const BorderSide(color: Color(0xFFE5E7EB), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCollapsed
                                  ? Icons.arrow_right_rounded
                                  : Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${groupItems.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Table Body if not collapsed
                    if (!isCollapsed) ...[
                      // Table Columns Header
                      Container(
                        color: const Color(0xFFFBFBFB),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: const [
                            SizedBox(width: 130, child: Text('📅 Tanggal', style: _headerStyle)),
                            SizedBox(width: 210, child: Text('Aa Nama', style: _headerStyle)),
                            SizedBox(width: 100, child: Text('👤 PIC', style: _headerStyle)),
                            SizedBox(width: 140, child: Text('≡ Catatan', style: _headerStyle)),
                            SizedBox(width: 80, child: Text('📎 Media', style: _headerStyle)),
                            SizedBox(width: 120, child: Text('👥 Pelanggan', style: _headerStyle)),
                            SizedBox(width: 65, child: Text('# Qty', style: _headerStyle)),
                            SizedBox(width: 140, child: Text('☼ Status', style: _headerStyle)),
                            SizedBox(width: 120, child: Text('🏷️ Type', style: _headerStyle)),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: Color(0xFFE5E7EB)),

                      // Rows
                      ...groupItems.map((item) => _buildTableRow(item)),
                    ],
                  ],
                ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
      },
    ),
  );
}

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF6B7280),
  );

  Widget _buildTableRow(ProductionScheduleItem item) {
    final bgStatus = widget.getStatusBgColor(item.status);
    final textStatus = widget.getStatusTextColor(item.status);
    final hasImage = item.imageUrl != null && item.imageUrl!.trim().isNotEmpty;

    return InkWell(
      onTap: () => widget.onItemTap(item),
      hoverColor: const Color(0xFFF9FAFB),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
          ),
        ),
        child: Row(
          children: [
            // 📅 Tanggal
            SizedBox(
              width: 130,
              child: Text(
                _formatDate(item.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Aa Nama
            SizedBox(
              width: 210,
              child: Row(
                children: [
                  const Text('📄 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 👤 PIC
            SizedBox(
              width: 100,
              child: item.pic != null && item.pic!.trim().isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.pic!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7E22CE),
                        ),
                      ),
                    )
                  : const Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ),

            // ≡ Catatan
            SizedBox(
              width: 140,
              child: Text(
                item.description != null && item.description!.trim().isNotEmpty
                    ? item.description!.trim()
                    : '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
              ),
            ),

            // 📎 Media
            SizedBox(
              width: 80,
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: buildScheduleImage(
                        item.imageUrl,
                        width: 28,
                        height: 28,
                        placeholder: const Text('-', style: TextStyle(color: Color(0xFF9CA3AF))),
                      ),
                    )
                  : const Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ),

            // 👥 Pelanggan
            SizedBox(
              width: 120,
              child: item.customer != null && item.customer!.trim().isNotEmpty
                  ? Container(
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFBE185D),
                        ),
                      ),
                    )
                  : const Text('-', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ),

            // # Qty
            SizedBox(
              width: 65,
              child: Text(
                item.qty != null ? '${item.qty}' : '-',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
            ),

            // ☼ Status
            SizedBox(
              width: 140,
              child: Container(
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
                    Flexible(
                      child: Text(
                        item.status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textStatus,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 🏷️ Type
            SizedBox(
              width: 120,
              child: Text(
                item.cageType != null && item.cageType!.trim().isNotEmpty
                    ? item.cageType!.trim()
                    : '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
