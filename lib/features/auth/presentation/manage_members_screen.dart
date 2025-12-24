import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/authz/roles_extension.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/user_model.dart';
import 'member_detail_screen.dart';
import '../../../core/subscription/subscription_providers.dart';

class ManageMembersScreen extends ConsumerWidget {
  const ManageMembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(organizationMembersProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Ekip Yönetimi',
        showProjectChip: false,
        showSyncStatus: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(organizationMembersProvider),
            tooltip: 'Yenile',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberDialog(context, ref),
        label: const Text('Yeni Üye Davet Et'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(organizationMembersProvider),
              child: membersAsync.when(
                data: (data) {
                  if (data.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Center(
                          child: Column(
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey),
                              Gap(16),
                              Text('Henüz üye eklenmemiş', style: TextStyle(color: Colors.grey, fontSize: 16)),
                              Gap(8),
                              Text('Yeni üye davet ederek başlayın.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  // Sort: Owner first, then others
                  final members = List<User>.from(data);
                  members.sort((a, b) {
                    if (a.role == AppRole.owner && b.role != AppRole.owner) return -1;
                    if (a.role != AppRole.owner && b.role == AppRole.owner) return 1;
                    return a.fullName.compareTo(b.fullName);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isMe = member.id == currentUser?.id;
                      final roleColor = _getRoleColor(member.role);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
                            ).then((_) => ref.invalidate(organizationMembersProvider));
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: roleColor.withOpacity(0.1),
                                  child: Text(
                                    member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : '?',
                                    style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Gap(16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            member.fullName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          if (isMe) ...[
                                            const Gap(8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('SEN', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(member.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    member.role.trName,
                                    style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Gap(8),
                                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const Gap(16),
                        Text('Yükleme hatası: $e', textAlign: TextAlign.center),
                        const Gap(16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(organizationMembersProvider),
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(AppRole role) {
    switch (role) {
      case AppRole.owner: return Colors.deepOrange;
      case AppRole.admin: return Colors.blue;
      case AppRole.manager: return Colors.indigo;
      case AppRole.finance: return Colors.green;
      case AppRole.viewer: return Colors.grey;
      default: return Colors.grey;
    }
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => const _AddMemberDialog());
  }
}

class _AddMemberDialog extends ConsumerStatefulWidget {
  const _AddMemberDialog();

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  AppRole _selectedRole = AppRole.viewer;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Üye Oluştur'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Davet edilecek üyenin bilgilerini girin:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Gap(16),
            CustomTextField(label: 'Ad Soyad', controller: _nameCtrl, prefixIcon: Icons.person_outline),
            const Gap(12),
            CustomTextField(label: 'E-posta', controller: _emailCtrl, prefixIcon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const Gap(12),
            CustomTextField(label: 'Geçici Şifre', controller: _passCtrl, prefixIcon: Icons.lock_outline, obscureText: true),
            const Gap(16),
            const Text('Üye Rolü', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Gap(8),
            DropdownButtonFormField<AppRole>(
              value: _selectedRole,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: AppRole.values
                  .where((r) => r != AppRole.owner)
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.trName)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRole = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Oluştur ve Davet Et'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldurun')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentUser = ref.read(authControllerProvider).valueOrNull;
      if (currentUser == null) throw Exception('Oturum bulunamadı.');

      await ref.read(authRepositoryProvider).inviteMember(
        orgId: currentUser.currentOrgId,
        email: email,
        fullName: name,
        role: _selectedRole,
        temporaryPassword: pass,
      );
      
      ref.invalidate(organizationMembersProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name başarıyla eklendi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

