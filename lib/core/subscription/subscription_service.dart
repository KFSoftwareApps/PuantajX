import 'package:flutter/foundation.dart'; // Added
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../init/providers.dart';
import 'subscription_model.dart';
import 'plan_config.dart';
import 'subscription_providers.dart'; // Added for listener provider

import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/data/models/organization_model.dart'; // Added
import '../../features/project/data/models/worker_model.dart';
import '../../features/project/data/models/project_model.dart';
import '../../features/report/data/models/daily_report_model.dart';

// Services
import '../../features/auth/data/repositories/auth_repository.dart'; // Added
import '../../core/init/supabase_service.dart'; // Added



class SubscriptionService {
  final Isar? _isar;
  final Ref _ref;

  SubscriptionService(this._isar, this._ref);

  Future<Subscription?> getOrgSubscription(String orgId) async {
    if (_isar == null) return null;
    return await _isar!.subscriptions.filter().orgIdEqualTo(orgId).findFirst();
  }

  Future<PlanConfig> getOrgPlan(String orgId) async {
    final subscription = await getOrgSubscription(orgId);

    if (subscription == null || subscription.status != SubscriptionStatus.active) {
      return Plans.free;
    }

    if (subscription.expiresAt != null && subscription.expiresAt!.isBefore(DateTime.now())) {
      if (subscription.gracePeriodEndsAt != null &&
          subscription.gracePeriodEndsAt!.isAfter(DateTime.now())) {
        return Plans.getConfig(subscription.plan);
      }
      return Plans.free;
    }

    return Plans.getConfig(subscription.plan);
  }

  Future<bool> hasEntitlement(String orgId, Entitlement entitlement) async {
    final plan = await getOrgPlan(orgId);
    return plan.hasEntitlement(entitlement);
  }

  Future<Map<String, int>> getOrgUsage(String orgId) async {
    if (_isar == null) return {'projects': 0, 'seats': 0, 'workers': 0, 'photos': 0};

    final projects = await _isar!.projects.filter().orgIdEqualTo(orgId).findAll();
    final projectCount = projects.length;

    final userCount =
        await _isar!.users.filter().currentOrgIdEqualTo(orgId).count();

    final workerCount =
        await _isar!.workers.filter().orgIdEqualTo(orgId).count();

    // DailyReport tarafında query helperlar yoksa patlamasın diye
    // "hepsini çek -> projectId listesine göre dart'ta filtrele" (MVP, idare eder)
    int photoCount = 0;
    final projectIds = projects.map((p) => p.id).toSet();

    final allReports = await _isar!.dailyReports.where().findAll();
    final reports = allReports.where((r) => projectIds.contains(r.projectId)).toList();

    photoCount = reports.fold<int>(0, (sum, r) => sum + r.attachments.length);

    return {
      'projects': projectCount,
      'seats': userCount,
      'workers': workerCount,
      'photos': photoCount,
    };
  }

  Future<bool> canPerformAction(String orgId, String action, {int? currentCount}) async {
    final plan = await getOrgPlan(orgId);

    Future<int> usageOf(String key) async {
      if (currentCount != null) return currentCount;
      final usage = await getOrgUsage(orgId);
      return usage[key] ?? 0;
    }

    switch (action) {
      case 'create_project':
        if (plan.projectLimit == 0) return true;
        return (await usageOf('projects')) < plan.projectLimit;

      case 'invite_user':
        if (plan.seatLimit == 0) return true;
        return (await usageOf('seats')) < plan.seatLimit;

      case 'add_worker':
        if (plan.workerLimit == 0) return true;
        return (await usageOf('workers')) < plan.workerLimit;

      case 'add_photo':
        if (plan.photoLimit == 0) return true;
        return (await usageOf('photos')) < plan.photoLimit;

      case 'export_excel':
        return plan.hasEntitlement(Entitlement.excelExport);

      case 'approve_timesheet':
        return plan.hasEntitlement(Entitlement.approvalFlow);

      case 'lock_period':
        return plan.hasEntitlement(Entitlement.periodLock);

      case 'view_audit_log':
        return plan.hasEntitlement(Entitlement.auditLog);

      case 'manage_wages':
        return plan.hasEntitlement(Entitlement.wageRates);

      case 'view_payment_summary':
        return plan.hasEntitlement(Entitlement.paymentSummary);

      case 'manage_policies':
        return plan.hasEntitlement(Entitlement.ownerPolicyPanel);

      case 'manage_role_templates':
        return plan.hasEntitlement(Entitlement.roleTemplates);

      case 'manage_user_overrides':
        return plan.hasEntitlement(Entitlement.userOverrides);

      case 'create_guest_share':
        return plan.hasEntitlement(Entitlement.guestSharing);

      default:
        return true;
    }
  }

  Future<void> updateSubscription(Subscription subscription) async {
    if (_isar == null) return;
    await _isar!.writeTxn(() async {
      await _isar!.subscriptions.put(subscription);
    });
  }

  Future<void> initializeFreePlan(String orgId) async {
    final existing = await getOrgSubscription(orgId);
    if (existing != null) return;

    final subscription = Subscription()
      ..orgId = orgId
      ..plan = SubscriptionPlan.free
      ..store = 'manual'
      ..status = SubscriptionStatus.active
      ..createdAt = DateTime.now();

    await updateSubscription(subscription);
  }

  /// DEBUG ONLY: Manually set the plan for an organization
  Future<void> setOrgPlan(String orgId, SubscriptionPlan newPlan) async {
    // Ensure subscription exists
    await initializeFreePlan(orgId);
    
    final subscription = await getOrgSubscription(orgId);
    if (subscription != null) {
      subscription.plan = newPlan;
      // Reset any expiration if setting manual plan
      subscription.expiresAt = null; 
      subscription.status = SubscriptionStatus.active;
      
      await updateSubscription(subscription);
    }
  }

  // --- Merged Logic from Duplicate Service ---

  Future<void> checkAndSyncSubscription() async {
    // Force a sync via IAPListener (which calls restorePurchases)
    final listener = _ref.read(iapListenerProvider);
    await listener.syncSubscriptionStatus();
  }

  Future<void> _triggerLimitWarning(String email, String orgName, String resource, int current, int limit) async {
    try {
      final supabase = _ref.read(supabaseClientProvider);
      await supabase.functions.invoke('send-notification', body: {
        'type': 'limit_warning',
        'email': email,
        'orgName': orgName,
        'data': {
          'resource': resource,
          'current': current,
          'limit': limit
        }
      });
    } catch (e) {
      debugPrint('Notification Error: $e');
    }
  }

  // Enhanced Action Check with Warning Side-Effect
  Future<bool> canCreateProject() async {
    final user = _ref.read(authControllerProvider).valueOrNull;
    if (user == null) return false;

    final orgId = user.currentOrgId;
    final plan = await getOrgPlan(orgId);
    
    final usage = await getOrgUsage(orgId);
    final count = usage['projects'] ?? 0;
    final limit = plan.projectLimit;
    
    
    // Warning Check
    if (_isar != null) {
      final org = await _isar!.organizations.filter().codeEqualTo(orgId).findFirst();
       if (org != null && org.billingEmailVerified && org.billingEmail != null && org.notifyLimitWarnings) {
        final warningThreshold = (limit * 0.8).floor();
        if (count == warningThreshold || count == limit - 1) {
            _triggerLimitWarning(
               org.billingEmail!, 
               org.name, 
               'Proje', 
               count + 1, 
               limit
            );
        }
      }
    }

    if (limit == 0) return true; // Unlimited
    return count < limit;
  }
}


