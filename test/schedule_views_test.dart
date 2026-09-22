import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katalog/pages/schedule_production_page.dart';
import 'package:katalog/services/schedule_service.dart';
import 'package:katalog/widgets/schedule/schedule_board_view.dart';
import 'package:katalog/widgets/schedule/schedule_gallery_view.dart';
import 'package:katalog/widgets/schedule/schedule_table_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyItems = [
    ProductionScheduleItem(
      id: 'test_1',
      title: 'Sangkar Kosan R.10 Custom',
      date: DateTime(2026, 9, 20),
      customer: 'Haji Ahmad',
      cageType: 'Kosan R10',
      qty: 2,
      status: 'Sedang berlangsung',
      pic: 'Budi',
      description: 'Pengerjaan ukir naga',
    ),
    ProductionScheduleItem(
      id: 'test_2',
      title: 'Sangkar Murai No.2 Jati',
      date: DateTime(2026, 9, 21),
      customer: 'Pak Bambang',
      cageType: 'Bijian No.2',
      qty: 1,
      status: 'Siap Cetak',
      pic: 'Joko',
      description: 'Finishing natural',
    ),
  ];

  group('Schedule Views Rendering Tests', () {
    testWidgets('ScheduleGalleryView renders cards and details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduleGalleryView(
              items: dummyItems,
              onItemTap: (_) {},
              getStatusBgColor: (_) => Colors.blue.shade50,
              getStatusTextColor: (_) => Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Sangkar Kosan R.10 Custom'), findsOneWidget);
      expect(find.text('Sangkar Murai No.2 Jati'), findsOneWidget);
      expect(find.text('Haji Ahmad'), findsOneWidget);
      expect(find.text('Pak Bambang'), findsOneWidget);
    });

    testWidgets('ScheduleBoardView renders 5 status columns and items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduleBoardView(
              items: dummyItems,
              onItemTap: (_) {},
              getStatusBgColor: (_) => Colors.blue.shade50,
              getStatusTextColor: (_) => Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Belum dimulai'), findsOneWidget);
      expect(find.text('Sedang berlangsung'), findsWidgets);
      expect(find.text('Siap Cetak'), findsWidgets);
      expect(find.text('Di Cetak'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);

      expect(find.text('Sangkar Kosan R.10 Custom'), findsOneWidget);
      expect(find.text('Sangkar Murai No.2 Jati'), findsOneWidget);
    });

    testWidgets('ScheduleTableView renders grouped week header and columns', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduleTableView(
              items: dummyItems,
              onItemTap: (_) {},
              getStatusBgColor: (_) => Colors.blue.shade50,
              getStatusTextColor: (_) => Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('📅 Tanggal'), findsOneWidget);
      expect(find.text('Aa Nama'), findsOneWidget);
      expect(find.text('Sangkar Kosan R.10 Custom'), findsOneWidget);
      expect(find.text('Sangkar Murai No.2 Jati'), findsOneWidget);
    });

    testWidgets('ScheduleProductionPage renders all 5 tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ScheduleProductionPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bulanan'), findsOneWidget);
      expect(find.text('Mingguan'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Board'), findsOneWidget);
      expect(find.text('Table'), findsOneWidget);

      // Tap on Gallery tab
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleGalleryView), findsOneWidget);

      // Tap on Board tab
      await tester.tap(find.text('Board'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleBoardView), findsOneWidget);

      // Tap on Table tab
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleTableView), findsOneWidget);

      // Open New dialog and check mandatory upload UI
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      expect(find.text('Upload Foto dari Laptop / HP'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Wajib')),
        findsWidgets,
      );

      // Try submitting with title filled but no image
      final dialogTextFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(dialogTextFields.first, 'Kegiatan Tanpa Gambar');
      await tester.tap(find.text('Save to Schedule'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Foto atau gambar desain wajib diunggah atau diisi!'), findsOneWidget);
    });
  });
}
