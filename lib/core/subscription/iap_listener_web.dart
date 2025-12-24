import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/iap_service.dart';
import 'subscription_service.dart';

class IAPListener {
  IAPListener(Ref ref, IAPService iapService, SubscriptionService subscriptionService);

  void startListening() {
    // No-op on Web
  }
  
  void stopListening() {}

  Future<void> syncSubscriptionStatus() async {
    // No-op on Web
  }
}
