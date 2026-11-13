import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Map<String, Object?>> createStaffPushSubscription(
  String publicKey,
) async {
  final permission = await web.Notification.requestPermission().toDart;
  if (permission.toDart != 'granted') {
    throw StateError('Allow notifications in your browser to enable push.');
  }

  final registration = await web.window.navigator.serviceWorker
      .register(
        '/static/portal/push-service-worker.js'.toJS,
        web.RegistrationOptions(scope: '/static/portal/'),
      )
      .toDart;
  var subscription = await registration.pushManager.getSubscription().toDart;
  subscription ??= await registration.pushManager
      .subscribe(
        web.PushSubscriptionOptionsInit(
          userVisibleOnly: true,
          applicationServerKey: Uint8List.fromList(
            base64Url.decode(base64Url.normalize(publicKey)),
          ).toJS,
        ),
      )
      .toDart;

  final value = subscription.toJSON().dartify();
  if (value is! Map) {
    throw StateError('The browser returned an invalid push subscription.');
  }
  return value.map((key, value) => MapEntry(key.toString(), value as Object?));
}
