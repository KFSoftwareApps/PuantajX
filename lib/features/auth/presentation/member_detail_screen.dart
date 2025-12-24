import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart'; // Add go_router import
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/authz/roles.dart';
import '../../../core/authz/roles_extension.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import '../../project/data/models/project_model.dart';
import '../../project/presentation/providers/project_providers.dart';

class MemberDetailScreen extends ConsumerStatefulWidget {
  final User member;

  const MemberDetailScreen({super.key, required this.member});

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  late AppRole _currentRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.member.role;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    
    // Watch the members list to get real-time updates for this specific member
    final membersAsync = ref.watch(organizationMembersProvider);
    final liveMember = membersAsync.valueOrNull?.firstWhere(
      (m) => m.id == widget.member.id,
      orElse: () => widget.member,
    ) ?? widget.member;

    final isMe = currentUser?.id == liveMember.id;
    final canManage = currentUser?.role == AppRole.owner; // Only owner can manage roles for now

    return Scaffold(
      appBar: const CustomAppBar(title: 'Üye Detayı', showProjectChip: false, showSyncStatus: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  child: Text(
                    liveMember.fullName.isNotEmpty ? liveMember.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(liveMember.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(liveMember.email, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Role Section
            const Text('Rol ve Yetkiler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Gap(12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AppRole>(
                  value: _currentRole,
                  isExpanded: true,
                  items: AppRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      // Disable Owner option if current user is not Owner
                      enabled: canManage && (role != AppRole.owner || currentUser?.role == AppRole.owner),
                      child: Text(role.trName),
                    );
                  }).toList(),
                  onChanged: (canManage && !isMe)
                      ? (val) {
                          if (val != null) _updateRole(val);
                        }
                      : null, // Disable if not manager or if it's me
                ),
              ),
            ),
            if (_currentRole == AppRole.finance) ...[
              const Gap(8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    Gap(8),
                    Expanded(child: Text('Finans rolü tüm ücret ve ödemeleri görüntüleyebilir.', style: TextStyle(color: Colors.blue, fontSize: 12))),
                  ],
                ),
              ),
            ],

            const Gap(24),
            
            // Project Access (Phase 4)
            // Project Access (Phase 4)
            if (canManage) ...[
               const Text('Proje Erişimleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               const Gap(12),
               if (liveMember.role == AppRole.owner)
                 Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.grey.shade100,
                     border: Border.all(color: Colors.grey.shade300),
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: Row(
                     children: [
                       const Icon(Icons.lock, color: Colors.grey),
                       const Gap(12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             const Text('Tam Erişim (Yönetici)', style: TextStyle(fontWeight: FontWeight.bold)),
                             Text('Yöneticiler tüm projelere otomatik erişir.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                           ],
                         ),
                       ),
                     ],
                   ),
                 )
               else
                 InkWell(
                   onTap: () => _showProjectAccessDialog(),
                   borderRadius: BorderRadius.circular(8),
                   child: Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.shade300),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Row(
                       children: [
                         Icon(
                           Icons.business, 
                           color: liveMember.assignedProjectIds.isEmpty ? Colors.orange : Colors.blueGrey
                         ),
                         const Gap(12),
                         Expanded(
                           child: liveMember.assignedProjectIds.isEmpty 
                             ? const Text('Proje Erişimi Yok - Ata', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                             : Text('${liveMember.assignedProjectIds.length} Projeye Erişim Var', style: TextStyle(fontSize: 15)),
                         ),
                         const Icon(Icons.chevron_right, color: Colors.grey),
                       ],
                     ),
                   ),
                 ),
            ],

            const Gap(40),

            // Actions
             if (canManage && !isMe)
              Center(
                 child: TextButton(
                   onPressed: () => _confirmRemove(context),
                   child: const Text('Organizasyondan Kaldır', style: TextStyle(color: Colors.red)),
                 ),
              )
          ],
        ),
      ),
    );
  }

  Future<void> _updateRole(AppRole newRole) async {
    // 1. Check last owner rule if demoting
    if (_currentRole == AppRole.owner && newRole != AppRole.owner) {
      final members = await ref.read(organizationMembersProvider.future);
      final ownerCount = members.where((m) => m.role == AppRole.owner).length;
      if (ownerCount <= 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organizasyonda en az 1 yönetici kalmalıdır.')));
        }
        return;
      }
    }

    setState(() => _currentRole = newRole);
    // Optimistic update
    try {
      await ref.read(authRepositoryProvider).updateMemberRole(widget.member.id, newRole);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol güncellendi')));
      ref.invalidate(organizationMembersProvider);
    } catch (e) {
      setState(() => _currentRole = widget.member.role); // Revert
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _showProjectAccessDialog() {
    showDialog(
      context: context,
      builder: (context) => _ProjectAccessDialog(
        initialIds: widget.member.assignedProjectIds,
        memberId: widget.member.id,
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Kaldır'),
        content: Text('${widget.member.fullName} organizasyondan kaldırılsın mı? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _performRemove();
            },
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performRemove() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final repo = ref.read(authRepositoryProvider);
    final nav = Navigator.of(context); // Capture navigator

    setState(() => _isLoading = true);
    try {
      await repo.removeMember(widget.member.id);
      ref.invalidate(organizationMembersProvider);
      
      if (mounted) {
         nav.pop(); // Go back to list
         scaffoldMessenger.showSnackBar(
           SnackBar(
             content: Text('${widget.member.fullName} kaldırıldı'),
             action: SnackBarAction(
               label: 'Geri Al', 
               onPressed: () {
                 // Re-invite logic would be complex (password issue). 
                 // For now, this is a "Fake" undo or we just don't offer it if we deleted.
                 // "Opsiyonel" -> user asked for it. 
                 // Implementing real undo requires Soft Delete or avoiding the delete call.
                 scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Geri alma işlemi henüz aktif değil (Soft Delete gerekli)')));
               } 
             ),
           ),
         );
      }
    } catch (e) {
      if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }
}



class _ProjectAccessDialog extends ConsumerStatefulWidget {
  final List<int> initialIds;
  final int memberId;
  const _ProjectAccessDialog({required this.initialIds, required this.memberId});

  @override
  ConsumerState<_ProjectAccessDialog> createState() => _ProjectAccessDialogState();
}

class _ProjectAccessDialogState extends ConsumerState<_ProjectAccessDialog> {
  late Set<int> _selectedIds;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider);

    return AlertDialog(
      title: const Text('Proje Erişimleri'),
      content: SizedBox(
        width: double.maxFinite,
        child: projectsAsync.when(
          data: (projects) {
            if (projects.isEmpty) {
               return Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Icon(Icons.folder_off, size: 48, color: Colors.grey),
                   const Gap(16),
                   const Text('Henüz proje oluşturulmamış.', textAlign: TextAlign.center),
                   const Gap(8),
                   TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))
                 ],
               );
            }
            
            final allSelected = projects.length == _selectedIds.length;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Select All Option
                CheckboxListTile(
                  title: const Text('Hepsini Seç', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: allSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds = projects.map((p) => p.id).toSet();
                      } else {
                        _selectedIds.clear();
                      }
                    });
                  },
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      final project = projects[index];
                      final isSelected = _selectedIds.contains(project.id);
                      return CheckboxListTile(
                        title: Text(project.name),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedIds.add(project.id);
                            } else {
                              _selectedIds.remove(project.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
          error: (e, s) => Text('Hata: $e'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kaydet'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).updateUserProjects(
        widget.memberId,
        _selectedIds.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erişimler güncellendi')));
        ref.invalidate(organizationMembersProvider); // Refresh list/member detail parent if needed
        // Note: Parent MemberDetailScreen might need refresh if it uses cache. 
        // Currently MemberDetailScreen uses passed-in `User`. We might want to refresh it or just use optimistic update.
        // For accurate UI in parent, invalidating org members is correct, but since we pushed a route, the parent is under it.
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
