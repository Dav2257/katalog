// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:katalog/main.dart';
import 'package:katalog/pages/admin_order_detail_page.dart';
import 'package:katalog/pages/cart_page.dart';
import 'package:katalog/services/auth_service.dart';
import 'package:katalog/services/cage_service.dart';
import 'package:katalog/services/order_service.dart';
import 'package:katalog/services/settings_service.dart';
import 'package:katalog/widgets/hero_banner.dart';

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  static final _transparentImage = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ];

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    void Function()? onDone,
    Function? onError,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _MockHttpOverrides();
  });

  setUp(() {
    AuthService.instance.logout();
    OrderService.instance.resetForTesting();
  });
  testWidgets('TopNavbar and HeroBanner elements test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify logo 'JATIMAS' is present.
    expect(find.text('JATIMAS'), findsOneWidget);

    // Verify search bar is present.
    expect(find.byType(TextField), findsOneWidget);

    // Verify shopping cart icon is present.
    expect(find.byIcon(Icons.shopping_cart), findsOneWidget);

    // Verify profile icon is present.
    expect(find.byIcon(Icons.account_circle), findsOneWidget);

    // Verify full-width project logo banner is present.
    expect(find.byType(HeroBanner), findsOneWidget);
  });

  testWidgets('Cart icon opens CartPage', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap cart icon
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();

    // Verify CartPage is displayed
    expect(find.text('Keranjang Belanja'), findsOneWidget);
    expect(find.text('Keranjang Belanja Masih Kosong'), findsOneWidget);
  });

  testWidgets('Profile icon opens LoginPage when not logged in', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap profile icon
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    // Verify LoginPage is displayed with design elements
    expect(find.text('JATIMAS '), findsOneWidget);
    expect(find.text('SANGKAR'), findsOneWidget);
    expect(find.text('Sangkar Burung Pilihan'), findsOneWidget);
    expect(find.text('Masuk ke akun anda'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('MASUK'), findsOneWidget);
    expect(find.text('Masuk Cepat (Mode Demo)'), findsOneWidget);
  });

  testWidgets('Clicking product opens ProductDetailPage with cages, counter and note', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap first product
    await tester.tap(find.text('Sangkar Burung Ukir Jati Jepara Klasik'));
    await tester.pumpAndSettle();

    // Verify Breadcrumb
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text('Detail Produk'), findsOneWidget);

    // Verify Cage Options
    expect(find.text('Sangkar 1'), findsWidgets);
    expect(find.text('Sangkar 2'), findsOneWidget);
    expect(find.text('Sangkar 3'), findsOneWidget);
    expect(find.text('Sangkar 4'), findsOneWidget);

    // Verify initial Note section for Sangkar 1
    expect(find.text('Catatan Sangkar 1'), findsOneWidget);
    expect(find.text('0 / 100'), findsOneWidget);
    expect(find.text('Keranjang'), findsWidgets);
  });

  testWidgets('Different cage shapes have separate notes in the same place and separate items in cart', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // Open detail page
    await tester.tap(find.text('Sangkar Burung Ukir Jati Jepara Klasik'));
    await tester.pumpAndSettle();

    // 1. Enter note and quantity for Sangkar 1
    expect(find.text('Catatan Sangkar 1'), findsOneWidget);
    final noteField = find.byType(TextField).first;
    await tester.enterText(noteField, 'Ukiran naga tiang sangkar');
    await tester.pumpAndSettle();
    expect(find.text('25 / 100'), findsOneWidget);

    // Increase Sangkar 1 quantity
    final addButtons = find.byIcon(Icons.add);
    await tester.tap(addButtons.at(0));
    await tester.pumpAndSettle();

    // 2. Select Sangkar 2
    await tester.tap(find.text('Sangkar 2'));
    await tester.pumpAndSettle();

    // Note header switches to Sangkar 2 in the exact same place
    expect(find.text('Catatan Sangkar 2'), findsOneWidget);
    expect(find.text('0 / 100'), findsOneWidget);

    // Enter note and quantity for Sangkar 2
    await tester.enterText(noteField, 'Finishing hitam doff');
    await tester.pumpAndSettle();
    expect(find.text('20 / 100'), findsOneWidget);

    // Increase Sangkar 2 quantity
    await tester.tap(addButtons.at(1));
    await tester.pumpAndSettle();

    // 3. Switch back to Sangkar 1 to verify note is preserved
    await tester.tap(find.text('Sangkar 1').last);
    await tester.pumpAndSettle();
    expect(find.text('Catatan Sangkar 1'), findsOneWidget);
    expect(find.text('Ukiran naga tiang sangkar'), findsOneWidget);

    // 4. Submit to Cart
    await tester.tap(find.widgetWithText(OutlinedButton, 'Keranjang'));
    await tester.pumpAndSettle();

    // Verify indicator badge on cart icon is visible on detail page
    expect(find.byType(Badge), findsOneWidget);

    // Go back to home page
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    // Verify indicator badge on cart icon is ALSO visible on home page
    expect(find.byType(Badge), findsOneWidget);

    // 5. Open Cart Page
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();

    // Verify that both shapes appear as SEPARATE items in the cart
    expect(find.text('Keranjang Belanja'), findsOneWidget);
    expect(find.text('Pilih semua'), findsOneWidget);
    expect(find.text('Bentuk: Sangkar 1'), findsOneWidget);
    expect(find.text('Ukiran naga tiang sangkar'), findsOneWidget);
    expect(find.text('Bentuk: Sangkar 2'), findsOneWidget);
    expect(find.text('Finishing hitam doff'), findsOneWidget);

    // Initially no item is checked, so "Hapus Semua" should NOT appear
    expect(find.text('Hapus Semua'), findsNothing);

    // Tap "Pilih semua" checkbox to check all items
    await tester.tap(find.text('Pilih semua'));
    await tester.pumpAndSettle();

    // "Hapus Semua" must now APPEAR!
    expect(find.text('Hapus Semua'), findsOneWidget);

    // Verify Edit Catatan button is present for both items
    expect(find.text('Edit Catatan'), findsNWidgets(2));

    // Verify Total Pembayaran and Checkout Sekarang are removed
    expect(find.text('Total Pembayaran'), findsNothing);
    expect(find.text('Checkout Sekarang'), findsNothing);

    // Verify green Pesan button is present with WhatsAppLogo
    expect(find.text('Pesan'), findsOneWidget);
    expect(find.byType(WhatsAppLogo), findsOneWidget);

    // Test Edit Catatan feature in cart
    await tester.tap(find.text('Edit Catatan').first);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Edit Catatan')), findsOneWidget);
    final editField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(editField, 'Catatan Baru Hasil Edit');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Catatan Baru Hasil Edit'), findsOneWidget);

    // Test responsive deletion of first item (trash icon)
    final deleteIcons = find.byIcon(Icons.delete_rounded);
    expect(deleteIcons, findsNWidgets(2));
    await tester.tap(deleteIcons.first);
    await tester.pumpAndSettle();

    // Verify first item is IMMEDIATELY removed without page navigation
    expect(find.text('Catatan Baru Hasil Edit'), findsNothing);
    expect(find.text('Bentuk: Sangkar 2'), findsOneWidget);

    // Test deleting remaining item
    await tester.tap(find.byIcon(Icons.delete_rounded));
    await tester.pumpAndSettle();

    // Cart is now immediately empty on the same page
    expect(find.text('Keranjang Belanja Masih Kosong'), findsOneWidget);
  });

  testWidgets('User login opens UserHomePage with request button and custom logo catalog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. Initially guest sees standard catalog
    expect(find.text('Katalog Produk Pilihan'), findsOneWidget);
    expect(find.text('Permintaan Logo Custom'), findsNothing);

    // 2. Log in via demo mode
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    expect(find.text('Masuk Cepat (Mode Demo)'), findsOneWidget);
    await tester.tap(find.text('Masuk Cepat (Mode Demo)'));
    await tester.pumpAndSettle();

    // 3. User is now logged in: Dedicated UserHomePage is displayed
    expect(find.text('Katalog Umum'), findsOneWidget);
    expect(find.text('Permintaan Logo Custom'), findsOneWidget);
    expect(find.text('Katalog Logo Custom Saya'), findsOneWidget);
    expect(find.text('Logo Custom Naga Api Jepara'), findsOneWidget);
    expect(find.text('Logo Siluet Elang Perkasa'), findsOneWidget);

    // 4. Test 'Permintaan Logo Custom' button opens request modal
    await tester.tap(find.text('Permintaan Logo Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Permintaan Logo Custom Sangkar'), findsOneWidget);
    expect(find.text('Kirim Permintaan Logo Custom'), findsOneWidget);

    // Fill request form
    final nameField = find.widgetWithText(TextField, '').first;
    await tester.enterText(nameField, 'Logo Singa Emas Juara');
    await tester.tap(find.text('Kirim Permintaan Logo Custom'));
    await tester.pumpAndSettle();

    // Verify newly created custom logo is immediately shown in user catalog
    expect(find.text('Logo Singa Emas Juara'), findsOneWidget);
  });

  testWidgets('Data separation: guest cart and user cart are completely separated', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. Guest adds a standard product to guest cart
    await tester.tap(find.text('Sangkar Burung Ukir Jati Jepara Klasik'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Keranjang'));
    await tester.pumpAndSettle();

    // Verify guest cart has 1 item
    expect(find.byType(Badge), findsOneWidget);

    // Go back to home
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    // 2. User logs in
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk Cepat (Mode Demo)'));
    await tester.pumpAndSettle();

    // 3. User is now logged in. User cart is fresh/separate (0 items)
    expect(find.text('Katalog Logo Custom Saya'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // User adds custom logo to user cart
    await tester.tap(find.text('Logo Custom Naga Api Jepara'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Keranjang'));
    await tester.pumpAndSettle();

    // User cart now has 1 item
    expect(find.text('1'), findsOneWidget);

    // Return to home page
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    // 4. User logs out
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar dari akun'));
    await tester.pumpAndSettle();

    // Guest cart is restored with its original guest item
    expect(find.text('Katalog Produk Pilihan'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Cage management: + Tambah is admin-only, next button only visible when cages > 4', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. As GUEST (Umum): Open Product Detail
    await tester.tap(find.text('Sangkar Burung Ukir Jati Jepara Klasik'));
    await tester.pumpAndSettle();

    // Verify exactly 4 initial cages
    expect(find.text('Sangkar 1'), findsWidgets);
    expect(find.text('Sangkar 2'), findsOneWidget);
    expect(find.text('Sangkar 3'), findsOneWidget);
    expect(find.text('Sangkar 4'), findsOneWidget);

    // Guest should NOT see '+ Tambah'
    expect(find.text('+ Tambah'), findsNothing);

    // With 4 cages (<= 4), Next (>) and Prev (<) buttons should NOT be present
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);

    // Back to home
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    // 2. Login as regular USER (User Login)
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk Cepat (Mode Demo)'));
    await tester.pumpAndSettle();

    // User opens standard catalog
    await tester.tap(find.text('Katalog Umum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sangkar Burung Ukir Jati Jepara Klasik'));
    await tester.pumpAndSettle();

    // Regular user should NOT see '+ Tambah'
    expect(find.text('+ Tambah'), findsNothing);
    // Regular user should NOT see Next button when <= 4
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);

    // Back to home
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    // 3. Switch to ADMIN mode via profile sheet
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    expect(find.text('Beralih ke Akun Admin'), findsOneWidget);
    await tester.tap(find.text('Beralih ke Akun Admin'));
    await tester.pumpAndSettle();

    // Admin is now on AdminDashboardPage, enters preview mode via 'Preview Umum'
    expect(find.text('Preview Umum'), findsOneWidget);
    await tester.tap(find.text('Preview Umum'));
    await tester.pumpAndSettle();

    // Admin opens product detail
    await tester.tap(find.text('Sangkar Burung Ukir Jati Jepara Klasik'));
    await tester.pumpAndSettle();

    // Admin SEES '+ Tambah'
    expect(find.text('+ Tambah'), findsOneWidget);
    // Before adding, still 4 cages, so Next button is not yet visible
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);

    // Admin taps '+ Tambah' to add Sangkar 5
    await tester.tap(find.text('+ Tambah'));
    await tester.pumpAndSettle();

    // Now Sangkar 5 exists (total = 5 > 4)
    expect(find.text('Sangkar 5'), findsOneWidget);

    // Because cages > 4, Next (>) and Prev (<) buttons NOW APPEAR!
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    // Back to catalog
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    // 4. Switch back to regular User: verify user sees Sangkar 5 & Next button, but NOT '+ Tambah'
    await tester.tap(find.byIcon(Icons.admin_panel_settings_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beralih ke Akun Member'));
    await tester.pumpAndSettle();

    // On UserHomePage, open standard catalog
    await tester.tap(find.text('Katalog Umum'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sangkar Burung Ukir Jati Jepara Klasik'));
    await tester.pumpAndSettle();

    // User sees Sangkar 5 configured by Admin
    expect(find.text('Sangkar 5'), findsOneWidget);
    // User sees Next button because > 4 cages
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);
    // But User does NOT see '+ Tambah'
    expect(find.text('+ Tambah'), findsNothing);
  });

  testWidgets('Custom logo creation: cage selection, hashtag input, and design note unified in cart', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. Log in via demo mode
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk Cepat (Mode Demo)'));
    await tester.pumpAndSettle();

    // 2. Open Custom Logo request bottom sheet
    expect(find.text('Permintaan Logo Custom'), findsOneWidget);
    await tester.tap(find.text('Permintaan Logo Custom'));
    await tester.pumpAndSettle();

    // Verify modal elements
    expect(find.text('Permintaan Logo Custom Sangkar'), findsOneWidget);
    expect(find.text('Hashtag / Kategori Custom'), findsOneWidget);
    expect(find.text('Pilihan Bentuk Sangkar Burung'), findsOneWidget);

    // 3. Select 'Sangkar 2'
    await tester.tap(find.text('Sangkar 2'));
    await tester.pumpAndSettle();

    // 4. Fill form: Name, Hashtag, and Catatan Desain & Posisi Ukir
    final nameField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText?.contains('Harimau Putih') == true,
    );
    final hashtagField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText?.contains('#LogoCustomUkir') == true,
    );
    final noteField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText?.contains('Ukir timbul di mahkota') == true,
    );

    await tester.enterText(nameField, 'Logo Naga Emas Sakti');
    await tester.enterText(hashtagField, 'NagaSakti');
    await tester.enterText(noteField, 'Ukir timbul relief 3D pada mahkota dan tiang');

    // Submit request: otomatis langsung masuk ke katalog dan keranjang belanja
    await tester.tap(find.text('Kirim Permintaan Logo Custom'));
    await tester.pumpAndSettle();

    // 5. Verify custom logo card in catalog displays formatted hashtag and name
    expect(find.text('#NagaSakti'), findsOneWidget);
    expect(find.text('Logo Naga Emas Sakti'), findsOneWidget);

    // 6. Langsung buka Keranjang Belanja via TopNavbar dan buktikan produk custom sudah ada di keranjang!
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();

    expect(find.text('Keranjang Belanja'), findsOneWidget);
    expect(find.text('Logo Naga Emas Sakti'), findsOneWidget);
    expect(find.text('Bentuk: Sangkar 2'), findsOneWidget);
    expect(find.text('Catatan :   '), findsWidgets);
    expect(find.text('Ukir timbul relief 3D pada mahkota dan tiang'), findsOneWidget);

    // Kembali ke Beranda
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // 7. Buka Detail Produk Custom dari kartu di katalog untuk memastikan sinkronisasi pilihan sangkar & catatan
    await tester.tap(find.text('Logo Naga Emas Sakti'));
    await tester.pumpAndSettle();

    expect(find.text('Catatan Sangkar 2'), findsOneWidget);
    expect(find.text('Ukir timbul relief 3D pada mahkota dan tiang'), findsOneWidget);
  });

  testWidgets('Login, role switch, and logout directly from ProductDetailPage update state reactively', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. As GUEST: Open product detail directly
    await tester.tap(find.text('Sangkar Burung Ukir Jati Jepara Klasik'));
    await tester.pumpAndSettle();

    // Guest should NOT see '+ Tambah'
    expect(find.text('+ Tambah'), findsNothing);

    // 2. Tap profile icon while inside ProductDetailPage -> opens LoginPage
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke akun anda'), findsOneWidget);
    expect(find.text('Masuk Cepat (Mode Demo)'), findsOneWidget);

    // 3. Log in as regular member
    await tester.tap(find.text('Masuk Cepat (Mode Demo)'));
    await tester.pumpAndSettle();

    // Now user is back on ProductDetailPage!
    expect(find.text('Detail Produk'), findsOneWidget);

    // 4. Tap profile icon AGAIN while on ProductDetailPage:
    // Should OPEN PROFILE BOTTOM SHEET (NOT LoginPage again!)
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    expect(find.text('Member / Pengguna'), findsOneWidget);
    expect(find.text('Beralih ke Akun Admin'), findsOneWidget);
    expect(find.text('Keluar dari akun'), findsOneWidget);

    // 5. Switch to Admin directly from ProductDetailPage bottom sheet
    await tester.tap(find.text('Beralih ke Akun Admin'));
    await tester.pumpAndSettle();

    // Now user is ADMIN! TopNavbar shows ADMIN badge icon and '+ Tambah' is IMMEDIATELY VISIBLE!
    expect(find.byIcon(Icons.admin_panel_settings_rounded), findsOneWidget);
    expect(find.text('+ Tambah'), findsOneWidget);

    // 6. Tap admin profile icon again to logout
    await tester.tap(find.byIcon(Icons.admin_panel_settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Administrator'), findsOneWidget);
    await tester.tap(find.text('Keluar dari akun'));
    await tester.pumpAndSettle();

    // 7. Verified: Immediately logged out while still on ProductDetailPage!
    // '+ Tambah' is gone and TopNavbar shows guest account circle
    expect(find.text('+ Tambah'), findsNothing);
    expect(find.byIcon(Icons.account_circle), findsOneWidget);

    // 8. Tapping profile icon now opens LoginPage again!
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke akun anda'), findsOneWidget);
  });

  testWidgets('User umum (guest) does not have Pesanan Anda, only logged in user has Pesanan Anda', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. As GUEST (User Umum): Open Cart Page
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();

    // Verify "Pesanan Anda" section DOES NOT EXIST for user umum
    expect(find.text('Pesanan Anda'), findsNothing);
    expect(find.text('A01-Batman Swing biru cantik'), findsNothing);

    // Go back to home
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // 2. USER LOGS IN (Member)
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk Cepat (Mode Demo)'));
    await tester.pumpAndSettle();

    // 3. Open Cart Page as LOGGED-IN USER:
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();

    // Verify "Pesanan Anda" section IS DISPLAYED for logged-in user
    expect(find.text('Pesanan Anda'), findsOneWidget);
    expect(find.text('A01-Batman Swing biru cantik'), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.text('Design 1 bentuk 1'), findsOneWidget);
    expect(find.text('Status: '), findsOneWidget);
    expect(find.text('Tahap 1'), findsOneWidget);
    expect(find.text('Tambahkan tokoh superman bersandingan dengan batman'), findsOneWidget);

    // 4. USER LOGS OUT (becomes user umum again)
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar dari akun'));
    await tester.pumpAndSettle();

    // 5. Open Cart Page as GUEST again:
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();

    // Verified: "Pesanan Anda" is GONE for user umum!
    expect(find.text('Pesanan Anda'), findsNothing);
  });

  testWidgets('Admin Dashboard displays sidebar, metric cards, incoming orders table, and private users table', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. Open login page as Guest
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    // 2. Login directly as Admin
    expect(find.text('Masuk sebagai Admin (Mode Demo)'), findsOneWidget);
    await tester.tap(find.text('Masuk sebagai Admin (Mode Demo)'));
    await tester.pumpAndSettle();

    // 3. Verify Admin Dashboard Header & Sidebar
    expect(find.text('Admin 1'), findsOneWidget);
    expect(find.text('admin@gmail.com'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Pesanan'), findsWidgets);
    expect(find.text('User Private'), findsWidgets);
    expect(find.text('Preview Umum'), findsOneWidget);

    // 4. Verify Analisis Data Section & 5 Metric Cards
    expect(find.text('Analisis Data'), findsOneWidget);
    expect(find.text('JUMLAH DESIGN PRODUK'), findsOneWidget);
    expect(find.text('1.200'), findsOneWidget);
    expect(find.text('JUMLAH PESANAN'), findsOneWidget);
    expect(find.text('259'), findsOneWidget);
    expect(find.text('JUMLAH DESIGN REQUEST'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('JUMLAH BENTUK SANGKAR'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('JUMLAH PESANAN BARU'), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    // 5. Verify Pesanan Masuk Table
    expect(find.text('Pesanan Masuk'), findsOneWidget);
    expect(find.text('085113123142'), findsWidgets);
    expect(find.text('A01, A04'), findsWidgets);
    expect(find.text('Diproses'), findsWidgets);

    // 6. Verify User Private Table
    expect(find.text('085732257048'), findsWidgets);
    expect(find.text('admin123'), findsOneWidget);

    // 7. Verify Detail button dialog
    final detailButtons = find.text('Detail');
    expect(detailButtons, findsWidgets);
    await tester.ensureVisible(detailButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(detailButtons.first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Detail Pesanan'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    // 7b. Verify List Produk User Umum Section (matching screenshot)
    expect(find.text('List Produk User Umum'), findsOneWidget);
    expect(find.text('Cari berdasarkan:'), findsOneWidget);
    expect(find.text('Nama'), findsOneWidget);
    expect(find.text('Kode'), findsOneWidget);
    expect(find.text('A01-Batman Swing biru cantik'), findsWidgets);
    expect(find.text('#superhero #batman #DC'), findsWidgets);

    // 7c. Verify Sangkar Section (matching screenshot) and Tambah Sangkar button
    expect(find.text('Sangkar'), findsWidgets);
    expect(find.text('Tambah Sangkar'), findsOneWidget);

    // Tap 'Tambah Sangkar'
    await tester.ensureVisible(find.text('Tambah Sangkar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Sangkar'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Bentuk Sangkar'), findsOneWidget);
    expect(find.text('Simpan Sangkar'), findsOneWidget);
    await tester.tap(find.text('Simpan Sangkar'));
    await tester.pumpAndSettle();

    // Add multiple cages past 7 (Sangkar 6, 7, 8)
    for (int i = 0; i < 3; i++) {
      await tester.ensureVisible(find.text('Tambah Sangkar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah Sangkar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan Sangkar'));
      await tester.pumpAndSettle();
    }

    // Verified: Cages count is now past 7!
    expect(CageService.instance.count, greaterThan(7));
    expect(find.textContaining('${CageService.instance.count} Bentuk'), findsOneWidget);

    // Test scroll buttons
    expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsWidgets);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsWidgets);
    await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).last);
    await tester.pumpAndSettle();

    // 7d. Verify Riwayat Section (completed orders from all users)
    expect(find.text('Riwayat'), findsWidgets);
    expect(find.text('Diterima'), findsWidgets);
    expect(find.text('085113123148'), findsWidgets);

    // 8. Test Preview Umum banner and returning to Dashboard
    await tester.tap(find.text('Preview Umum'));
    await tester.pumpAndSettle();

    expect(find.text('Kembali ke Dashboard Admin'), findsOneWidget);
    await tester.tap(find.text('Kembali ke Dashboard Admin'));
    await tester.pumpAndSettle();

    // Returned back to Admin Dashboard
    expect(find.text('Analisis Data'), findsOneWidget);
    expect(find.text('Admin 1'), findsOneWidget);
  });

  testWidgets('Orders placed by user dynamically enter Admin Dashboard Pesanan Masuk and can be completed to Riwayat', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Start app as Guest
    await tester.pumpWidget(const MyApp());

    // 2. Open first product
    await tester.tap(find.text('Sangkar Burung Ukir Jati Jepara Klasik'));
    await tester.pumpAndSettle();

    // 3. Add to cart
    await tester.tap(find.widgetWithText(OutlinedButton, 'Keranjang'));
    await tester.pumpAndSettle();

    // Go back from product detail to Home
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    // 4. Open cart
    await tester.tap(find.byIcon(Icons.shopping_cart));
    await tester.pumpAndSettle();

    // 5. Select item and checkout
    await tester.tap(find.text('Pilih semua'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pesan'));
    await tester.pumpAndSettle();

    // In confirmation dialog, enter custom phone number
    await tester.enterText(find.byType(TextField).last, '081299887766');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kirim Pesanan'));
    await tester.pumpAndSettle();

    // 6. Go back from Cart to Home
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // 7. Login as Admin
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk sebagai Admin (Mode Demo)'));
    await tester.pumpAndSettle();

    // 8. Verify new user order '081299887766' appears in Pesanan Masuk!
    expect(find.text('Pesanan Masuk'), findsOneWidget);
    expect(find.text('081299887766'), findsOneWidget);

    // 9. Tap Detail on this order
    final detailButtons = find.text('Detail');
    expect(detailButtons, findsWidgets);
    await tester.ensureVisible(detailButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(detailButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('081299887766'), findsWidgets);
    expect(find.text('Selesaikan Pesanan'), findsOneWidget);

    // 10. Tap Selesaikan Pesanan
    await tester.tap(find.text('Selesaikan Pesanan'));
    await tester.pumpAndSettle();

    // 11. Verify it moved from Pesanan Masuk to Riwayat!
    expect(find.text('Riwayat'), findsWidgets);
    expect(find.text('081299887766'), findsOneWidget);
  });

  testWidgets('User registration on web dynamically enters Admin Dashboard User Private table', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. Open LoginPage
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    // 2. Switch to Registrasi mode
    expect(find.text('Registrasi'), findsOneWidget);
    await tester.tap(find.text('Registrasi'));
    await tester.pumpAndSettle();

    expect(find.text('Registrasi Akun Baru'), findsOneWidget);
    expect(find.text('DAFTAR SEKARANG'), findsOneWidget);

    // 3. Fill in registration form (Phone, Email, Password)
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    await tester.enterText(textFields.at(0), '081233445566'); // Phone
    await tester.enterText(textFields.at(1), 'budi@gmail.com'); // Email
    await tester.enterText(textFields.at(2), 'budi123'); // Password
    await tester.pumpAndSettle();

    // 4. Tap DAFTAR SEKARANG
    await tester.tap(find.text('DAFTAR SEKARANG'));
    await tester.pumpAndSettle();

    // 5. User is logged in as Member and sees UserHomePage (has 'Permintaan Logo Custom' button)
    expect(find.text('Permintaan Logo Custom'), findsOneWidget);

    // 6. Switch to Admin Dashboard
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    expect(find.text('Beralih ke Akun Admin'), findsOneWidget);
    await tester.tap(find.text('Beralih ke Akun Admin'));
    await tester.pumpAndSettle();

    // 7. Verify Admin Dashboard User Private table contains the new user!
    expect(find.text('User Private'), findsWidgets);
    expect(find.text('081233445566'), findsOneWidget);
    expect(find.text('budi123'), findsOneWidget);

    // 8. View Detail dialog for this newly registered user
    final userDetailBtn = find.byKey(const ValueKey('user_detail_081233445566'));
    expect(userDetailBtn, findsOneWidget);

    await tester.ensureVisible(userDetailBtn);
    await tester.pumpAndSettle();
    await tester.tap(userDetailBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Detail User Private'), findsOneWidget);
    expect(find.text('081233445566'), findsWidgets);
    expect(find.text('budi123'), findsWidgets);
    expect(find.text('Preview Katalog'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);

    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
  });

  testWidgets('Admin can add product via Tambah Produk button and it appears in public catalog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. Login as Admin
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk sebagai Admin (Mode Demo)'));
    await tester.pumpAndSettle();

    // 2. Locate and tap 'Tambah Produk' button in List Produk User Umum section
    final addProductBtn = find.widgetWithText(ElevatedButton, 'Tambah Produk');
    expect(addProductBtn, findsOneWidget);

    await tester.ensureVisible(addProductBtn);
    await tester.pumpAndSettle();
    await tester.tap(addProductBtn);
    await tester.pumpAndSettle();

    // 3. Verify AdminAddProductPage is displayed
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text(' / Tambah Produk Baru'), findsOneWidget);
    expect(find.text('Buat'), findsOneWidget);
    expect(find.text('Bentuk Sangkar'), findsOneWidget);

    // 4. Fill in product details
    await tester.enterText(find.byKey(const Key('admin_add_code_field')), 'A99'); // Kode
    await tester.enterText(find.byKey(const Key('admin_add_name_field')), 'Sangkar Ukir Rajawali Perkasa'); // Nama
    await tester.enterText(find.byKey(const Key('admin_add_hashtag_field')), '#rajawali #ukir #jati'); // Hashtags
    await tester.pumpAndSettle();

    // 5. Create product via 'Buat' button
    final buatBtn = find.widgetWithText(OutlinedButton, 'Buat');
    await tester.ensureVisible(buatBtn);
    await tester.pumpAndSettle();
    await tester.tap(buatBtn);
    await tester.pumpAndSettle();

    // 6. Verify newly added product is visible in Admin Dashboard list
    expect(find.text('A99-Sangkar Ukir Rajawali Perkasa'), findsOneWidget);
    expect(find.text('#rajawali #ukir #jati'), findsOneWidget);

    // 7. Go to Preview Umum (public catalog view)
    await tester.tap(find.text('Preview Umum'));
    await tester.pumpAndSettle();

    // 8. Verify the new product appears in the public user catalog!
    expect(find.text('Sangkar Ukir Rajawali Perkasa'), findsOneWidget);

    // 9. Clicking the new product opens ProductDetailPage
    await tester.tap(find.text('Sangkar Ukir Rajawali Perkasa'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Produk'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text('Sangkar Ukir Rajawali Perkasa'), findsWidgets);
    expect(find.text('Catatan Sangkar 1'), findsOneWidget);

    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
  });

  testWidgets('Admin can click public product card to edit details, add cage shapes, and sync with public catalog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. Login as Admin
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk sebagai Admin (Mode Demo)'));
    await tester.pumpAndSettle();

    // 2. Scroll to List Produk User Umum and click a product item
    final productFinder = find.text('A01-Batman Swing biru cantik').first;
    await tester.ensureVisible(productFinder);
    await tester.pumpAndSettle();

    await tester.tap(productFinder);
    await tester.pumpAndSettle();

    // 3. Verify AdminEditProductPage is displayed matching reference design
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text(' / Detail Produk'), findsOneWidget);
    expect(find.text('Bentuk Sangkar'), findsOneWidget);
    expect(find.text('Sangkar 1'), findsOneWidget);
    expect(find.text('Sangkar 2'), findsOneWidget);
    expect(find.text('Sangkar 3'), findsOneWidget);
    expect(find.text('Sangkar 4'), findsOneWidget);
    expect(find.text('Kode'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(find.textContaining('Terakhir di edit pada :'), findsOneWidget);

    // 4. Edit Kode, Name, and Hashtags using explicit keys
    await tester.enterText(find.byKey(const Key('admin_edit_code_field')), 'A77');
    await tester.enterText(find.byKey(const Key('admin_edit_name_field')), 'Batman Swing Special Edition Gold');
    await tester.enterText(find.byKey(const Key('admin_edit_hashtag_field')), '#custom #kayujati #viral');
    await tester.pumpAndSettle();

    // Verify profile button on top navbar opens profile menu
    final profileBtn = find.byKey(const Key('admin_edit_profile_button'));
    expect(profileBtn, findsOneWidget);
    await tester.tap(profileBtn);
    await tester.pumpAndSettle();

    // Verify profile sheet contains admin details and options
    expect(find.text('Admin 1'), findsOneWidget);
    expect(find.text('Preview Katalog Umum'), findsOneWidget);
    expect(find.text('Beralih ke Akun Member'), findsOneWidget);
    expect(find.text('Keluar dari Akun Admin'), findsOneWidget);

    // Dismiss the bottom sheet by tapping outside
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // 5. Add a new cage variation via '+ Tambah'
    final addCageBtn = find.text('+ Tambah');
    await tester.ensureVisible(addCageBtn);
    await tester.pumpAndSettle();
    await tester.tap(addCageBtn);
    await tester.pumpAndSettle();

    expect(find.text('Tambah Bentuk Sangkar'), findsOneWidget);
    // The dialog has a TextField with default 'Sangkar 5'
    await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah'));
    await tester.pumpAndSettle();

    // Verify Sangkar 5 now appears in the cage row
    expect(find.text('Sangkar 5'), findsOneWidget);

    // 6. Tap 'Simpan' button
    final simpanBtn = find.widgetWithText(OutlinedButton, 'Simpan');
    await tester.ensureVisible(simpanBtn);
    await tester.pumpAndSettle();
    await tester.tap(simpanBtn);
    await tester.pumpAndSettle();

    // 7. Tap 'Kembali' to return to Admin Dashboard
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    // 8. Verify the updated name, code, and hashtag appear in Admin Dashboard list
    expect(find.text('A77-Batman Swing Special Edition Gold'), findsWidgets);
    expect(find.text('#custom #kayujati #viral'), findsWidgets);

    // 9. Go to Public Preview (katalog umum)
    await tester.tap(find.text('Preview Umum'));
    await tester.pumpAndSettle();

    // 10. Verify updated product appears in the public catalog
    expect(find.text('Batman Swing Special Edition Gold'), findsWidgets);

    // 11. Tap the product to open public ProductDetailPage
    await tester.tap(find.text('Batman Swing Special Edition Gold').first);
    await tester.pumpAndSettle();

    // 12. Verify Sangkar 5 added by Admin is present in the public cage selector!
    expect(find.text('Sangkar 5'), findsOneWidget);
  });

  testWidgets('Admin user detail page displays credentials, custom logos, preview catalog, and saves updates', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. Login as Admin
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk sebagai Admin (Mode Demo)'));
    await tester.pumpAndSettle();

    // 2. Locate Detail button for user 085732257048
    final detailBtn = find.byKey(const ValueKey('user_detail_085732257048'));
    expect(detailBtn, findsOneWidget);

    await tester.ensureVisible(detailBtn);
    await tester.pumpAndSettle();
    await tester.tap(detailBtn);
    await tester.pumpAndSettle();

    // 3. Verify on AdminUserDetailPage
    expect(find.text('Detail User Private'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text('Preview Katalog'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Produk Costum Pribadi'), findsOneWidget);
    expect(find.text('Logo Merak'), findsOneWidget);
    expect(find.text('Logo Nusantara'), findsOneWidget);

    // 4. Test Preview Katalog
    await tester.tap(find.byKey(const ValueKey('preview_katalog_button')));
    await tester.pumpAndSettle();

    expect(find.text('Mode Preview Katalog User'), findsOneWidget);
    expect(find.text('Logo Merak'), findsWidgets);
    expect(find.text('Logo Nusantara'), findsWidgets);

    // Go back from preview to detail page
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Detail User Private'), findsOneWidget);

    // 5. Edit Phone/Email and Password
    final phoneField = find.byKey(const ValueKey('user_detail_phone_field'));
    final passwordField = find.byKey(const ValueKey('user_detail_password_field'));

    await tester.enterText(phoneField, '085799998888');
    await tester.enterText(passwordField, 'newpass999');
    await tester.pumpAndSettle();

    // 6. Tap Simpan
    final simpanBtn = find.byKey(const ValueKey('simpan_user_button'));
    await tester.ensureVisible(simpanBtn);
    await tester.pumpAndSettle();
    await tester.tap(simpanBtn);
    await tester.pumpAndSettle();

    // 7. Tap Kembali to go back to Admin Dashboard
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();

    // 8. Verify the updated credentials appear in the User Private table
    expect(find.text('085799998888'), findsOneWidget);
    expect(find.text('newpass999'), findsOneWidget);
  });

  testWidgets('Admin incoming order detail page displays buyer phone, WhatsApp button, items, custom stage, and saves progress', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MyApp());

    // 1. Login as Admin
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk sebagai Admin (Mode Demo)'));
    await tester.pumpAndSettle();

    // 2. Open Detail of incoming order
    final detailButtons = find.text('Detail');
    expect(detailButtons, findsWidgets);
    await tester.ensureVisible(detailButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(detailButtons.first);
    await tester.pumpAndSettle();

    // 3. Verify on AdminOrderDetailPage
    expect(find.text('Detail Pesanan'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
    expect(find.text('Pemesanan: '), findsOneWidget);
    expect(find.text('Hubungi'), findsOneWidget);
    expect(find.text('A01-Batman Swing biru cantik'), findsOneWidget);
    expect(find.text('B03-Nusantara Beach biru'), findsOneWidget);
    expect(find.text('Status :   '), findsWidgets);
    expect(find.text('Tahap 1'), findsWidgets);
    expect(find.text('Tahap 2'), findsWidgets);
    expect(find.text('Tambah Tahap'), findsWidgets);
    expect(find.text('Simpan'), findsOneWidget);

    // 4. Tap WhatsApp Hubungi button (uses authentic WhatsApp logo)
    final hubungiBtn = find.byKey(const ValueKey('hubungi_whatsapp_button'));
    expect(hubungiBtn, findsOneWidget);
    expect(find.descendant(of: hubungiBtn, matching: find.byType(CustomPaint)), findsWidgets);
    await tester.tap(hubungiBtn);
    await tester.pumpAndSettle();

    // 5. Select Tahap 2 for the first item
    await tester.tap(find.text('Tahap 2').first);
    await tester.pumpAndSettle();

    // 6. Test Tambah Tahap
    await tester.tap(find.text('Tambah Tahap').first);
    await tester.pumpAndSettle();

    expect(find.text('Tambah Tahap Baru'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Quality Check');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    expect(find.text('Quality Check'), findsOneWidget);

    // 6b. Test Hapus Tahap: delete 'Quality Check' stage via its delete icon
    final deleteStageBtn = find.byKey(const ValueKey('delete_stage_Quality Check_0'));
    expect(deleteStageBtn, findsOneWidget);
    await tester.ensureVisible(deleteStageBtn);
    await tester.pumpAndSettle();
    await tester.tap(deleteStageBtn);
    await tester.pumpAndSettle();

    expect(find.text('Quality Check'), findsNothing);

    // 7. Tap Simpan button
    final simpanBtn = find.byKey(const ValueKey('simpan_order_status_button'));
    await tester.ensureVisible(simpanBtn);
    await tester.pumpAndSettle();
    await tester.tap(simpanBtn);
    await tester.pumpAndSettle();

    // 8. Tap Kembali to go back to Admin Dashboard
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
  });

  testWidgets('Admin Dashboard cage section supports adding photos, two-way sync with Admin Edit Product Page and deletion', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    CageService.instance.resetToDefault();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 1. Open login page as Guest
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    // 2. Login directly as Admin
    expect(find.text('Masuk sebagai Admin (Mode Demo)'), findsOneWidget);
    await tester.tap(find.text('Masuk sebagai Admin (Mode Demo)'));
    await tester.pumpAndSettle();

    // 3. Verify Sangkar section exists in Admin Dashboard
    expect(find.text('Sangkar'), findsWidgets);
    expect(find.text('4 Bentuk'), findsOneWidget);
    expect(find.text('Sangkar 1'), findsWidgets);
    expect(find.text('Sangkar 2'), findsWidgets);
    expect(find.text('Sangkar 3'), findsWidgets);
    expect(find.text('Sangkar 4'), findsWidgets);

    // 4. Test Tambah Sangkar from Admin Dashboard with photo feature
    final tambahSangkarBtn = find.text('Tambah Sangkar');
    expect(tambahSangkarBtn, findsOneWidget);
    await tester.ensureVisible(tambahSangkarBtn);
    await tester.pumpAndSettle();
    await tester.tap(tambahSangkarBtn);
    await tester.pumpAndSettle();

    // Dialog Tambah Bentuk Sangkar with photo preview & sample choices & upload button
    expect(find.text('Tambah Bentuk Sangkar'), findsOneWidget);
    expect(find.text('Foto / Gambar Sangkar:'), findsOneWidget);
    expect(find.text('Upload Foto dari Galeri / File'), findsOneWidget);
    expect(find.byKey(const ValueKey('upload_cage_image_btn')), findsOneWidget);
    expect(find.text('Pilihan Gambar Contoh:'), findsOneWidget);

    // Enter custom name
    final nameField = find.widgetWithText(TextField, 'Contoh: Sangkar Segi Enam');
    await tester.enterText(nameField, 'Sangkar Emas');
    await tester.pumpAndSettle();

    // Tap Simpan Sangkar
    await tester.tap(find.text('Simpan Sangkar'));
    await tester.pumpAndSettle();

    // Verify it is saved and synced
    expect(find.text('Sangkar Emas'), findsOneWidget);
    expect(find.text('5 Bentuk'), findsOneWidget);
    expect(CageService.instance.count, equals(5));

    // 5. Click a public product card to open AdminEditProductPage
    final productCard = find.text('A01-Batman Swing biru cantik');
    expect(productCard, findsWidgets);
    await tester.ensureVisible(productCard.first);
    await tester.pumpAndSettle();
    await tester.tap(productCard.first);
    await tester.pumpAndSettle();

    // Verify AdminEditProductPage opened and has 'Sangkar Emas' from Dashboard!
    expect(find.text(' / Detail Produk'), findsOneWidget);
    expect(find.text('Sangkar Emas'), findsOneWidget);

    // 6. Test adding a cage in AdminEditProductPage with photo
    final tambahCageBtn = find.text('+ Tambah');
    expect(tambahCageBtn, findsOneWidget);
    await tester.ensureVisible(tambahCageBtn);
    await tester.pumpAndSettle();
    await tester.tap(tambahCageBtn);
    await tester.pumpAndSettle();

    expect(find.text('Tambah Bentuk Sangkar'), findsOneWidget);
    expect(find.text('Foto / Gambar Sangkar:'), findsOneWidget);

    final editCageNameField = find.widgetWithText(TextField, 'Contoh: Sangkar 5');
    await tester.enterText(editCageNameField, 'Sangkar Ukir Jepara');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();

    // Verify cage was added to CageService and local list
    expect(find.text('Sangkar Ukir Jepara'), findsOneWidget);
    expect(CageService.instance.count, equals(6));

    // 7. Test deleting a cage in AdminEditProductPage
    // Remove the first cage ('Sangkar 1')
    final closeButtons = find.byIcon(Icons.close);
    expect(closeButtons, findsWidgets);
    await tester.ensureVisible(closeButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(closeButtons.first);
    await tester.pumpAndSettle();

    // Verify Sangkar 1 is deleted from CageService and page
    expect(CageService.instance.count, equals(5));
    expect(CageService.instance.cages.any((c) => c.name == 'Sangkar 1'), isFalse);

    // 8. Go back to Admin Dashboard
    final kembaliBtn = find.text('Kembali');
    await tester.ensureVisible(kembaliBtn);
    await tester.pumpAndSettle();
    await tester.tap(kembaliBtn);
    await tester.pumpAndSettle();

    // Verify Admin Dashboard displays updated cages: has 'Sangkar Ukir Jepara', does not have 'Sangkar 1'
    expect(find.text('5 Bentuk'), findsOneWidget);
    expect(find.text('Sangkar Ukir Jepara'), findsOneWidget);
    expect(find.text('Sangkar 1'), findsNothing);

    // 9. Test deleting a cage directly from Admin Dashboard via delete icon on card
    final dashboardCageDeleteBtn = find.byKey(ValueKey('delete_cage_btn_${CageService.instance.cages.first.id}'));
    expect(dashboardCageDeleteBtn, findsOneWidget);
    await tester.ensureVisible(dashboardCageDeleteBtn);
    await tester.pumpAndSettle();
    await tester.tap(dashboardCageDeleteBtn);
    await tester.pumpAndSettle();

    expect(CageService.instance.count, equals(4));
    expect(find.text('4 Bentuk'), findsOneWidget);
  });

  testWidgets('Admin completed order detail page displays buyer info, WhatsApp button, items, status, and completion date', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    AuthService.instance.logout();
    CageService.instance.resetToDefault();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Open login page as Guest
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    // Login directly as Admin
    expect(find.text('Masuk sebagai Admin (Mode Demo)'), findsOneWidget);
    await tester.tap(find.text('Masuk sebagai Admin (Mode Demo)'));
    await tester.pumpAndSettle();

    // Verify Admin Dashboard is displayed
    expect(find.text('Riwayat'), findsWidgets);

    // Scroll to Riwayat section and find Detail button for completed order 085732257048
    final detailBtn = find.byKey(const ValueKey('completed_order_detail_085732257048_1'));
    expect(detailBtn, findsOneWidget);
    await tester.ensureVisible(detailBtn);
    await tester.pumpAndSettle();
    await tester.tap(detailBtn);
    await tester.pumpAndSettle();

    // Verify AdminCompletedOrderDetailPage opened
    expect(find.text('Detail Pesanan'), findsOneWidget);
    expect(find.text('Pemesanan: 085732257048'), findsOneWidget);
    expect(find.text('Tanggal Pemesanan: 10-09-2026'), findsOneWidget);

    // Verify WhatsApp Hubungi button with WhatsApp logo
    expect(find.byKey(const ValueKey('whatsapp_hubungi_btn')), findsOneWidget);
    expect(find.text('Hubungi'), findsOneWidget);
    expect(find.byType(WhatsAppIcon), findsOneWidget);

    // Verify items from the reference image
    expect(find.text('A01-Batman Swing biru cantik'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('B03-Nusantara Beach biru'), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);

    // Verify status & completed date
    expect(find.text('Status :'), findsOneWidget);
    expect(find.text('Diterima'), findsWidgets);
    expect(find.text('Tanggal Diterima: 11-09-2026'), findsOneWidget);

    // Test Kembali button
    final kembaliBtn = find.text('Kembali');
    expect(kembaliBtn, findsOneWidget);
    await tester.tap(kembaliBtn);
    await tester.pumpAndSettle();

    // Verify back to Admin Dashboard
    expect(find.text('Riwayat'), findsWidgets);
  });

  testWidgets('Admin settings page allows changing catalog layout and destination WhatsApp number for all orders', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    AppSettingsService.instance.resetToDefault();
    AuthService.instance.logout();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Login as Admin
    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk sebagai Admin (Mode Demo)'));
    await tester.pumpAndSettle();

    // Tap Pengaturan in Sidebar
    final pengaturanMenu = find.text('Pengaturan');
    expect(pengaturanMenu, findsWidgets);
    await tester.tap(pengaturanMenu.first);
    await tester.pumpAndSettle();

    // Verify AdminSettingsPage is open
    expect(find.text('Preview Dashboard Umum'), findsOneWidget);
    expect(find.text('Banner'), findsOneWidget);
    expect(find.text('Navbar'), findsOneWidget);
    expect(find.text('Font'), findsOneWidget);
    expect(find.text('Nomor WhatsApp Tujuan Pesanan (Admin)'), findsOneWidget);

    // Verify banner, navbar style buttons (1, 2, 3), and font dropdown exist
    expect(find.byKey(const ValueKey('settings_banner_picker')), findsOneWidget);
    expect(find.byKey(const ValueKey('navbar_style_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('navbar_style_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('navbar_style_3')), findsOneWidget);

    // Select Navbar Style 2
    await tester.tap(find.byKey(const ValueKey('navbar_style_2')));
    await tester.pumpAndSettle();

    // Update WhatsApp destination number to a new number
    final waField = find.byKey(const ValueKey('admin_whatsapp_input'));
    expect(waField, findsOneWidget);
    await tester.enterText(waField, '089876543210');
    await tester.pumpAndSettle();

    // Tap Simpan Pengaturan
    final saveBtn = find.byKey(const ValueKey('save_settings_btn'));
    await tester.ensureVisible(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Verify settings updated globally in AppSettingsService
    expect(AppSettingsService.instance.adminWhatsApp, equals('089876543210'));
    expect(AppSettingsService.instance.navbarStyle, equals(2));

    // Tap Kembali to go back to Admin Dashboard
    final kembaliBtn = find.text('Kembali');
    expect(kembaliBtn, findsOneWidget);
    await tester.ensureVisible(kembaliBtn);
    await tester.pumpAndSettle();
    await tester.tap(kembaliBtn);
    await tester.pumpAndSettle();

    // Switch to user preview to test checkout destination
    expect(find.text('Preview Umum'), findsOneWidget);
    await tester.tap(find.text('Preview Umum'));
    await tester.pumpAndSettle();

    // Verify destination URI for any order targets the newly configured WhatsApp number
    final destUri = AppSettingsService.instance.createOrderWhatsAppUri(
      customerPhone: '081234567890',
      itemDescriptions: ['A01-Batman Swing biru cantik x1'],
    );
    expect(destUri.toString(), contains('6289876543210'));

    // Verify destination URI includes product name and photo link
    final photoUri = AppSettingsService.instance.createOrderWhatsAppUri(
      customerPhone: '081234567890',
      itemDescriptions: [
        'Sangkar Burung Ukir Jati Jepara Klasik [Bulat] x1\n   📸 Foto Produk: https://images.unsplash.com/photo-1548767797-d8c844163c4c?w=600\n   Catatan: finishing natural',
      ],
    );
    expect(photoUri.toString(), contains('Foto%20Produk'));
    expect(photoUri.toString(), contains('images.unsplash.com'));
  });
}



