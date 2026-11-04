import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:owner_desktop/main.dart';
import 'package:owner_desktop/screens/add_product_screen.dart';
import 'package:owner_desktop/screens/profile_screen.dart';

void main() {
  testWidgets('owner can open products and sales areas', (tester) async {
    tester.view.physicalSize = const Size(1280, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OwnerApp());
    await tester.tap(find.text('Open demo workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Products'), findsWidgets);
    expect(find.text('Basmati Rice'), findsOneWidget);
    expect(find.text('Add Product'), findsOneWidget);
    expect(find.text('Rate'), findsNothing);

    await tester.tap(find.text('Add Product'));
    await tester.pumpAndSettle();
    expect(find.text('Product ID'), findsOneWidget);
    expect(find.text('Rate'), findsNothing);

    await tester.tap(find.text('Save Product'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(2));
    expect(find.text('Enter a whole number'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('owner-product-id')), 'P004');
    await tester.enterText(
      find.byKey(const Key('owner-product-name')),
      'Sugar',
    );
    await tester.enterText(
      find.byKey(const Key('owner-product-quantity')),
      '25',
    );
    await tester.tap(find.text('Save Product'));
    await tester.pumpAndSettle();
    expect(find.text('Sugar'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit product').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-product-name')), '   ');
    await tester.tap(find.byKey(const Key('edit-product-save')));
    await tester.pumpAndSettle();
    expect(find.text('Product name is required'), findsOneWidget);
    expect(find.text('Sugar'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('edit-product-name')),
      'Sugar Premium',
    );
    await tester.tap(find.byKey(const Key('edit-product-save')));
    await tester.pumpAndSettle();
    expect(find.text('Sugar Premium'), findsOneWidget);
    expect(find.text('Sugar'), findsNothing);
  });

  testWidgets('owner profile does not show hardcoded support contact', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            name: 'Store Owner',
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

  testWidgets('add product form scrolls on a short desktop window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AddProductScreen()));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Save Product'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Save Product')).bottom,
      lessThanOrEqualTo(420),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner app supports Android-sized screen and navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OwnerApp());
    await tester.tap(find.text('Open demo workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Owner workspace is designed for desktop.'), findsNothing);
    expect(find.text('Basmati Rice'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Sales').last);
    await tester.pumpAndSettle();
    expect(find.text('Sales Entries'), findsWidgets);
    expect(find.text('Rahul'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Rahul')).dy,
      lessThan(tester.getTopLeft(find.text('Amit')).dy),
    );
    expect(find.text('Pending'), findsNWidgets(2));
    final approveButton = find.byKey(
      const ValueKey('approve-order-demo-rahul'),
    );
    await tester.ensureVisible(approveButton);
    await tester.pumpAndSettle();
    await tester.tap(approveButton);
    await tester.pumpAndSettle();
    expect(find.text('Approved'), findsNWidgets(2));
    expect(find.text('Pending'), findsOneWidget);
    expect(approveButton, findsOneWidget);
    expect(tester.widget<FilledButton>(approveButton).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

void _noopSave(String name, String store, String contact, String location) {}
