
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../core/services/iap_service.dart';
import '../../../core/subscription/subscription_model.dart'; 
import '../../../features/auth/data/repositories/auth_repository.dart';
import '../../../core/subscription/plan_config.dart';
import '../../../core/subscription/subscription_providers.dart';
import '../../../core/widgets/custom_app_bar.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isLoading = false;

  Future<void> _purchaseProduct(ProductDetails product) async {
    setState(() => _isLoading = true);
    try {
      final iapService = ref.read(iapServiceProvider);
      await iapService.buyProduct(product);
      // Feedback is handled via stream listeners, but we show a generic wait message
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Satın alma işlemi başlatıldı. Lütfen mağaza ekranını takip edin.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      final iapService = ref.read(iapServiceProvider);
      await iapService.restorePurchases();
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geri yükleme işlemi başlatıldı.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _activateDemoPlan(SubscriptionPlan newPlan) async {
    setState(() => _isLoading = true);
    try {
        final user = ref.read(authControllerProvider).valueOrNull;
        if (user != null) {
            final subService = ref.read(subscriptionServiceProvider);
            final sub = await subService.getOrgSubscription(user.currentOrgId);
            
            if (sub != null) {
              sub.plan = newPlan;
              sub.status = SubscriptionStatus.active;
              sub.expiresAt = null; // Unlimited duration for demo
              sub.gracePeriodEndsAt = null;
              await subService.updateSubscription(sub);
            } else {
              await subService.initializeFreePlan(user.currentOrgId);
              final newSub = await subService.getOrgSubscription(user.currentOrgId);
              if (newSub != null) {
                  newSub.plan = newPlan;
                  newSub.status = SubscriptionStatus.active;
                  newSub.expiresAt = null;
                  await subService.updateSubscription(newSub);
              }
            }
            ref.invalidate(currentPlanProvider); 
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${Plans.getConfig(newPlan).displayName} planına geçildi! (Demo)')),
              );
              Navigator.pop(context);
            }
        }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(currentPlanProvider);
    final productsAsync = ref.watch(productsProvider);
    final currentConfig = Plans.getConfig(planAsync.valueOrNull?.plan ?? SubscriptionPlan.free);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Planını Seç',
        showProjectChip: false,
        showSyncStatus: false,
      ),
      body: Stack(
        children: [
              // Plan Cards
              Positioned.fill(
                child: ListView(
                  padding: const EdgeInsets.all(0),
                  children: [
                    // Header 
                    Container(
                      padding: const EdgeInsets.all(20),
                      color: Theme.of(context).primaryColor.withAlpha(13),
                      child: Column(
                        children: [
                          Text(
                            'Şantiyede hızlı giriş, ofiste düzenli takip.',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const Gap(8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.blue.withOpacity(0.2) 
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? Colors.blue.shade300 
                                    : Colors.blue.shade200
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                                const Gap(6),
                                Flexible(
                                  child: Text(
                                    'Satın alma sonrası tüm cihazlarında aktif olur.',
                                    style: TextStyle(
                                      fontSize: 11, 
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.blue.shade100 
                                          : Colors.blue.shade700
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),

                    // DYNAMIC PLAN CARDS
                    ...Plans.allPlans.map((config) {
                      final isCurrent = planAsync.valueOrNull?.plan == config.plan;
                      
                      // Price Logic
                      String priceStr = '₺${(config.priceMonthly / 100).toStringAsFixed(0)}';
                      String? unit;
                      ProductDetails? product;

                      if (config.priceMonthly > 0) {
                         unit = ' / ay';
                         // Find IAP product
                         if (productsAsync.value != null) {
                            try {
                              // Filter by name logic or ID logic
                              // 'puantajx_pro_monthly' for Pro
                              // 'puantajx_business_monthly' for Business
                              final keyword = config.plan == SubscriptionPlan.pro ? 'pro' : 'business';
                              product = productsAsync.value!.firstWhere((pkg) => pkg.id.contains(keyword));
                              
                              priceStr = product!.price;
                              unit = null; // price includes unit usually
                            } catch (_) {}
                         }
                      } else {
                         priceStr = '₺0';
                         unit = null;
                      }

                      // Limits String
                      final pLimit = config.projectLimit == 0 ? 'Sınırsız' : '${config.projectLimit}';
                      final uLimit = config.seatLimit == 0 ? 'Sınırsız' : '${config.seatLimit}';
                      final wLimit = config.workerLimit == 0 ? 'Sınırsız' : '${config.workerLimit}';
                      final limits = '$pLimit proje • $uLimit kullanıcı • $wLimit çalışan';

                      // CTA Text
                      String cta = 'Seç';
                      if (isCurrent) {
                        cta = 'Mevcut Plan';
                      } else if (config.priceMonthly > 0) {
                         if (config.priceMonthly > currentConfig.priceMonthly) {
                           cta = '${config.displayName}\'a Yükselt'; 
                           if (config.plan == SubscriptionPlan.business) cta = 'Business\'a Geç';
                           if (config.plan == SubscriptionPlan.pro) cta = 'Pro\'ya Geç';
                         } else {
                           cta = 'Planı Düşür';
                         }
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                        child: _PlanCard(
                          plan: config.plan,
                          badge: config.badgeText,
                          badgeColor: config.accentColor,
                          title: config.displayName,
                          price: priceStr,
                          priceUnit: unit,
                          description: config.description,
                          features: config.featureBullets,
                          limits: limits,
                          ctaText: cta,
                          currentPlan: planAsync.valueOrNull?.plan,
                          isPopular: config.plan == SubscriptionPlan.pro,
                          isLoading: _isLoading && !isCurrent,
                          onTap: () {
                             if (isCurrent) return;
                             if (product != null) {
                               _purchaseProduct(product!);
                             } else {
                               // REAL PRODUCTION BEHAVIOR: Show Error if Store unavailable
                               showDialog(
                                 context: context, 
                                 builder: (context) => AlertDialog(
                                   title: const Text('Mağaza Bağlantı Hatası'),
                                   content: const Text(
                                     'Google Play Store ile bağlantı kurulamadı.\n\n'
                                     'Olası sebepler:\n'
                                     '1. İnternet bağlantınız yok.\n'
                                     '2. Google Play Hizmetleri bu cihazda yüklü değil (Emülatör).\n'
                                     '3. Google Play oturumunuz açık değil.\n\n'
                                     'Lütfen gerçek bir Android cihazda deneyin.'
                                   ),
                                   actions: [
                                     TextButton(
                                       onPressed: () => Navigator.pop(context),
                                       child: const Text('Tamam'),
                                     )
                                   ],
                                 )
                               );
                             }
                          },
                        ),
                      );
                    }).toList(),

                    const Gap(24),
                    
                    // Compare Button
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showComparisonSheet(context),
                        icon: const Icon(Icons.compare_arrows),
                        label: const Text('Planları Karşılaştır'),
                      ),
                    ),
                    
                    const Gap(16),
                    // Footer
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color, // Theme card color
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FooterNote('Abonelik iptali mağaza hesabından yapılır; dönem bitene kadar erişim sürer.'),
                            const Gap(8),
                            _FooterNote('Satın aldıysan:'),
                            TextButton(
                              onPressed: _restorePurchases,
                              child: const Text('Satın Alımları Geri Yükle', style: TextStyle(fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _showComparisonSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan Karşılaştırması',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(20),
            _ComparisonRow('Free', 'Deneme, tek proje, filigranlı PDF', Colors.grey),
            const Gap(12),
            _ComparisonRow('Pro', 'Bulut + ekip + filigransız PDF', Colors.blue),
            const Gap(12),
            _ComparisonRow('Business', 'Excel + onay/kilit + audit + ödeme özeti + owner panel', Colors.purple),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final String? badge;
  final Color? badgeColor;
  final String title;
  final String price;
  final String? priceUnit;
  final String description;
  final List<String> features;
  final String limits;
  final String ctaText;
  final SubscriptionPlan? currentPlan;
  final bool isPopular;
  final VoidCallback onTap;
  final bool isLoading;

  const _PlanCard({
    required this.plan,
    this.badge,
    this.badgeColor,
    required this.title,
    required this.price,
    this.priceUnit,
    required this.description,
    required this.features,
    required this.limits,
    required this.ctaText,
    required this.onTap,
    this.currentPlan,
    this.isPopular = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = currentPlan == plan;
    final borderColor = isPopular ? Colors.blue : Colors.grey.shade300;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isCurrent ? Colors.green : borderColor, width: isCurrent ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardTheme.color,
        boxShadow: isPopular
            ? [BoxShadow(color: Colors.blue.withAlpha(26), blurRadius: 8, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (badgeColor ?? Colors.grey).withAlpha(13),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    if (badge != null) ...[
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    if (isCurrent) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Aktif Plan', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const Gap(8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    if (priceUnit != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Text(priceUnit!, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      ),
                  ],
                ),
                const Gap(8),
                Text(description, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14)),
              ],
            ),
          ),

          // Features
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, size: 18, color: badgeColor ?? Colors.green),
                          const Gap(8),
                          Expanded(child: Text(feature, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    )),
                const Gap(16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.black12 : Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(limits, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
                ),
                const Gap(16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCurrent || isLoading ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrent ? Colors.grey : (badgeColor ?? Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      ctaText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  final String text;
  const _FooterNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
        const Gap(8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color))),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String plan;
  final String description;
  final Color color;
  const _ComparisonRow(this.plan, this.description, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color),
          ),
          child: Text(plan, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12), textAlign: TextAlign.center),
        ),
        const Gap(12),
        Expanded(child: Text(description, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
