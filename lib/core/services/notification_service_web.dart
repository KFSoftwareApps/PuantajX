import 'package:flutter/foundation.dart';

class NotificationService {
  Future<void> init() async {
    debugPrint('NotificationService: Not supported on Web');
  }

  Future<void> requestPermissions() async {}
  Future<void> scheduleReportReminder({int hour = 18, int minute = 0}) async {}
  Future<void> cancelReportReminder() async {}
  Future<void> showSyncError(String error) async {
    debugPrint('Sync Error (Web Notification): $error');
  }
}
