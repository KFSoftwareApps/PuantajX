import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/widgets/permission_guard.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../data/models/project_member_model.dart';
import '../data/models/project_model.dart';
import 'providers/project_providers.dart';
import 'providers/project_members_provider.dart';

class ProjectMembersScreen extends ConsumerWidget {
  final int projectId;

  const ProjectMembersScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectByIdProvider(projectId));
    final membersAsync = ref.watch(projectMembersProvider(projectId));
    final currentUser = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proje Erişim Yönetimi'),
      ),
      floatingActionButton: PermissionGuard(
        permission: AppPermission.projectUpdate,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddMemberSheet(context, ref, projectId),
          label: const Text('Üye Ekle'),
          icon: const Icon(Icons.person_add),
        ),
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) return const Center(child: Text('Proje bulunamadı'));

          return Column(
            children: [
              // Info Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business, color: Colors.blue),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            project.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    const Text(
                      'Bu projeye erişimi olan kullanıcıları yönetin. Sadece organizasyon üyeleri eklenebilir.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),

              // Members List
              Expanded(
                child: membersAsync.when(
                  data: (members) {
                    if (members.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.group_off_outlined, size: 64, color: Colors.grey),
                            const Gap(16),
                            const Text('Bu projeye atanmış üye yok.'),
                            const Gap(8),
                            const Text(
                              'Organizasyon üyelerini bu projeye ekleyerek\nerişim yetkisi verebilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    // Fetch org members to get user details
                    final orgMembersAsync = ref.watch(organizationMembersProvider);

                    return orgMembersAsync.when(
                      data: (orgMembers) {
                        // Create a map for quick lookup
                        final userMap = {for (var u in orgMembers) u.id: u};

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final user = userMap[member.userId];
                            final isCurrentUser = currentUser?.id == member.userId;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.indigo.shade100,
                                  child: Text(
                                    user?.fullName?.isNotEmpty == true
                                        ? user!.fullName![0].toUpperCase()
                                        : (user?.email[0].toUpperCase() ?? '?'),
                                    style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user?.fullName ?? user?.email ?? 'Kullanıcı #${member.userId}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (isCurrentUser) ...[
                                      const Gap(8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Siz',
                                          style: TextStyle(color: Colors.white, fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (user?.email != null)
                                      Text(
                                        user!.email,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    const Gap(4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(member.roleOverrideStr),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            member.hasRoleOverride && member.roleOverrideStr != null
                                                ? member.roleOverrideStr!
                                                : 'Varsayılan',
                                            style: const TextStyle(color: Colors.white, fontSize: 10),
                                          ),
                                        ),
                                        const Gap(8),
                                        Text(
                                          'Eklendi: ${_formatDate(member.assignedAt)}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: !isCurrentUser
                                    ? PermissionGuard(
                                        permission: AppPermission.projectUpdate,
                                        child: IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                          tooltip: 'Projeden Çıkar',
                                          onPressed: () => _confirmRemoveMember(context, ref, projectId, member),
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final isCurrentUser = currentUser?.id == member.userId;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.shade100,
                                child: const Icon(Icons.person, color: Colors.indigo),
                              ),
                              title: Row(
                                children: [
                                  Text('Kullanıcı #${member.userId}'),
                                  if (isCurrentUser) ...[
                                    const Gap(8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Siz',
                                        style: TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.hasRoleOverride && member.roleOverrideStr != null
                                        ? 'Rol: ${member.roleOverrideStr}'
                                        : 'Rol: Varsayılan',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    'Eklendi: ${_formatDate(member.assignedAt)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: !isCurrentUser
                                  ? PermissionGuard(
                                      permission: AppPermission.projectUpdate,
                                      child: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                        tooltip: 'Projeden Çıkar',
                                        onPressed: () => _confirmRemoveMember(context, ref, projectId, member),
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Hata: $e')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'Admin':
        return Colors.red;
      case 'Member':
        return Colors.blue;
      case 'Viewer':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  void _showAddMemberSheet(BuildContext context, WidgetRef ref, int projectId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddMemberSheet(projectId: projectId),
    );
  }

  void _confirmRemoveMember(BuildContext context, WidgetRef ref, int projectId, ProjectMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Çıkar'),
        content: Text('Kullanıcı #${member.userId} bu projeden çıkarılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(projectMembersProvider(projectId).notifier).removeMember(member.userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Üye projeden çıkarıldı')),
                );
              }
            },
            child: const Text('Çıkar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AddMemberSheet extends ConsumerStatefulWidget {
  final int projectId;

  const _AddMemberSheet({required this.projectId});

  @override
  ConsumerState<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<_AddMemberSheet> {
  int? _selectedUserId;
  String _selectedRole = 'Member';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final orgMembersAsync = ref.watch(organizationMembersProvider);
    final currentMembersAsync = ref.watch(projectMembersProvider(widget.projectId));
    
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Üye Ekle', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const Gap(16),
              
              // Search
              TextField(
                decoration: const InputDecoration(
                  hintText: 'İsimle ara...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              ),
              
              const Gap(16),
              
              // Members List
              Expanded(
                child: orgMembersAsync.when(
                  data: (orgMembers) {
                    return currentMembersAsync.when(
                      data: (currentMembers) {
                        // Filter out already assigned members
                        final assignedUserIds = currentMembers.map((m) => m.userId).toSet();
                        final availableMembers = orgMembers
                            .where((u) => !assignedUserIds.contains(u.id))
                            .where((u) => _searchQuery.isEmpty || 
                                         u.email.toLowerCase().contains(_searchQuery) ||
                                         (u.fullName?.toLowerCase().contains(_searchQuery) ?? false))
                            .toList();

                        if (availableMembers.isEmpty) {
                          return const Center(
                            child: Text('Eklenebilecek üye bulunamadı.'),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: availableMembers.length,
                          itemBuilder: (context, index) {
                            final user = availableMembers[index];
                            final isSelected = _selectedUserId == user.id;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? Colors.indigo : Colors.grey.shade200,
                                child: Icon(
                                  Icons.person,
                                  color: isSelected ? Colors.white : Colors.grey,
                                ),
                              ),
                              title: Text(user.fullName ?? user.email),
                              subtitle: Text(user.email),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: Colors.indigo)
                                  : null,
                              onTap: () => setState(() => _selectedUserId = user.id),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Hata: $e')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Hata: $e')),
                ),
              ),
              
              const Divider(),
              const Gap(16),
              
              // Role Selection
              const Text('Rol', style: TextStyle(fontWeight: FontWeight.bold)),
              const Gap(8),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Admin', child: Text('Admin - Tam yetki')),
                  DropdownMenuItem(value: 'Member', child: Text('Üye - Standart yetki')),
                  DropdownMenuItem(value: 'Viewer', child: Text('Görüntüleyici - Sadece okuma')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRole = val);
                },
              ),
              
              const Gap(16),
              
              CustomButton(
                text: 'Ekle',
                onPressed: _selectedUserId != null ? _addMember : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addMember() async {
    if (_selectedUserId == null) return;

    try {
      await ref.read(projectMembersProvider(widget.projectId).notifier).addMember(
            _selectedUserId!,
            roleOverride: _selectedRole,
          );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Üye projeye eklendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }
}
