import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:device_demo/app.dart';

void main() {
  testWidgets('guest can place and inspect an order', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HaidwareApp());
    expect(find.text('Interactive screen overview'), findsOneWidget);

    await tester.tap(find.text('Start walkthrough'));
    await tester.pumpAndSettle();
    expect(find.text('H A I D W A R E'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Scan to view menu & place your order'), findsNothing);
    await tester.tap(find.text('Browse Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Room / table number is required'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.text('Browse Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen'), findsOneWidget);

    await tester.tap(find.text('Kitchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grilled Chicken'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your Cart'), findsOneWidget);
    expect(find.text('N6,500'), findsAtLeastNWidgets(1));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('N13,000'), findsAtLeastNWidgets(1));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('N13,000'), findsNothing);

    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay at Reception'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I have paid'));
    await tester.pumpAndSettle();
    expect(find.text('#HDW-101-00045'), findsOneWidget);

    await tester.tap(find.text('Track Order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Grilled Chicken x 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications can be cleared from the screen overview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HaidwareApp());

    await tester.tap(find.text('12. NOTIFICATION'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    expect(find.text('You are all caught up.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home categories open their matching menus', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HaidwareApp());
    await tester.tap(find.text('4. HOME - CATEGORY'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bar'));
    await tester.pumpAndSettle();
    expect(find.text('Mango Mocktail'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Good afternoon 👋'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Room / Table Info'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('welcome flow fits the target 800 by 480 display', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HaidwareApp());
    await tester.tap(find.text('Start walkthrough'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.text('Browse Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
