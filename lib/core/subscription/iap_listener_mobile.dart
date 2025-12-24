import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../services/iap_service.dart';
import 'plan_config.dart';
import 'subscription_service.dart';
import 'subscription_providers.dart';

class IAPListener {
  final Ref _ref;
  final IAPService _iapService;
  final SubscriptionService _subscriptionService;
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  IAPListener(this._ref, this._iapService, this._subscriptionService);

  void startListening() {
    _subscription = _iapService.purchaseStream.listen(
      _onPurchaseDetailsChanged,
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        debugPrint('IAP Stream Error: $error');
      },
    );
  }
  
  void stopListening() {
    _subscription?.cancel();
  }

  Future<void> _onPurchaseDetailsChanged(List<PurchaseDetails> purchaseDetailsList) async {
    final user = _ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    
    final hasActiveTransactions = purchaseDetailsList.any((p) => 
        p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored
    );

    if (purchaseDetailsList.isNotEmpty && !hasActiveTransactions) {
      debugPrint('IAP Listener: Ignored event with status(es): ${purchaseDetailsList.map((e) => e.status).toList()}');
      return; 
    }

    final plan = _iapService.checkEntitlement(purchaseDetailsList);
    
    await _subscriptionService.setOrgPlan(user.currentOrgId, plan);
    
    _ref.invalidate(currentPlanProvider);
    
    // Note: pendingCompletePurchase is handled in IAPService
    
    debugPrint('IAP Listener: Synced plan to $plan');
  }

  Future<void> syncSubscriptionStatus() async {
    debugPrint('IAP Listener: Syncing status...');
    try {
      await _iapService.restorePurchases();
    } catch (e) {
      debugPrint('IAP Listener: Sync failed: $e');
    }
  }
}
