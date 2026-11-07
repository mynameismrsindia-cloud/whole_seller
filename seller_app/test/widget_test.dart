import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:seller_app/models/product.dart';
import 'package:seller_app/screens/login_screen.dart';
import 'package:seller_app/screens/profile_screen.dart';
import 'package:seller_app/screens/sales_entry_screen.dart';

void main() {
  testWidgets('login page does not offer a demo workspace', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Seller sign in'), findsOneWidget);
    expect(find.text('Open demo workspace'), findsNothing);
    expect(find.text('Remember password'), findsOneWidget);
    final passwordField = find.byKey(const Key('seller-password'));
    final editablePassword = find.descendant(
      of: passwordField,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editablePassword).obscureText, isTrue);
    await tester.tap(find.byKey(const Key('seller-password-visibility')));
    await tester.pump();
    expect(tester.widget<EditableText>(editablePassword).obscureText, isFalse);
  });

  testWidgets('sales entry has a product dropdown and no search', (
    tester,
  ) async {
    await _pumpSalesEntry(tester);

    expect(find.byType(DropdownButtonFormField<Product>), findsOneWidget);
    expect(find.text('Rice — Remaining: 10'), findsOneWidget);
    expect(find.byKey(const Key('seller-product-search')), findsNothing);
  });

  testWidgets('submit button is grey until required fields are filled', (
    tester,
  ) async {
    await _pumpSalesEntry(tester);

    var button = tester.widget<FilledButton>(
      find.byKey(const Key('seller-submit')),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.disabled}),
      const Color(0xFF9E9E9E),
    );

    await tester.enterText(find.byKey(const Key('store-name')), 'Store');
    await tester.enterText(
      find.byKey(const Key('store-contact')),
      '1234567890',
    );
    await tester.enterText(find.byKey(const Key('store-location')), 'Kolkata');
    await tester.enterText(find.byKey(const Key('seller-quantity')), '2');
    await tester.pump();

    button = tester.widget<FilledButton>(
      find.byKey(const Key('seller-submit')),
    );
    expect(button.onPressed, isNotNull);
    expect(button.style?.backgroundColor?.resolve({}), const Color(0xFF2E7D32));
  });

  testWidgets('sales entry scrolls on a short phone viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSalesEntry(tester);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('seller-submit')));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const Key('seller-submit'))).bottom,
      lessThanOrEqualTo(480),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile shows only the seller name and email in one card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileScreen(name: 'Seller Name', email: 'seller@gmail.com'),
        ),
      ),
    );

    expect(find.byType(Card), findsOneWidget);
    expect(find.text('Seller Name'), findsOneWidget);
    expect(find.text('seller@gmail.com'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Save profile'), findsNothing);
  });

  testWidgets('seller can submit a sale', (tester) async {
    var submittedQuantity = 0;
    await _pumpSalesEntry(
      tester,
      onSubmitSale:
          ({
            required requestId,
            required product,
            required quantity,
            required rate,
            required store,
            required contact,
            required location,
          }) async {
            submittedQuantity = quantity;
            return [
              Product(
                id: product.id,
                name: product.name,
                quantity: product.quantity - quantity,
                rate: product.rate,
              ),
            ];
          },
    );
    await tester.enterText(find.byKey(const Key('store-name')), 'Store');
    await tester.enterText(
      find.byKey(const Key('store-contact')),
      '1234567890',
    );
    await tester.enterText(find.byKey(const Key('store-location')), 'Kolkata');
    await tester.enterText(find.byKey(const Key('seller-quantity')), '2');
    await tester.ensureVisible(find.byKey(const Key('seller-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seller-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Sale submitted.'), findsOneWidget);
    expect(find.text('Rice — Remaining: 8'), findsOneWidget);
    expect(submittedQuantity, 2);
  });
}

Product _testProduct() =>
    Product(id: 'rice', name: 'Rice', quantity: 10, rate: 73);

Future<void> _pumpSalesEntry(
  WidgetTester tester, {
  Future<List<Product>> Function({
    required String requestId,
    required Product product,
    required int quantity,
    required int rate,
    required String store,
    required String contact,
    required String location,
  })?
  onSubmitSale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SalesEntryScreen(
          name: 'Seller',
          store: '',
          contact: '',
          location: '',
          products: [_testProduct()],
          onStoreChanged: (_, _, _) {},
          onSubmitSale:
              onSubmitSale ??
              ({
                required requestId,
                required product,
                required quantity,
                required rate,
                required store,
                required contact,
                required location,
              }) async => [_testProduct()],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
