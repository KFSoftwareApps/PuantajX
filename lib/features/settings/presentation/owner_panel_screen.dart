import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/entitlement_gate.dart';
import '../../../core/subscription/plan_config.dart';

class OwnerPanelScreen extends ConsumerWidget {
  const OwnerPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Yönetim Paneli'),
      body: EntitlementGate(
        requiredEntitlement: Entitlement.ownerPolicyPanel,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PanelCard(
              title: 'Erişim Politikaları',
              subtitle: 'Finans, Fotoğraf ve Onay kurallarını yönetin.',
              icon: Icons.shield_outlined,
              color: Colors.blue,
              onTap: () => context.push('/settings/owner-panel/policies'),
            ),
            const Gap(16),
            _PanelCard(
              title: 'Rol Şablonları',
              subtitle: 'Rollerin varsayılan yetkilerini özelleştirin.',
              icon: Icons.admin_panel_settings_outlined,
              color: Colors.orange,
              onTap: () => context.push('/settings/owner-panel/role-templates'),
            ),
            const Gap(16),
            _PanelCard(
              title: 'Kullanıcı İstisnaları',
              subtitle: 'Kişiye özel yetki tanımlayın.',
              icon: Icons.person_search_outlined,
              color: Colors.purple,
              onTap: () => context.push('/settings/owner-panel/user-overrides'),
            ),
            const Gap(16),
            _PanelCard(
              title: 'Denetim Kayıtları',
              subtitle: 'Sistemdeki kritik değişiklikleri inceleyin.',
              icon: Icons.history_edu,
              color: Colors.brown,
              onTap: () => context.push('/settings/owner-panel/audit-logs'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isComingSoon;

  const _PanelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (isComingSoon) ...[
                          const Gap(8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Yakında', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          )
                        ]
                      ],
                    ),
                    const Gap(4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
