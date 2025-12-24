import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/data/models/security_models.dart';
import '../../../core/widgets/custom_app_bar.dart';

// Provider to fetch policy
final orgPolicyProvider = FutureProvider.autoDispose<OrgPolicy>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) throw Exception('User not logged in');
  final repo = ref.read(authRepositoryProvider);
  return repo.getOrgPolicy(user.currentOrgId);
});

class PolicySettingsScreen extends ConsumerWidget {
  const PolicySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policyAsync = ref.watch(orgPolicyProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Erişim Politikaları'),
      body: policyAsync.when(
        data: (policy) {
          // We modify a copy or direct object? 
          // Isar objects manages updates. But we should update via repository to persist.
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(context, 'Finans & Gizlilik'),
              _PolicySwitch(
                title: 'Finans ekibi fotoğrafları görebilir',
                subtitle: 'Açık ise Finance rolü rapor eklerini ve fotoğrafları görebilir.',
                value: policy.financeCanViewPhotos,
                onChanged: (val) async {
                  policy.financeCanViewPhotos = val;
                  await _updatePolicy(ref, policy);
                },
              ),
              _PolicySwitch(
                title: 'Supervisor proje ekibini yönetebilir',
                subtitle: 'Açık ise Supervisor rolü projeye çalışan ekleyip çıkarabilir.',
                value: policy.supervisorCanManageProjectWorkers,
                onChanged: (val) async {
                  policy.supervisorCanManageProjectWorkers = val;
                  await _updatePolicy(ref, policy);
                },
              ),
              
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Onay ve İş Akışı'),
              _PolicySwitch(
                title: 'Finans puantaj onaylayabilir',
                subtitle: 'Açık ise Finance rolü puantajları LOCKED statüsüne getirebilir.',
                value: policy.financeCanApproveTimesheets,
                onChanged: (val) async {
                  policy.financeCanApproveTimesheets = val;
                  await _updatePolicy(ref, policy);
                },
              ),
              _PolicySwitch(
                title: 'Export onayı zorunlu',
                subtitle: 'Açık ise Excel/PDF çıktıları için Admin onayı gerekir (Smart Export).',
                value: policy.exportsRequireApproval,
                onChanged: (val) async {
                  policy.exportsRequireApproval = val;
                  await _updatePolicy(ref, policy);
                },
              ),
              _PolicySwitch(
                title: 'Kilit açma sadece Şirket Sahibinde',
                subtitle: 'Açık ise Adminler kilitli dönemi açamaz, sadece Owner açabilir.',
                value: policy.lockedPeriodUnlockOnlyOwner,
                onChanged: (val) async {
                  policy.lockedPeriodUnlockOnlyOwner = val;
                  await _updatePolicy(ref, policy);
                },
              ),

              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Paylaşım'),
              _PolicySwitch(
                title: 'Misafir paylaşımı aktif',
                subtitle: 'Açık ise raporlar harici kişilerle (Misafir) paylaşılabilir.',
                value: policy.guestSharingEnabled,
                onChanged: (val) async {
                  policy.guestSharingEnabled = val;
                  await _updatePolicy(ref, policy);
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Future<void> _updatePolicy(WidgetRef ref, OrgPolicy policy) async {
    // Optimistic update logic usually, but here we just call repo and invalidate
    final repo = ref.read(authRepositoryProvider);
    await repo.updateOrgPolicy(policy);
    // Invalidate to refresh UI and global permissions
    ref.invalidate(orgPolicyProvider);
    ref.invalidate(currentPermissionsProvider); // Critical: Update guards immediately
  }
}

class _PolicySwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PolicySwitch({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
