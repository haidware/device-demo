import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:device_demo/app.dart';
import 'package:device_demo/services/portal_api.dart';
import 'package:device_demo/screens/welcome_screens.dart';

void main() {
  test('greeting follows local time of day', () {
    expect(greetingForTime(DateTime(2026, 11, 2, 8)), 'Good morning');
    expect(greetingForTime(DateTime(2026, 11, 2, 14)), 'Good afternoon');
    expect(greetingForTime(DateTime(2026, 11, 2, 22)), 'Good evening');
  });

  test('QR links provide a valid numeric device ID', () {
    expect(
      scannedDeviceIdFromUri(
        Uri.parse('https://example.test/?device_id=123456'),
      ),
      '123456',
    );
    expect(
      scannedDeviceIdFromUri(
        Uri.parse('https://example.test/?device_id=wrong'),
      ),
      isNull,
    );
  });

  testWidgets('QR launch opens directly on the ordering homepage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      HaidwareApp(
        initialUri: Uri.parse('https://example.test/?device_id=123456'),
      ),
    );

    expect(find.text('${greetingForTime(DateTime.now())} 👋'), findsOneWidget);
    expect(find.text('Hotel staff sign in'), findsNothing);
    expect(
      find.text('This room QR is not connected to the ordering portal yet.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('homepage always shows kitchen, bar and services options', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeScreen(
            cartCount: 0,
            propertyName: 'Demo Hotel',
            roomLabel: 'Room 101',
            isQrGuest: true,
            isConnecting: false,
            connectionError: null,
            onRetryConnection: () async {},
            onEnterDeviceId: () {},
            onOpenKitchen: () {},
            onOpenBar: () {},
            onOpenServices: () {},
            onOpenRoom: () {},
            onOpenCart: () {},
            onOpenNotifications: () {},
            nextWhatsAppDepartment: null,
            onOpenNextWhatsApp: () {},
          ),
        ),
      ),
    );

    expect(find.text('Kitchen'), findsOneWidget);
    expect(find.text('Demo Hotel'), findsOneWidget);
    expect(find.text('Bar'), findsOneWidget);
    expect(find.text('Services'), findsOneWidget);
    expect(find.byTooltip('Room details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff order confirmation stops when portal is unavailable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HaidwareApp());
    expect(find.text('H A I D W A R E'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel staff sign in'), findsOneWidget);
    expect(find.text('Device ID Number'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Scan to view menu & place your order'), findsNothing);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Device ID number is required'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen'), findsOneWidget);

    await tester.tap(find.text('Kitchen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grilled Chicken'));
    await tester.pumpAndSettle();
    expect(find.text('Estimated order time'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    final estimateY = tester.getTopLeft(find.text('Estimated order time')).dy;
    final addToCartY = tester.getTopLeft(find.text('Add to Cart')).dy;
    expect(estimateY, lessThan(addToCartY));
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();
    expect(find.text('Your Cart'), findsOneWidget);
    expect(find.text('N6,500'), findsAtLeastNWidgets(1));
    expect(find.text('Service Charge (10%)'), findsNothing);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    expect(find.text('N13,000'), findsAtLeastNWidgets(1));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('N13,000'), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jollof Rice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Cart'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();
    expect(find.text('Pay at Reception'), findsNothing);
    expect(find.text('Name on bank transfer'), findsOneWidget);
    await tester.tap(find.text('I have paid'));
    await tester.pumpAndSettle();
    expect(find.text('Enter sender name'), findsAtLeastNWidgets(1));
    await tester.enterText(find.byType(TextFormField), 'Jane Customer');
    await tester.tap(find.text('I have paid'));
    await tester.pumpAndSettle();
    expect(find.text('Payment message preview'), findsOneWidget);
    expect(find.textContaining('#HDW-101-00045'), findsOneWidget);
    expect(find.textContaining('Device ID Number: 101'), findsOneWidget);
    expect(
      find.textContaining('Name on bank transfer: Jane Customer'),
      findsOneWidget,
    );
    expect(
      find.text('Generated message preview. This is not sent automatically.'),
      findsOneWidget,
    );
    expect(find.text('Reception Dashboard'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm Order'));
    await tester.pumpAndSettle();
    expect(find.text('Thank You!'), findsNothing);
    expect(find.text('Payment message preview'), findsOneWidget);
    expect(
      find.text(
        'The ordering portal is not connected. Your order was not submitted.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff notification link opens the authenticated staff inbox', (
    tester,
  ) async {
    final api = PortalApi(
      'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          '{"error":"Sign in to view staff notifications."}',
          401,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      HaidwareApp(
        initialUri: Uri.parse('https://example.test/ordernotification'),
        portalApi: api,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff Notifications'), findsOneWidget);
    expect(find.text('Sign in to your staff inbox'), findsOneWidget);
    expect(find.text('Staff sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirmed order opens WhatsApp and keeps other departments queued',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final openedLinks = <Uri>[];
      final api = PortalApi(
        'https://example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/device/session/')) {
            return http.Response(
              jsonEncode({
                'device_id': '123456',
                'property': {'name': 'Demo Hotel'},
                'room': '101',
                'payment_details': {
                  'bank_name': 'GTBank',
                  'account_name': 'Demo Hotel',
                  'account_number': '0123456789',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/menu/')) {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 42,
                    'name': 'Jollof Rice',
                    'description': 'Freshly prepared',
                    'category': 'Main',
                    'department': 'kitchen',
                    'price': '5000.00',
                    'preparation_minutes': 25,
                    'image_url': '',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/services/')) {
            return http.Response(
              '{"services":[]}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'order_number': 'HDW-ABC123',
              'whatsapp_messages': [
                {
                  'department': 'Kitchen',
                  'staff_name': 'Kemi',
                  'status': 'ready',
                  'detail': 'Manual send required.',
                  'whatsapp_url': 'https://wa.me/2348011112222?text=Kitchen',
                },
                {
                  'department': 'Bar',
                  'staff_name': 'Tunde',
                  'status': 'ready',
                  'detail': 'Manual send required.',
                  'whatsapp_url': 'https://wa.me/2348022223333?text=Bar',
                },
              ],
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);

      await tester.pumpWidget(
        HaidwareApp(
          initialUri: Uri.parse('https://example.test/?device_id=123456'),
          portalApi: api,
          launchWhatsApp: (url) async {
            openedLinks.add(url);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kitchen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jollof Rice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Jane Customer');
      await tester.tap(find.text('I have paid'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm Order'));
      await tester.pumpAndSettle();

      expect(openedLinks, [
        Uri.parse('https://wa.me/2348011112222?text=Kitchen'),
      ]);
      expect(find.text('Send the order message to Bar'), findsOneWidget);
      expect(find.text('Thank You!'), findsNothing);
      await tester.tap(find.text('Open WhatsApp'));
      await tester.pumpAndSettle();
      expect(openedLinks, [
        Uri.parse('https://wa.me/2348011112222?text=Kitchen'),
        Uri.parse('https://wa.me/2348022223333?text=Bar'),
      ]);
      expect(find.text('Send the order message to Bar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('staff can clear notifications after signing in', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HaidwareApp());

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
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
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bar'));
    await tester.pumpAndSettle();
    expect(find.text('Mango Mocktail'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('${greetingForTime(DateTime.now())} 👋'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Staff Login'), findsOneWidget);
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
    await tester.pumpWidget(const HaidwareApp());
    expect(find.text('H A I D W A R E'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Kitchen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
