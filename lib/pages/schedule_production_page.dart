import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/schedule_service.dart';
import '../services/storage_service.dart';
import '../widgets/schedule/schedule_board_view.dart';
import '../widgets/schedule/schedule_gallery_view.dart';
import '../widgets/schedule/schedule_image_helper.dart';
import '../widgets/schedule/schedule_table_view.dart';

/// Halaman Schedule Proses Pembuatan (Khusus Admin)
/// Mengadopsi sistem Workspace Jatimas Design (Notion-style) dari https://jatimas.beelink.web.id/
/// dengan 2 mode tampilan utama:
/// 1. Tampilan Bulanan (Monthly Calendar Grid dengan event pills)
/// 2. Tampilan Mingguan (Weekly 7-Column Grid dengan weekly cards)
class ScheduleProductionPage extends StatefulWidget {
  const ScheduleProductionPage({super.key});

  @override
  State<ScheduleProductionPage> createState() => _ScheduleProductionPageState();
}

class _ScheduleProductionPageState extends State<ScheduleProductionPage> {
  // Mode View aktif: 'Bulanan' atau 'Mingguan'
  String _activeView = 'Bulanan';

  // Tanggal acuan saat ini
  late DateTime _currentDate;
  late DateTime _selectedDate;
  late DateTime _nowRealTime;
  Timer? _clockTimer;

  // Filter & Pencarian
  String _searchQuery = '';
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
  final List<String> _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  final List<String> _statusOptions = [
    'Belum dimulai',
    'Sedang berlangsung',
    'Siap Cetak',
    'Di Cetak',
    'Selesai',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _nowRealTime = now;
    _currentDate = DateTime(now.year, now.month, now.day);
    _selectedDate = DateTime(now.year, now.month, now.day);

    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _nowRealTime = DateTime.now();
        });
      }
    });

    ProductionScheduleService.instance.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    ProductionScheduleService.instance.removeListener(_onServiceUpdate);
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateYMD(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _formatIndonesianFullDate(DateTime date) {
    final weekdays = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    final dayName = weekdays[date.weekday - 1];
    final monthName = _monthNames[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  // Navigasi Bulanan
  void _navigateMonth(int delta) {
    setState(() {
      if (delta == 0) {
        final now = DateTime.now();
        _currentDate = DateTime(now.year, now.month, now.day);
        _selectedDate = _currentDate;
      } else {
        _currentDate = DateTime(_currentDate.year, _currentDate.month + delta, 1);
      }
    });
  }

  // Navigasi Mingguan
  void _navigateWeek(int delta) {
    setState(() {
      if (delta == 0) {
        final now = DateTime.now();
        _currentDate = DateTime(now.year, now.month, now.day);
        _selectedDate = _currentDate;
      } else {
        _currentDate = _currentDate.add(Duration(days: delta * 7));
      }
    });
  }

  // Mengambil daftar item terfilter
  List<ProductionScheduleItem> get _filteredItems {
    final all = ProductionScheduleService.instance.items;
    return all.where((it) {
      final matchesQuery = _searchQuery.isEmpty ||
          it.title.toLowerCase().contains(_searchQuery) ||
          (it.customer != null && it.customer!.toLowerCase().contains(_searchQuery)) ||
          (it.cageType != null && it.cageType!.toLowerCase().contains(_searchQuery)) ||
          (it.description != null && it.description!.toLowerCase().contains(_searchQuery));

      final matchesStatus = _statusFilter == 'all' ||
          it.status.toLowerCase() == _statusFilter.toLowerCase();

      return matchesQuery && matchesStatus;
    }).toList();
  }

  // Warna Pill Status sesuai desain Jatimas Notion
  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
        return const Color(0xFFD1FAE5); // Emerald light
      case 'di cetak':
        return const Color(0xFFFEF3C7); // Yellow light
      case 'siap cetak':
        return const Color(0xFFFFEDD5); // Orange light
      case 'sedang berlangsung':
        return const Color(0xFFDBEAFE); // Blue light
      case 'belum dimulai':
      default:
        return const Color(0xFFF3F4F6); // Gray light
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'selesai':
        return const Color(0xFF047857);
      case 'di cetak':
        return const Color(0xFFB45309);
      case 'siap cetak':
        return const Color(0xFFC2410C);
      case 'sedang berlangsung':
        return const Color(0xFF1D4ED8);
      case 'belum dimulai':
      default:
        return const Color(0xFF4B5563);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5A3E28),
                Color(0xFF382314),
                Color(0xFF24150B),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'DIVISI JATIMAS',
                            style: TextStyle(
                              color: Color(0xFFFFD900),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            'Schedule Proses Pembuatan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Real-time Clock Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFFFFD900),
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_nowRealTime.day.toString().padLeft(2, '0')}/${_nowRealTime.month.toString().padLeft(2, '0')}/${_nowRealTime.year} ${_nowRealTime.hour.toString().padLeft(2, '0')}:${_nowRealTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Notion-style Tabs Bar (Bulanan, Mingguan, Gallery, Board, Table) & Filter Controls
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;
                final rowChildren = [
                  // Tab Buttons: Bulanan, Mingguan, Gallery, Board, Table
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildViewTabButton(
                          viewName: 'Bulanan',
                          icon: '📅',
                          label: 'Bulanan',
                        ),
                        const SizedBox(width: 4),
                        _buildViewTabButton(
                          viewName: 'Mingguan',
                          icon: '📆',
                          label: 'Mingguan',
                        ),
                        const SizedBox(width: 4),
                        _buildViewTabButton(
                          viewName: 'Gallery',
                          icon: '🖼️',
                          label: 'Gallery',
                        ),
                        const SizedBox(width: 4),
                        _buildViewTabButton(
                          viewName: 'Board',
                          icon: '📋',
                          label: 'Board',
                        ),
                        const SizedBox(width: 4),
                        _buildViewTabButton(
                          viewName: 'Table',
                          icon: '📊',
                          label: 'Table',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Filter Status Dropdown
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF6B7280)),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600),
                        onChanged: (val) {
                          if (val != null) setState(() => _statusFilter = val);
                        },
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                          ..._statusOptions.map((st) => DropdownMenuItem(value: st, child: Text(st))),
                        ],
                      ),
                    ),
                  ),

                  if (isWide) const Spacer() else const SizedBox(width: 14),

                  // Search Box
                  SizedBox(
                    width: 200,
                    height: 34,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Cari kegiatan/produk...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF9CA3AF)),
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Tombol New Page / Tambah
                  ElevatedButton.icon(
                    onPressed: () => _showAddOrEditDialog(initialDate: _selectedDate),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('New'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A4B29),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 34),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ];

                if (isWide) {
                  return Row(children: rowChildren);
                } else {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: rowChildren),
                  );
                }
              },
            ),
          ),

          // 2. Konten Tampilan Aktif (Bulanan, Mingguan, Gallery, Board, Table)
          Expanded(
            child: _buildCurrentView(isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView(bool isDesktop) {
    switch (_activeView) {
      case 'Mingguan':
        return _buildMingguanView(isDesktop);
      case 'Gallery':
        return ScheduleGalleryView(
          items: _filteredItems,
          onItemTap: (item) => _showAddOrEditDialog(existingItem: item),
          onAddNew: () => _showAddOrEditDialog(initialDate: _selectedDate),
          getStatusBgColor: _getStatusBgColor,
          getStatusTextColor: _getStatusTextColor,
        );
      case 'Board':
        return ScheduleBoardView(
          items: _filteredItems,
          onItemTap: (item) => _showAddOrEditDialog(existingItem: item),
          onAddNewWithStatus: (status) => _showAddOrEditDialog(
            initialDate: _selectedDate,
            defaultStatus: status,
          ),
          getStatusBgColor: _getStatusBgColor,
          getStatusTextColor: _getStatusTextColor,
        );
      case 'Table':
        return ScheduleTableView(
          items: _filteredItems,
          onItemTap: (item) => _showAddOrEditDialog(existingItem: item),
          onAddNew: () => _showAddOrEditDialog(initialDate: _selectedDate),
          getStatusBgColor: _getStatusBgColor,
          getStatusTextColor: _getStatusTextColor,
        );
      case 'Bulanan':
      default:
        return _buildBulananView(isDesktop);
    }
  }

  Widget _buildViewTabButton({
    required String viewName,
    required String icon,
    required String label,
  }) {
    final isActive = _activeView == viewName;

    return InkWell(
      onTap: () {
        setState(() {
          _activeView = viewName;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? const Color(0xFF1F2937) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TAMPILAN BULANAN (MONTHLY CALENDAR VIEW - NOTION STYLE)
  // ===========================================================================
  Widget _buildBulananView(bool isDesktop) {
    final year = _currentDate.year;
    final month = _currentDate.month;
    final monthTitle = '${_monthNames[month - 1]} $year';
    final items = _filteredItems;

    return Column(
      children: [
        // Navigation Bar Kalender Bulanan
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => _navigateMonth(-1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () => _navigateMonth(0),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () => _navigateMonth(1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF4B5563)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Body Grid Bulanan
        Expanded(
          child: isDesktop
              ? _buildDesktopMonthlyGrid(items, year, month)
              : _buildMobileMonthlyView(items, year, month),
        ),
      ],
    );
  }

  // Grid Kalender Bulanan Desktop (7 Kolom dengan Event Pills)
  Widget _buildDesktopMonthlyGrid(List<ProductionScheduleItem> items, int year, int month) {
    final firstDayWeekday = DateTime(year, month, 1).weekday % 7; // 0 = Min, 1 = Sen, ...
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final prevMonthDays = DateTime(year, month, 0).day;
    final prevYear = month == 1 ? year - 1 : year;
    final prevMonth = month == 1 ? 12 : month - 1;

    final nextYear = month == 12 ? year + 1 : year;
    final nextMonth = month == 12 ? 1 : month + 1;

    final totalCells = firstDayWeekday + daysInMonth;
    final remainingSlots = (7 - (totalCells % 7)) % 7;
    final totalGridCells = totalCells + remainingSlots;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Hari (Min - Sab)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: _dayNames.map((d) {
                final isSunday = d == 'Min';
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(top: 8, bottom: 8, right: 10),
                    alignment: Alignment.centerRight,
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSunday ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Grid Tanggal
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rowsCount = (totalGridCells / 7).ceil();
                final cellHeight = constraints.maxHeight / rowsCount;

                return SingleChildScrollView(
                  child: Column(
                    children: List.generate(rowsCount, (rowIndex) {
                      return SizedBox(
                        height: cellHeight < 95 ? 95 : cellHeight,
                        child: Row(
                          children: List.generate(7, (colIndex) {
                            final cellIndex = rowIndex * 7 + colIndex;

                            // 1. Bulan Sebelumnya
                            if (cellIndex < firstDayWeekday) {
                              final dayNum = prevMonthDays - firstDayWeekday + 1 + cellIndex;
                              final date = DateTime(prevYear, prevMonth, dayNum);
                              return Expanded(
                                child: _buildMonthlyCell(
                                  date: date,
                                  dayNumber: dayNum,
                                  isOtherMonth: true,
                                  items: items,
                                ),
                              );
                            }
                            // 2. Bulan Aktif
                            else if (cellIndex < firstDayWeekday + daysInMonth) {
                              final dayNum = cellIndex - firstDayWeekday + 1;
                              final date = DateTime(year, month, dayNum);
                              return Expanded(
                                child: _buildMonthlyCell(
                                  date: date,
                                  dayNumber: dayNum,
                                  isOtherMonth: false,
                                  items: items,
                                ),
                              );
                            }
                            // 3. Bulan Berikutnya
                            else {
                              final dayNum = cellIndex - (firstDayWeekday + daysInMonth) + 1;
                              final date = DateTime(nextYear, nextMonth, dayNum);
                              return Expanded(
                                child: _buildMonthlyCell(
                                  date: date,
                                  dayNumber: dayNum,
                                  isOtherMonth: true,
                                  items: items,
                                ),
                              );
                            }
                          }),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Sel Tanggal pada Tampilan Bulanan
  Widget _buildMonthlyCell({
    required DateTime date,
    required int dayNumber,
    required bool isOtherMonth,
    required List<ProductionScheduleItem> items,
  }) {
    final dateStr = _formatDateYMD(date);
    final dayItems = items.where((it) => _formatDateYMD(it.date) == dateStr).toList();
    final isToday = _isSameDay(date, _nowRealTime);
    final isSelected = _isSameDay(date, _selectedDate);

    return InkWell(
      onTap: () {
        setState(() => _selectedDate = date);
        _showAddOrEditDialog(initialDate: date);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF5EFE9)
              : isToday
                  ? const Color(0xFFFFFBEB)
                  : Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        ),
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nomor Tanggal di Pojok Kanan Atas
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? const Color(0xFFDC2626) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  dayNumber == 1
                      ? '${_monthNames[date.month - 1].substring(0, 3)} 1'
                      : '$dayNumber',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                    color: isToday
                        ? Colors.white
                        : isOtherMonth
                            ? const Color(0xFF9CA3AF)
                            : (date.weekday == DateTime.sunday)
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF374151),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 2),

            // Event Pills di dalam Sel
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: dayItems.length,
                itemBuilder: (context, i) {
                  final item = dayItems[i];
                  return _buildCalendarEventPill(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pill Event di dalam Sel Kalender Bulanan
  Widget _buildCalendarEventPill(ProductionScheduleItem item) {
    final bgColor = _getStatusBgColor(item.status);
    final textColor = _getStatusTextColor(item.status);

    return InkWell(
      onTap: () => _showAddOrEditDialog(existingItem: item),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Text('📄', style: TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tampilan Bulanan untuk Layar Mobile
  Widget _buildMobileMonthlyView(List<ProductionScheduleItem> items, int year, int month) {
    final selectedDateItems = items.where((it) => _isSameDay(it.date, _selectedDate)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid Kalender Mini
          _buildMobileMiniCalendarGrid(items, year, month),
          const SizedBox(height: 18),

          // Agenda Hari Terpilih
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pesanan: ${_formatIndonesianFullDate(_selectedDate)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A4B29).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedDateItems.length} Kegiatan',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7A4B29)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (selectedDateItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(
                child: Text(
                  'Tidak ada pesanan / kegiatan pada tanggal ini.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            ...selectedDateItems.map(_buildWeeklyCard),
        ],
      ),
    );
  }

  Widget _buildMobileMiniCalendarGrid(List<ProductionScheduleItem> items, int year, int month) {
    final firstDayWeekday = DateTime(year, month, 1).weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final datesWithEvents = items.map((it) => _formatDateYMD(it.date)).toSet();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: _dayNames.map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstDayWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayWeekday) {
                return const SizedBox();
              }
              final dayNum = index - firstDayWeekday + 1;
              final date = DateTime(year, month, dayNum);
              final isSel = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, _nowRealTime);
              final hasEvents = datesWithEvents.contains(_formatDateYMD(date));

              return InkWell(
                onTap: () => setState(() => _selectedDate = date),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF7A4B29)
                        : isToday
                            ? const Color(0xFFFFFBEB)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSel ? Border.all(color: const Color(0xFFD4AF37)) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel || isToday ? FontWeight.bold : FontWeight.w500,
                          color: isSel ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                      if (hasEvents)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: isSel ? Colors.white : const Color(0xFFEA580C),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. TAMPILAN MINGGUAN (WEEKLY 7-COLUMN GRID - NOTION STYLE)
  // ===========================================================================
  Widget _buildMingguanView(bool isDesktop) {
    // Cari hari pertama minggu (Minggu)
    final curr = _currentDate;
    final dayOfWeek = curr.weekday % 7; // 0 = Minggu
    final startOfWeek = curr.subtract(Duration(days: dayOfWeek));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final weekRangeTitle = startOfWeek.month == endOfWeek.month
        ? '${startOfWeek.day} - ${endOfWeek.day} ${_monthNames[startOfWeek.month - 1]} ${startOfWeek.year}'
        : '${startOfWeek.day} ${_monthNames[startOfWeek.month - 1].substring(0, 3)} - ${endOfWeek.day} ${_monthNames[endOfWeek.month - 1].substring(0, 3)} ${startOfWeek.year}';

    final items = _filteredItems;

    return Column(
      children: [
        // Navigation Bar Kalender Mingguan
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                weekRangeTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => _navigateWeek(-1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () => _navigateWeek(0),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton(
                    onPressed: () => _navigateWeek(1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 30),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF4B5563)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 7 Kolom Mingguan (Desktop) ATAU Date-Strip + Agenda (Mobile)
        Expanded(
          child: isDesktop
              ? _buildDesktopWeeklyGrid(items, startOfWeek)
              : _buildMobileWeeklyView(items, startOfWeek),
        ),
      ],
    );
  }

  // 7 Kolom Vertikal Kalender Mingguan Desktop
  Widget _buildDesktopWeeklyGrid(List<ProductionScheduleItem> items, DateTime startOfWeek) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(7, (i) {
          final date = startOfWeek.add(Duration(days: i));
          final dateStr = _formatDateYMD(date);
          final dayItems = items.where((it) => _formatDateYMD(it.date) == dateStr).toList();
          final isToday = _isSameDay(date, _nowRealTime);
          final dayName = _dayNames[i];

          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: i < 6 ? const BorderSide(color: Color(0xFFE5E7EB)) : BorderSide.none,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Kolom Header: Hari & Nomor Tanggal
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: dayName == 'Min' ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
                          ),
                        ),
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isToday ? const Color(0xFFDC2626) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            date.day == 1
                                ? '${_monthNames[date.month - 1].substring(0, 3)} 1'
                                : '${date.day}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                              color: isToday ? Colors.white : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Kolom Body: Daftar Kartu Mingguan (Weekly Cards)
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        ...dayItems.map(_buildWeeklyCard),

                        // Tombol Tambah Cepat di Hari Ini
                        InkWell(
                          onTap: () => _showAddOrEditDialog(initialDate: date),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add, size: 14, color: Color(0xFF9CA3AF)),
                                SizedBox(width: 4),
                                Text(
                                  'New',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // Kartu Jadwal / Pesanan di Tampilan Mingguan (Weekly Card)
  Widget _buildWeeklyCard(ProductionScheduleItem item) {
    final statusBg = _getStatusBgColor(item.status);
    final statusText = _getStatusTextColor(item.status);

    return InkWell(
      onTap: () => _showAddOrEditDialog(existingItem: item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul Kegiatan / Produk
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📄', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Pelanggan (Jika ada)
            if (item.customer != null && item.customer!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 11, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.customer!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Type Sangkar / Qty / Jam
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (item.cageType != null && item.cageType!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.cageType!,
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                    ),
                  ),
                if (item.qty != null && item.qty! > 0)
                  Text(
                    'Qty: ${item.qty}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.bold),
                  ),
                if (item.time != null && item.time!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded, size: 10, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 2),
                      Text(item.time!, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: statusText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tampilan Mingguan untuk Layar Mobile
  Widget _buildMobileWeeklyView(List<ProductionScheduleItem> items, DateTime startOfWeek) {
    final selectedDateItems = items.where((it) => _isSameDay(it.date, _selectedDate)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 7-Day Date Strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: List.generate(7, (i) {
                final date = startOfWeek.add(Duration(days: i));
                final isSel = _isSameDay(date, _selectedDate);
                final isToday = _isSameDay(date, _nowRealTime);

                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedDate = date),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF7A4B29) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _dayNames[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white70 : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSel || isToday ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? Colors.white : (isToday ? const Color(0xFFDC2626) : const Color(0xFF1F2937)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 18),

          // Agenda Hari Terpilih
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pesanan: ${_formatIndonesianFullDate(_selectedDate)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7A4B29).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedDateItems.length} Desain',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7A4B29)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (selectedDateItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Center(
                child: Text(
                  'Tidak ada pesanan / kegiatan pada tanggal ini.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            ...selectedDateItems.map(_buildWeeklyCard),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. DIALOG TAMBAH & EDIT KEGIATAN (NOTION STYLE)
  // ===========================================================================
  void _showAddOrEditDialog({
    ProductionScheduleItem? existingItem,
    DateTime? initialDate,
    String? defaultStatus,
  }) {
    final isEdit = existingItem != null;
    final titleCtrl = TextEditingController(text: existingItem?.title ?? '');
    final customerCtrl = TextEditingController(text: existingItem?.customer ?? '');
    final cageTypeCtrl = TextEditingController(text: existingItem?.cageType ?? '');
    final qtyCtrl = TextEditingController(text: existingItem?.qty?.toString() ?? '');
    final timeCtrl = TextEditingController(text: existingItem?.time ?? '');
    final descCtrl = TextEditingController(text: existingItem?.description ?? '');
    final imageUrlCtrl = TextEditingController(text: existingItem?.imageUrl ?? '');
    String? uploadedFileName;
    bool isUploadingImage = false;
    DateTime dialogDate = existingItem?.date ?? initialDate ?? _selectedDate;
    String selectedStatus = existingItem?.status ?? defaultStatus ?? 'Sedang berlangsung';

    InputDecoration formInputDecoration({required String hintText}) {
      return InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9BAA)),
        filled: true,
        fillColor: const Color(0xFFE5E2EC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC6C3CF), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC6C3CF), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6E3D20), width: 1.5),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFEDEBF2),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            titlePadding: const EdgeInsets.fromLTRB(22, 18, 18, 12),
            contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('📄', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      isEdit ? 'Edit Page (Pesanan Desain)' : 'New Page (Pesanan Desain)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF4B5563)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 18,
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama Pesanan / Produk
                    RichText(
                      text: const TextSpan(
                        text: 'Nama ',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        children: [
                          TextSpan(text: '*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
                      decoration: formInputDecoration(hintText: 'Untitled (misal: Sangkar Kosan R.10)'),
                    ),

                    const SizedBox(height: 12),

                    // Pelanggan & Type Sangkar
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pelanggan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: customerCtrl,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
                                decoration: formInputDecoration(hintText: 'Contoh: Budi Santoso'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Type Sangkar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: cageTypeCtrl,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
                                decoration: formInputDecoration(hintText: 'Contoh: Kosan R.10'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Status & Qty
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                              const SizedBox(height: 6),
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E2EC),
                                  border: Border.all(color: const Color(0xFFC6C3CF), width: 1.0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedStatus,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4B5563)),
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w600),
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => selectedStatus = val);
                                    },
                                    items: _statusOptions.map((st) => DropdownMenuItem(value: st, child: Text(st))).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Qty (Jumlah)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
                                decoration: formInputDecoration(hintText: 'Contoh: 1'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Tanggal & Jam
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tanggal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: dialogDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      dialogDate = DateTime(picked.year, picked.month, picked.day);
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFC6C3CF), width: 1.0),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF6E3D20)),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${dialogDate.day} ${_monthNames[dialogDate.month - 1].substring(0, 3)} ${dialogDate.year}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Waktu / Jam (Opsional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: timeCtrl,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
                                decoration: formInputDecoration(hintText: '08:00 - 12:00'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // File & Media / Foto Desain (Wajib)
                    RichText(
                      text: const TextSpan(
                        text: 'File & Media / Foto Desain ',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                        children: [
                          TextSpan(text: '*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          TextSpan(text: ' (Wajib)', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Tombol Upload dari Laptop / HP
                    InkWell(
                      onTap: isUploadingImage
                          ? null
                          : () async {
                              try {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1600,
                                  maxHeight: 1600,
                                  imageQuality: 85,
                                );
                                if (picked != null) {
                                  setDialogState(() => isUploadingImage = true);
                                  final bytes = await picked.readAsBytes();
                                  final ext = picked.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
                                  final base64Fallback = 'data:image/$ext;base64,${base64Encode(bytes)}';

                                  String finalUrl = base64Fallback;
                                  try {
                                    final uploaded = await StorageService.instance.uploadBytes(
                                      bytes: bytes,
                                      prefix: 'schedule',
                                      originalFilename: picked.name,
                                    );
                                    if (uploaded != null && uploaded.isNotEmpty) {
                                      finalUrl = uploaded;
                                    }
                                  } catch (_) {}

                                  setDialogState(() {
                                    isUploadingImage = false;
                                    uploadedFileName = picked.name;
                                    imageUrlCtrl.text = finalUrl;
                                  });
                                }
                              } catch (e) {
                                setDialogState(() => isUploadingImage = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Gagal memilih gambar: $e'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6E3D20).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6E3D20).withValues(alpha: 0.3), width: 1.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isUploadingImage) ...[
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6E3D20)),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Mengunggah gambar...',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6E3D20)),
                              ),
                            ] else ...[
                              const Icon(Icons.cloud_upload_outlined, size: 19, color: Color(0xFF6E3D20)),
                              const SizedBox(width: 8),
                              const Text(
                                'Upload Foto dari Laptop / HP',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF6E3D20)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Preview foto jika sudah ada
                    if (imageUrlCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFC6C3CF)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: buildScheduleImage(
                                imageUrlCtrl.text.trim(),
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    uploadedFileName ?? 'Foto Desain Terpasang',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Siap tampil di Gallery, Board & Table',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  imageUrlCtrl.clear();
                                  uploadedFileName = null;
                                });
                              },
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                              tooltip: 'Hapus Foto',
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Atau Tempel Link/URL
                    TextField(
                      controller: imageUrlCtrl,
                      onChanged: (_) => setDialogState(() {}),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
                      decoration: formInputDecoration(hintText: 'Atau tempel URL gambar foto desain (https://...)'),
                    ),

                    const SizedBox(height: 12),

                    // Catatan
                    const Text('Catatan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Catatan proses pengerjaan, ukiran, atau bahan...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9E9BAA)),
                        filled: true,
                        fillColor: const Color(0xFFE5E2EC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFC6C3CF), width: 1.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFC6C3CF), width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF6E3D20), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
            actions: [
              Row(
                children: [
                  if (isEdit)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelete(existingItem);
                      },
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      label: const Text('Hapus', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF5B6170), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama kegiatan tidak boleh kosong!'), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }

                      final imageUrl = imageUrlCtrl.text.trim();
                      if (imageUrl.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Foto atau gambar desain wajib diunggah atau diisi!'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      final qtyVal = int.tryParse(qtyCtrl.text.trim());

                      if (isEdit) {
                        final updated = existingItem.copyWith(
                          title: title,
                          customer: customerCtrl.text.trim().isNotEmpty ? customerCtrl.text.trim() : null,
                          cageType: cageTypeCtrl.text.trim().isNotEmpty ? cageTypeCtrl.text.trim() : null,
                          qty: qtyVal,
                          date: dialogDate,
                          time: timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : null,
                          description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                          status: selectedStatus,
                          imageUrl: imageUrlCtrl.text.trim().isNotEmpty ? imageUrlCtrl.text.trim() : null,
                        );
                        ProductionScheduleService.instance.updateItem(updated);
                      } else {
                        final newItem = ProductionScheduleItem(
                          id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
                          title: title,
                          customer: customerCtrl.text.trim().isNotEmpty ? customerCtrl.text.trim() : null,
                          cageType: cageTypeCtrl.text.trim().isNotEmpty ? cageTypeCtrl.text.trim() : null,
                          qty: qtyVal,
                          date: dialogDate,
                          time: timeCtrl.text.trim().isNotEmpty ? timeCtrl.text.trim() : null,
                          description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                          status: selectedStatus,
                          imageUrl: imageUrlCtrl.text.trim().isNotEmpty ? imageUrlCtrl.text.trim() : null,
                        );
                        ProductionScheduleService.instance.addItem(newItem);
                      }

                      setState(() {
                        _currentDate = dialogDate;
                        _selectedDate = dialogDate;
                      });

                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6E3D20),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isEdit ? 'Save Changes' : 'Save to Schedule',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(ProductionScheduleItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Pesanan?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Hapus "${item.title}" dari jadwal proses pembuatan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              ProductionScheduleService.instance.deleteItem(item.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
