import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_mobile.dart'
    if (dart.library.html) 'notification_service_web.dart';

import 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_mobile.dart'
    if (dart.library.html) 'notification_service_web.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
