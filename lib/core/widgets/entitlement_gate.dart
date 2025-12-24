import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../subscription/plan_config.dart';
import '../subscription/subscription_providers.dart';
import '../../features/settings/presentation/subscription_screen.dart';

/// Widget that gates a feature based on entitlement
class EntitlementGate extends ConsumerWidget {
  final Entitlement requiredEntitlement;
  final Widget child;
  final Widget? fallback;
  final VoidCallback? onUpgradeRequested;

  const EntitlementGate({
    super.key,
    required this.requiredEntitlement,
    required this.child,
    this.fallback,
    this.onUpgradeRequested,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasEntitlement = ref.watch(hasEntitlementProvider(requiredEntitlement));

    return hasEntitlement.when(
      data: (has) {
        if (has) return child;
        
        return fallback ?? InkWell(
          onTap: () => _showUpsellDialog(context, ref),
          child: Opacity(
            opacity: 0.5,
            child: Stack(
              children: [
                child,
                Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(Icons.lock, color: Colors.white, size: 32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showUpsellDialog(BuildContext context, WidgetRef ref) {
    if (onUpgradeRequested != null) {
      onUpgradeRequested!();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => UpsellDialog(requiredEntitlement: requiredEntitlement),
    );
  }
}

/// Dialog shown when user tries to access a locked feature
class UpsellDialog extends ConsumerWidget {
  final Entitlement requiredEntitlement;

  const UpsellDialog({super.key, required this.requiredEntitlement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPlan = ref.watch(currentPlanProvider).valueOrNull ?? Plans.free;
    final requiredPlan = _getRequiredPlan(requiredEntitlement);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.workspace_premium, color: _getPlanColor(requiredPlan)),
          const Gap(12),
          Text(_getPlanDisplayName(requiredPlan)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getFeatureDescription(requiredEntitlement),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            Text(_getFeatureBenefits(requiredEntitlement)),
            const Gap(24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getPlanColor(requiredPlan).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getPlanColor(requiredPlan)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_getPlanDisplayName(requiredPlan)} Planı',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getPlanColor(requiredPlan),
                    ),
                  ),
                  const Gap(8),
                  Text(
                    _getPlanPrice(requiredPlan),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Gap(8),
                  ..._getPlanFeatures(requiredPlan).map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: _getPlanColor(requiredPlan)),
                        const Gap(8),
                        Expanded(child: Text(feature, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionScreen()));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _getPlanColor(requiredPlan),
          ),
          child: const Text('Yükselt'),
        ),
      ],
    );
  }

  SubscriptionPlan _getRequiredPlan(Entitlement entitlement) {
    if (Plans.pro.hasEntitlement(entitlement)) return SubscriptionPlan.pro;
    if (Plans.business.hasEntitlement(entitlement)) return SubscriptionPlan.business;
    return SubscriptionPlan.free;
  }

  Color _getPlanColor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free: return Colors.grey;
      case SubscriptionPlan.pro: return Colors.blue;
      case SubscriptionPlan.business: return Colors.purple;
    }
  }

  String _getPlanDisplayName(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free: return 'Free';
      case SubscriptionPlan.pro: return 'Pro';
      case SubscriptionPlan.business: return 'Business';
    }
  }

  String _getPlanPrice(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free: return '₺0/ay';
      case SubscriptionPlan.pro: return '₺999/ay';
      case SubscriptionPlan.business: return '₺1.999/ay';
    }
  }

  String _getFeatureDescription(Entitlement entitlement) {
    final descriptions = {
      Entitlement.cloudSync: 'Bulut Senkronizasyonu',
      Entitlement.excelExport: 'Excel/CSV Dışa Aktarma',
      Entitlement.approvalFlow: 'Onay Akışı',
      Entitlement.periodLock: 'Dönem Kilitleme',
      Entitlement.auditLog: 'Denetim Kayıtları',
      Entitlement.wageRates: 'Ücret Yönetimi',
      Entitlement.paymentSummary: 'Ödeme Özeti',
      Entitlement.ownerPolicyPanel: 'Politika Yönetimi',
      Entitlement.roleTemplates: 'Rol Şablonları',
      Entitlement.userOverrides: 'Kullanıcı İstisnaları',
      Entitlement.guestSharing: 'Misafir Paylaşımı',
    };
    return descriptions[entitlement] ?? 'Premium Özellik';
  }

  String _getFeatureBenefits(Entitlement entitlement) {
    final benefits = {
      Entitlement.cloudSync: 'Verileriniz bulutta güvende. Tüm cihazlarınızdan erişin.',
      Entitlement.excelExport: 'Raporlarınızı Excel formatında dışa aktarın ve analiz edin.',
      Entitlement.approvalFlow: 'Puantaj ve raporları onaylayın, kontrol altında tutun.',
      Entitlement.periodLock: 'Ay kapanışı yapın, geçmiş dönemleri kilitleyin.',
      Entitlement.auditLog: 'Kim ne değiştirdi? Tüm işlemleri takip edin.',
      Entitlement.wageRates: 'Çalışan ücretlerini tanımlayın, maliyetleri hesaplayın.',
      Entitlement.paymentSummary: 'Bu ay kime ne ödenecek? Hakediş özetini görün.',
      Entitlement.ownerPolicyPanel: 'Şirketinize özel güvenlik kuralları belirleyin.',
      Entitlement.roleTemplates: 'Rollerin yetkilerini özelleştirin.',
      Entitlement.userOverrides: 'Kişiye özel izinler tanımlayın.',
      Entitlement.guestSharing: 'Raporları müşterilerle güvenli paylaşın.',
    };
    return benefits[entitlement] ?? 'Bu özellik premium planlarda mevcuttur.';
  }

  List<String> _getPlanFeatures(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.pro:
        return [
          '5 proje',
          '10 kullanıcı',
          '200 çalışan',
          'Bulut senkron',
          'Sınırsız geçmiş',
          'Filigransız PDF',
        ];
      case SubscriptionPlan.business:
        return [
          'Sınırsız proje',
          '25 kullanıcı',
          'Sınırsız çalışan',
          'Excel/CSV export',
          'Onay/Kilit akışı',
          'Audit log',
          'Ücret + Ödeme özeti',
          'Owner panel',
        ];
      default:
        return [];
    }
  }
}
