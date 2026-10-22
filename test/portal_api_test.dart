import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:device_demo/models/order.dart';
import 'package:device_demo/services/portal_api.dart';

void main() {
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
          jsonEncode({'order_number': 'HDW-ABC123'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = PortalApi('https://admin.example.test/', client: client);
      addTearDown(api.close);

      final session = await api.signIn('123456');
      expect(session.room, '101');
      expect(session.bankName, 'GTBank');
      expect(session.accountNumber, '0123456789');
      expect(session.menuItems.single.id, '42');
      expect(session.menuItems.single.price, 5000);
      expect(session.menuItems.single.department, 'kitchen');
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

      final orderNumber = await api.submitOrder(
        deviceId: '123456',
        senderName: 'Jane Customer',
        lines: [CartLine(item: session.menuItems.single, quantity: 2)],
        expectedTotal: 11000,
      );
      expect(orderNumber, 'HDW-ABC123');
      final orderBody = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(orderBody['sender_name'], 'Jane Customer');
      expect(orderBody['expected_total'], 11000);
      expect(orderBody['items'], [
        {'item_id': 42, 'quantity': 2},
      ]);
    },
  );
}
