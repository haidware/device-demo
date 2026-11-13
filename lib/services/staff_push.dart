import 'staff_push_stub.dart'
    if (dart.library.js_interop) 'staff_push_web.dart'
    as implementation;

Future<Map<String, Object?>> createStaffPushSubscription(String publicKey) =>
    implementation.createStaffPushSubscription(publicKey);
