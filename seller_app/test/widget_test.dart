import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seller_app/main.dart';
import 'package:seller_app/models/product.dart';
import 'package:seller_app/screens/profile_screen.dart';
import 'package:seller_app/services/demo_store.dart';

void main() {
  testWidgets('sales entry scrolls on a short phone viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SellerApp());
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('seller-submit')));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const Key('seller-submit'))).bottom,
      lessThanOrEqualTo(480),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Google-style button opens the seller demo', (tester) async {
    await tester.pumpWidget(const SellerApp());

    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('New Sales Entry'), findsOneWidget);
  });

  testWidgets('profile does not show hardcoded support contact', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            name: 'Rahul',
            store: 'Bandel Traders',
            contact: '98765 43210',
            location: 'Bandel, West Bengal',
            onSave: _noopSave,
          ),
        ),
      ),
    );

    expect(find.text('Any issue? Connect with Pratap Mity'), findsNothing);
    expect(find.text('pratapmity@gmail.com'), findsNothing);
  });

  testWidgets('seller can submit a demo sale', (tester) async {
    await tester.pumpWidget(const SellerApp());
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('New Sales Entry'), findsOneWidget);
    expect(find.text('Basmati Rice — Remaining: 98'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('seller-quantity')), '2');
    await tester.enterText(find.byKey(const Key('seller-rate')), '73');
    await tester.ensureVisible(find.byKey(const Key('seller-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seller-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Entry saved in this demo.'), findsOneWidget);
    expect(find.text('Basmati Rice — Remaining: 96'), findsOneWidget);
    expect(DemoStore.sales.first.rate, 73);
    expect(DemoStore.sales.first.orderStatus, OrderStatus.pending);
  });

  testWidgets('empty required fields and empty rate are rejected', (
    tester,
  ) async {
    await tester.pumpWidget(const SellerApp());
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('store-name')), '');
    await tester.enterText(find.byKey(const Key('seller-quantity')), '1');
    await tester.enterText(find.byKey(const Key('seller-rate')), '');
    await tester.ensureVisible(find.byKey(const Key('seller-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seller-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    expect(find.text('Enter a valid rate'), findsOneWidget);
    expect(find.text('Entry saved in this demo.'), findsNothing);
  });
}

void _noopSave(String name, String store, String contact, String location) {}
