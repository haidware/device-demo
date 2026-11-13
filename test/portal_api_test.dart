import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:device_demo/models/order.dart';
import 'package:device_demo/services/portal_api.dart';

void main() {
  test('web portal API uses the scanned QR code origin', () {
    expect(
      portalApiBaseUrl(
        isWeb: true,
        currentUri: Uri.parse(
          'https://device-demo-production.up.railway.app/?device_id=123456',
        ),
        configuredBaseUrl: 'https://device-demo.onrender.com',
      ),
      'https://device-demo-production.up.railway.app',
    );
  });

  test('native portal API uses its configured origin', () {
    expect(
      portalApiBaseUrl(
        isWeb: false,
        currentUri: Uri.parse(
          'https://device-demo-production.up.railway.app/?device_id=123456',
        ),
        configuredBaseUrl: 'https://device-demo.onrender.com',
      ),
      'https://device-demo.onrender.com',
    );
  });

  test('staff inbox uses the manager-created Django login', () async {
    final api = PortalApi(
      'https://hotel.example.test',
      client: MockClient(
        (_) async => http.Response(
          '{"error":"Sign in to view staff notifications."}',
          401,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(api.close);

    expect(
      api.staffLoginUri.toString(),
      'https://hotel.example.test/admin/login/?next=%2Fordernotification',
    );
    expect(await api.loadStaffSession(), isNull);
  });

  test('loads assigned staff messages and registers browser push', () async {
    final requests = <http.Request>[];
    final api = PortalApi(
      'https://hotel.example.test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/staff/session/')) {
          return http.Response(
            jsonEncode({
              'username': 'kemi',
              'name': 'Kemi Ade',
              'department': 'Kitchen',
              'push_enabled': true,
              'push_public_key': 'public-key',
              'csrf_token': 'csrf-value',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/staff/notifications/')) {
          return http.Response(
            jsonEncode({
              'notifications': [
                {
                  'id': 42,
                  'type': 'order',
                  'department': 'Kitchen',
                  'title': 'New Kitchen order',
                  'order_number': 'HDW-ABC123',
                  'room': '101',
                  'sender_name': 'Jane Customer',
                  'total': '6500.00',
                  'status': 'Pending',
                  'payment_status': 'Pending',
                  'items': [
                    {'name': 'Jollof Rice', 'quantity': 1},
                  ],
                  'details': '',
                  'created_at': '2026-11-13T14:01:00+00:00',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"status":"enabled"}', 200);
      }),
    );
    addTearDown(api.close);

    final session = await api.loadStaffSession();
    expect(session?.username, 'kemi');
    expect(session?.pushEnabled, isTrue);
    expect(session?.pushPublicKey, 'public-key');

    final notifications = await api.loadStaffNotifications();
    expect(notifications.single.orderNumber, 'HDW-ABC123');
    expect(notifications.single.items.single.name, 'Jollof Rice');
    expect(notifications.single.room, '101');

    await api.saveStaffPushSubscription(
      csrfToken: session!.csrfToken,
      subscription: {
        'endpoint': 'https://fcm.googleapis.com/push/token',
        'keys': {'p256dh': 'public', 'auth': 'auth'},
      },
    );
    expect(requests.last.headers['X-CSRFToken'], 'csrf-value');
    expect(
      jsonDecode(requests.last.body)['subscription']['endpoint'],
      'https://fcm.googleapis.com/push/token',
    );
  });

  test(
    'validates device, loads portal menu and submits paid order details',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/device/session/')) {
          return http.Response(
            jsonEncode({
              'device_id': '123456',
              'device_name': 'Room tablet',
              'room': '101',
              'property': {'name': 'Demo Hotel', 'location': 'Lagos'},
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
                  'category': 'Main Course',
                  'department': 'kitchen',
                  'price': '5000.00',
                  'preparation_minutes': 25,
                  'image_url':
                      'https://admin.example.test/api/v1/menu/42/image/',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/services/')) {
          return http.Response(
            jsonEncode({
              'services': [
                {
                  'id': 7,
                  'name': 'Fresh Towels',
                  'department': 'housekeeping',
                  'description': 'Fresh towels delivered to your room.',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/service-requests/')) {
          return http.Response(
            jsonEncode({'request_id': 'service-request-123', 'status': 'new'}),
            201,
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
                'status': 'demo',
                'detail': 'Manual send required.',
                'whatsapp_url':
                    'https://wa.me/2348011112222?text=Payment%20details',
              },
            ],
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = PortalApi('https://admin.example.test/', client: client);
      addTearDown(api.close);

      final session = await api.signIn('123456');
      expect(session.propertyName, 'Demo Hotel');
      expect(session.room, '101');
      expect(session.bankName, 'GTBank');
      expect(session.accountNumber, '0123456789');
      expect(session.menuItems.single.id, '42');
      expect(session.menuItems.single.price, 5000);
      expect(session.menuItems.single.department, 'kitchen');
      expect(
        session.menuItems.single.imageUrl,
        'https://admin.example.test/api/v1/menu/42/image/',
      );
      expect(session.menuItems.single.preparationTimeLabel, '25 min');
      expect(requests[1].headers['X-Device-ID'], '123456');
      expect(session.services.single.name, 'Fresh Towels');
      expect(session.services.single.department, 'housekeeping');
      expect(requests[2].headers['X-Device-ID'], '123456');

      final serviceRequestId = await api.requestService(
        deviceId: '123456',
        service: session.services.single,
      );
      expect(serviceRequestId, 'service-request-123');
      expect(jsonDecode(requests[3].body), {
        'device_id': '123456',
        'service_id': 7,
      });

      final submission = await api.submitOrder(
        deviceId: '123456',
        senderName: 'Jane Customer',
        lines: [CartLine(item: session.menuItems.single, quantity: 2)],
        expectedTotal: 10000,
      );
      expect(submission.orderNumber, 'HDW-ABC123');
      expect(submission.whatsappMessages.single.department, 'Kitchen');
      expect(submission.whatsappMessages.single.staffName, 'Kemi');
      expect(
        submission.whatsappMessages.single.url,
        'https://wa.me/2348011112222?text=Payment%20details',
      );
      final orderBody = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(orderBody['sender_name'], 'Jane Customer');
      expect(orderBody['expected_total'], 10000);
      expect(orderBody['items'], [
        {'item_id': 42, 'quantity': 2},
      ]);
    },
  );
}
