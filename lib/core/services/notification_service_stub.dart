// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class NotificationService {
  Future<void> init() async {}
  Future<void> requestPermissions() async {}
  
  Future<void> scheduleReportReminder({int hour = 18, int minute = 0}) async {
      // Web: Check if Notification API is available and permission granted
      // For now, just log or no-op as background workers are not setup.
  }
  
  Future<void> cancelReportReminder() async {}
  
  Future<void> showSyncError(String error) async {
     // Web: Show alert or console
     // js.context.callMethod('alert', ['Senkronizasyon Hatası: $error']);
     print('Sync Error: $error');
  }
}
