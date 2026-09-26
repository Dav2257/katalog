import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:katalog/main.dart';
import 'package:katalog/models/product.dart';
import 'package:katalog/pages/admin_add_product_page.dart';
import 'package:katalog/pages/admin_completed_order_detail_page.dart';
import 'package:katalog/pages/admin_dashboard_page.dart';
import 'package:katalog/pages/admin_edit_product_page.dart';
import 'package:katalog/pages/admin_order_detail_page.dart';
import 'package:katalog/pages/admin_settings_page.dart';
import 'package:katalog/pages/admin_user_detail_page.dart';
import 'package:katalog/pages/cart_page.dart';
import 'package:katalog/pages/login_page.dart';
import 'package:katalog/pages/product_detail_page.dart';
import 'package:katalog/pages/user_home_page.dart';
import 'package:katalog/services/user_service.dart';
import 'package:katalog/widgets/ai_assistant_dialog.dart';

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

final sampleProduct = Product(
  id: 'prod_1',
  code: 'A01',
  name: 'Sangkar Jati Ukir Naga Emas Mewah Jepara',
  price: 2500000,
  description: 'Sangkar burung ukir jati asli dengan finishing natural dan motif naga relief 3D yang sangat detail.',
  imageUrl: 'https://example.com/sangkar.jpg',
  category: '#jati #naga #mewah #sangkar',
  cageVariations: [
    ProductCageVariation(id: 'c1', name: 'Kosan standard', imageUrl: 'https://example.com/c1.jpg'),
    ProductCageVariation(id: 'c2', name: 'Kosan Ceper', imageUrl: 'https://example.com/c2.jpg'),
    ProductCageVariation(id: 'c3', name: 'Tebok', imageUrl: 'https://example.com/c3.jpg'),
  ],
);

final sampleIncomingOrder = AdminIncomingOrder(
  no: 1,
  customerName: 'Ahmad Subagyo',
  phone: '081234567890',
  email: 'ahmad@gmail.com',
  date: '26-09-2026',
  quantity: 1,
  productCode: 'A01',
  status: 'Tahap 1',
  note: 'Tambahkan inisial AS',
  cageType: 'Kosan standard',
  orderId: 'ord_1',
);

final sampleCompletedOrder = AdminCompletedOrder(
  no: 1,
  customerName: 'Budi Santoso',
  phone: '089876543210',
  email: 'budi@gmail.com',
  date: '25-09-2026',
  quantity: 1,
  productCode: 'A01',
  status: 'Diterima',
  note: 'Finishing doff gelap.',
  cageType: 'Tebok',
  orderId: 'comp_1',
);

final sampleUser = AdminPrivateUser(
  no: 1,
  name: 'Andrias Setiawan',
  phone: '081358486868',
  email: 'setiawan.andrias@gmail.com',
  password: 'user123',
  joinDate: '22-09-2026',
  customLogoCount: 1,
  customProducts: [sampleProduct],
);

void main() {
  setUpAll(() async {
    HttpOverrides.global = _MockHttpOverrides();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };
  });

  final testSizes = [
    {'name': 'HP Kecil (360x640)', 'size': const Size(360, 640)},
    {'name': 'HP Standar (390x844)', 'size': const Size(390, 844)},
    {'name': 'HP Layar Lebar (412x915)', 'size': const Size(412, 915)},
    {'name': 'Tablet (768x1024)', 'size': const Size(768, 1024)},
    {'name': 'Laptop (1280x800)', 'size': const Size(1280, 800)},
    {'name': 'Desktop Full HD (1920x1080)', 'size': const Size(1920, 1080)},
  ];

  for (final sizeConfig in testSizes) {
    final sizeName = sizeConfig['name'] as String;
    final size = sizeConfig['size'] as Size;

    group('Pemeriksaan Overflow pada $sizeName', () {
      testWidgets('Katalog Utama (MyHomePage / Guest)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: MyHomePage(title: 'Jatimas Sangkar'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Halaman Member (UserHomePage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: UserHomePage(
                  customLogos: [sampleProduct],
                  onAddCustomLogo: (prod) {},
                  onProductTap: (prod) {},
                  onOpenStandardCatalog: () {},
                  onCartTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Detail Produk (ProductDetailPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: ProductDetailPage(product: sampleProduct),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Keranjang Belanja (CartPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: CartPage(
              cartItems: [
                CartItem(
                  product: sampleProduct,
                  quantity: 1,
                  cageType: 'Kosan standard',
                  note: 'Catatan pesanan khusus',
                ),
              ],
              onUpdateQuantity: (item, qty) {},
              onRemoveItem: (item) {},
              onClearCart: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final rf in tester.allRenderObjects.whereType<RenderFlex>()) {
          if (rf.toString().contains('OVERFLOWING')) {
            RenderObject? p = rf.parent;
            int index = 0;
            if (p is RenderFlex) {
              RenderBox? child = p.firstChild;
              while (child != null) {
                if (child == rf) break;
                index++;
                child = (child.parentData as FlexParentData).nextSibling;
              }
            }
            debugPrint('OVERFLOWING ROW IS CHILD INDEX: $index OF COLUMN, constraints: ${rf.constraints}, size: ${rf.size}');
            RenderBox? c = rf.firstChild;
            while (c != null) {
              debugPrint('  ROW CHILD: ${c.debugCreator}, size: ${c.hasSize ? c.size : "no size"}');
              c = (c.parentData as FlexParentData).nextSibling;
            }
          }
        }
        final exc = tester.takeException();
        expect(exc, isNull);
      });

      testWidgets('Login & Registrasi (LoginPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Dashboard Admin (AdminDashboardPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: AdminDashboardPage(
              onPreviewUmum: () {},
              onLogout: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Tambah Produk Admin (AdminAddProductPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: AdminAddProductPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Edit Produk Admin (AdminEditProductPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: AdminEditProductPage(product: sampleProduct),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Detail Pesanan Masuk Admin (AdminOrderDetailPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? caughtDetails;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtDetails = details;
          oldOnError?.call(details);
        };

        await tester.pumpWidget(
          MaterialApp(
            home: AdminOrderDetailPage(order: sampleIncomingOrder),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = oldOnError;

        if (caughtDetails != null) {
          debugPrint('>>> ERROR DETAILS FULL:\n${caughtDetails.toString()}');
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('Detail Pesanan Selesai Admin (AdminCompletedOrderDetailPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? caughtDetails;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtDetails = details;
          oldOnError?.call(details);
        };

        await tester.pumpWidget(
          MaterialApp(
            home: AdminCompletedOrderDetailPage(order: sampleCompletedOrder),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = oldOnError;

        if (caughtDetails != null) {
          debugPrint('>>> COMPLETED ORDER ERROR:\n${caughtDetails.toString()}');
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('Detail User Private Admin (AdminUserDetailPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: AdminUserDetailPage(user: sampleUser),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Pengaturan Toko Admin (AdminSettingsPage)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? caughtDetails;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtDetails = details;
          oldOnError?.call(details);
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: AdminSettingsPage(),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = oldOnError;

        if (caughtDetails != null) {
          debugPrint('>>> SETTINGS ERROR:\n${caughtDetails.toString()}');
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('Dialog Asisten AI (AiAssistantDialog)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? caughtDetails;
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          caughtDetails = details;
          oldOnError?.call(details);
        };

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AiAssistantDialog(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        FlutterError.onError = oldOnError;

        if (caughtDetails != null) {
          debugPrint('>>> AI ASSISTANT ERROR:\n${caughtDetails.toString()}');
        }
        expect(tester.takeException(), isNull);
      });
    });
  }
}
