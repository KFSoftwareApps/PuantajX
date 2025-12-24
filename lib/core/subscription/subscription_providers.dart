import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../init/providers.dart';
import '../subscription/subscription_service.dart';
import '../subscription/plan_config.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../core/services/iap_service.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import 'iap_listener.dart'; // Added import

// Subscription service provider
// Subscription service provider
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  // Isar null is handled inside service
  return SubscriptionService(isar, ref);
});

// Current organization's plan provider
final currentPlanProvider = FutureProvider<PlanConfig>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return Plans.free;
  
  final service = ref.read(subscriptionServiceProvider);
  return await service.getOrgPlan(user.currentOrgId);
});

// Current organization's usage provider
final currentUsageProvider = FutureProvider<Map<String, int>>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return {};
  
  final service = ref.read(subscriptionServiceProvider);
  return await service.getOrgUsage(user.currentOrgId);
});

// Check if user can perform action
final canPerformActionProvider = FutureProvider.family<bool, String>((ref, action) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) return false;
  
  final service = ref.read(subscriptionServiceProvider);
  return await service.canPerformAction(user.currentOrgId, action);
});

// Check if user has entitlement
final hasEntitlementProvider = FutureProvider.family<bool, Entitlement>((ref, entitlement) async {
  final plan = await ref.watch(currentPlanProvider.future);
  return plan.hasEntitlement(entitlement);
});

// IAP Service Provider
final iapServiceProvider = Provider<IAPService>((ref) {
  return IAPService();
});

// Products Provider
final productsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  final service = ref.watch(iapServiceProvider);
  await service.init();
  return service.products.cast<ProductDetails>();
});

// IAP Listener Provider
final iapListenerProvider = Provider<IAPListener>((ref) {
  final iapService = ref.watch(iapServiceProvider);
  final subService = ref.watch(subscriptionServiceProvider);
  return IAPListener(ref, iapService, subService);
});
