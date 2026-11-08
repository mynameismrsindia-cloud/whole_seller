import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owner_desktop/main.dart';
import 'package:owner_desktop/models/app_user.dart';
import 'package:owner_desktop/models/product.dart';
import 'package:owner_desktop/screens/add_product_screen.dart';
import 'package:owner_desktop/screens/login_screen.dart';
import 'package:owner_desktop/screens/sales_list_screen.dart';
import 'package:owner_desktop/services/providers.dart';
import 'package:owner_desktop/services/wholesale_api_client.dart';

void main() {
  testWidgets('owner login has no demo bypass and exposes password options', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pump();

    expect(find.text('Open demo workspace'), findsNothing);
    expect(find.text('Remember password'), findsOneWidget);
    final passwordField = find.byKey(const Key('owner-password'));
    final editablePassword = find.descendant(
      of: passwordField,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editablePassword).obscureText, isTrue);
    await tester.tap(find.byKey(const Key('owner-password-visibility')));
    await tester.pump();
    expect(tester.widget<EditableText>(editablePassword).obscureText, isFalse);

    await tester.ensureVisible(find.text('New Owner? Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Owner? Create an account'));
    await tester.pump();
    expect(find.byKey(const Key('owner-register-name')), findsOneWidget);
    expect(find.text('Remember password'), findsNothing);
  });

  testWidgets('Owner registration fits a small mobile screen and shows logo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('New Owner? Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Owner? Create an account'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('owner-register-name')), findsOneWidget);
    await tester.ensureVisible(find.text('Create owner account'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop workspace shows account details and scrolls both ways', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authRepository = _TestAuthRepository();
    final apiRepository = _TestApiRepository();
    addTearDown(authRepository.api.close);
    addTearDown(apiRepository.api.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          apiRepositoryProvider.overrideWithValue(apiRepository),
        ],
        child: const OwnerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Owner Name'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    expect(find.byType(Scrollbar), findsNWidgets(2));
    expect(find.text('Rice'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Owner Name'), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('owner workspace adapts to mobile navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authRepository = _TestAuthRepository();
    final apiRepository = _TestApiRepository();
    addTearDown(authRepository.api.close);
    addTearDown(apiRepository.api.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          apiRepositoryProvider.overrideWithValue(apiRepository),
        ],
        child: const OwnerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Products'), findsWidgets);
    expect(find.text('Sales'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add product form scrolls on a short desktop window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AddProductScreen()));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('owner-product-id')), findsNothing);
    await tester.ensureVisible(find.text('Save Product'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Save Product')).bottom,
      lessThanOrEqualTo(420),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales list shows Indian time and status without user ID', (
    tester,
  ) async {
    final sale = Sale(
      id: 'sale-1',
      salesman: 'Seller Name',
      userId: 'private-user-id',
      store: 'Store',
      contact: '1234567890',
      location: 'Kolkata',
      productId: 'rice',
      productName: 'Rice',
      quantity: 2,
      rate: 50,
      createdAt: DateTime.utc(2026, 1, 1, 21),
    );
    OrderStatus? changedStatus;
    var invoiceRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SalesListScreen(
              sales: [sale],
              initialRange: DateTimeRange(
                start: DateTime(2026, 1, 2),
                end: DateTime(2026, 1, 2),
              ),
              onStatusChanged: (sale, status) {
                setState(() => sale.orderStatus = status);
                changedStatus = status;
              },
              onDownloadInvoice: (_) async {
                invoiceRequested = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('02 Jan 2026\n2:30 AM'), findsOneWidget);
    expect(find.text('User ID'), findsNothing);
    expect(find.text('private-user-id'), findsNothing);
    expect(find.text('Pending'), findsOneWidget);
    final approveButton = find.byKey(const ValueKey('approve-order-sale-1'));
    expect(tester.getRect(approveButton).right, lessThanOrEqualTo(800));
    expect(find.byTooltip('Download invoice PDF'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('download-invoice-sale-1')));
    await tester.pump();
    expect(invoiceRequested, isTrue);
    await tester.tap(find.byKey(const ValueKey('approve-order-sale-1')));
    await tester.pump();
    expect(changedStatus, OrderStatus.approved);
    expect(find.text('Pending'), findsNothing);
    expect(find.text('Approved'), findsNWidgets(2));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('approve-order-sale-1')),
          )
          .onPressed,
      isNull,
    );
  });
}

class _TestAuthRepository extends AuthRepository {
  _TestAuthRepository() : super(WholesaleApiClient());

  @override
  Future<AppUser?> restore({required String expectedRole}) async =>
      const AppUser(
        id: 'owner-1',
        email: 'owner@example.com',
        name: 'Owner Name',
        role: 'owner',
      );

  @override
  Future<void> signOut() async {}
}

class _TestApiRepository extends ApiRepository {
  _TestApiRepository() : super(WholesaleApiClient());

  @override
  Future<ProductPage> products({
    String query = '',
    String? cursor,
    bool forceRefresh = false,
  }) async =>
      ProductPage([Product(id: 'rice', name: 'Rice', quantity: 10)], null);

  @override
  Future<SalePage> sales({
    DateTime? start,
    DateTime? end,
    String? cursor,
  }) async => const SalePage([], null);
}
