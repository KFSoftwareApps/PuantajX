import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/iap_service.dart';
import 'subscription_service.dart';

class IAPListener {
  IAPListener(Ref ref, IAPService iapService, SubscriptionService subscriptionService);
  void startListening() => throw UnimplementedError();
  void stopListening() => throw UnimplementedError();
  Future<void> syncSubscriptionStatus() => throw UnimplementedError();
}
