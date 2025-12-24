import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../core/subscription/plan_config.dart';
import '../../../features/auth/presentation/owner_panel_screen.dart'; // Using existing logic or new placeholder
import '../../../core/subscription/subscription_providers.dart';

class LockedFeaturePlaceholder extends ConsumerWidget {
  final String featureKey;
  final String title;
  final String description;
  final VoidCallback? onUpgrade;

  const LockedFeaturePlaceholder({
    super.key,
    required this.featureKey, // E.g. 'audit_log', 'excel_export' (can be mapped to Entitlement)
    required this.title,
    required this.description,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline, size: 32, color: Colors.amber.shade800),
            ),
            const Gap(16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const Gap(8),
            Text(description, style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
            const Gap(24),
            ElevatedButton.icon(
              onPressed: onUpgrade ?? () => context.push('/settings/subscription'),
              icon: const Icon(Icons.star_outline),
              label: const Text('Paketi Yükselt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
