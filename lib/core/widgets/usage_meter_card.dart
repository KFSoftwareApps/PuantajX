import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../subscription/plan_config.dart';
import '../subscription/subscription_providers.dart';

/// Shows usage meters for current plan limits
class UsageMeterCard extends ConsumerWidget {
  const UsageMeterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(currentPlanProvider);
    final usageAsync = ref.watch(currentUsageProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 20),
                const Gap(8),
                const Text('Kullanım Durumu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                planAsync.when(
                  data: (plan) => _PlanBadge(plan: plan.plan),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const Gap(16),
            planAsync.when(
              data: (plan) => usageAsync.when(
                data: (usage) => Column(
                  children: [
                    if (!plan.isUnlimited('projects'))
                      _UsageMeter(
                        label: 'Projeler',
                        current: usage['projects'] ?? 0,
                        limit: plan.projectLimit,
                        icon: Icons.folder_outlined,
                      ),
                    if (!plan.isUnlimited('seats'))
                      _UsageMeter(
                        label: 'Kullanıcılar',
                        current: usage['seats'] ?? 0,
                        limit: plan.seatLimit,
                        icon: Icons.people_outline,
                      ),
                    if (!plan.isUnlimited('workers'))
                      _UsageMeter(
                        label: 'Çalışanlar',
                        current: usage['workers'] ?? 0,
                        limit: plan.workerLimit,
                        icon: Icons.engineering_outlined,
                      ),
                    if (!plan.isUnlimited('photos'))
                      _UsageMeter(
                        label: 'Fotoğraflar',
                        current: usage['photos'] ?? 0,
                        limit: plan.photoLimit,
                        icon: Icons.photo_library_outlined,
                      ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Kullanım bilgisi yüklenemedi'),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Plan bilgisi yüklenemedi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final SubscriptionPlan plan;

  const _PlanBadge({required this.plan});

  @override
  Widget build(BuildContext context) {
    final color = _getPlanColor();
    final name = _getPlanName();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        name,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Color _getPlanColor() {
    switch (plan) {
      case SubscriptionPlan.free: return Colors.grey;
      case SubscriptionPlan.pro: return Colors.blue;
      case SubscriptionPlan.business: return Colors.purple;
    }
  }

  String _getPlanName() {
    switch (plan) {
      case SubscriptionPlan.free: return 'FREE';
      case SubscriptionPlan.pro: return 'PRO';
      case SubscriptionPlan.business: return 'BUSINESS';
    }
  }
}

class _UsageMeter extends StatelessWidget {
  final String label;
  final int current;
  final int limit;
  final IconData icon;

  const _UsageMeter({
    required this.label,
    required this.current,
    required this.limit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = limit > 0 ? (current / limit).clamp(0.0, 1.0) : 0.0;
    final isNearLimit = percentage >= 0.8;
    final isAtLimit = current >= limit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const Gap(8),
              Text(label, style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                '$current / $limit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isAtLimit ? Colors.red : (isNearLimit ? Colors.orange : Colors.grey[700]),
                ),
              ),
            ],
          ),
          const Gap(8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                isAtLimit ? Colors.red : (isNearLimit ? Colors.orange : Theme.of(context).primaryColor),
              ),
              minHeight: 8,
            ),
          ),
          if (isNearLimit) ...[
            const Gap(4),
            Text(
              isAtLimit ? 'Limit doldu! Yükseltme gerekli.' : 'Limite yaklaşıyorsunuz',
              style: TextStyle(
                fontSize: 11,
                color: isAtLimit ? Colors.red : Colors.orange,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
