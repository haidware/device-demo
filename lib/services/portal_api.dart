import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/order.dart';

class PortalApiException implements Exception {
  const PortalApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PortalDeviceSession {
  const PortalDeviceSession({
    required this.room,
    required this.menuItems,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
  });

  final String? room;
  final List<MenuItem> menuItems;
  final String bankName;
  final String accountName;
  final String accountNumber;
}

class PortalApi {
  PortalApi(String baseUrl, {http.Client? client})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  static const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  final String _baseUrl;
  final http.Client _client;
  bool get isConfigured => _baseUrl.isNotEmpty;

  void close() => _client.close();

  Future<PortalDeviceSession> signIn(String deviceId) async {
    final sessionResponse = await _send(
      _client.post(
        _uri('/api/v1/device/session/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': deviceId}),
      ),
    );
    final sessionData = _decodeObject(sessionResponse);
    final paymentDetails = sessionData['payment_details'];
    if (paymentDetails is! Map<String, dynamic>) {
      throw const PortalApiException(
        'The portal returned invalid payment details.',
      );
    }
    final menuResponse = await _send(
      _client.get(_uri('/api/v1/menu/'), headers: {'X-Device-ID': deviceId}),
    );
    final menuData = _decodeObject(menuResponse);
    final rawItems = menuData['items'];
    if (rawItems is! List) {
      throw const PortalApiException('The portal returned an invalid menu.');
    }
    final items = rawItems.map(_menuItemFromJson).toList();
    return PortalDeviceSession(
      room: sessionData['room'] as String?,
      menuItems: items,
      bankName: paymentDetails['bank_name'] as String? ?? '',
      accountName: paymentDetails['account_name'] as String? ?? '',
      accountNumber: paymentDetails['account_number'] as String? ?? '',
    );
  }

  Future<String> submitOrder({
    required String deviceId,
    required String senderName,
    required List<CartLine> lines,
    required int expectedTotal,
  }) async {
    final response = await _send(
      _client.post(
        _uri('/api/v1/orders/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'sender_name': senderName,
          'expected_total': expectedTotal,
          'items': [
            for (final line in lines)
              {'item_id': int.parse(line.item.id), 'quantity': line.quantity},
          ],
        }),
      ),
    );
    final data = _decodeObject(response);
    final orderNumber = data['order_number'];
    if (orderNumber is! String || orderNumber.isEmpty) {
      throw const PortalApiException(
        'The portal did not return an order number.',
      );
    }
    return orderNumber;
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      final response = await request.timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final data = _tryDecodeObject(response.body);
        final message = data?['error'];
        throw PortalApiException(
          message is String
              ? message
              : 'Portal request failed (${response.statusCode}).',
        );
      }
      return response;
    } on TimeoutException {
      throw const PortalApiException(
        'The portal did not respond in time. Try again.',
      );
    } on http.ClientException {
      throw const PortalApiException('Could not connect to the hotel portal.');
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      throw const PortalApiException(
        'The portal returned an invalid response.',
      );
    }
    throw const PortalApiException('The portal returned an invalid response.');
  }

  Map<String, dynamic>? _tryDecodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  MenuItem _menuItemFromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const PortalApiException(
        'The portal returned an invalid menu item.',
      );
    }
    final id = value['id'];
    final name = value['name'];
    final price = value['price'];
    final preparationMinutes = value['preparation_minutes'];
    if (id is! int ||
        name is! String ||
        price is! String ||
        preparationMinutes is! int) {
      throw const PortalApiException(
        'The portal returned an invalid menu item.',
      );
    }
    final priceValue = double.tryParse(price);
    if (priceValue == null || priceValue < 0) {
      throw const PortalApiException(
        'The portal returned an invalid menu price.',
      );
    }
    final department = value['department'];
    if (department is! String ||
        (department != 'kitchen' && department != 'bar')) {
      throw const PortalApiException(
        'The portal returned an invalid menu department.',
      );
    }
    return MenuItem(
      id: id.toString(),
      name: name,
      description: value['description'] as String? ?? '',
      category: value['category'] as String? ?? 'Other',
      price: priceValue.round(),
      department: department,
      preparationMinutes: preparationMinutes,
    );
  }
}
