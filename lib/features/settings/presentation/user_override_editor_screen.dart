import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:isar/isar.dart';
import '../../../core/init/providers.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/authz/roles.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/data/models/security_models.dart';
import '../../auth/data/repositories/user_override_repository.dart';
import '../../auth/data/repositories/auth_repository.dart';

// Provider for user override repository
final userOverrideRepositoryProvider = Provider<UserOverrideRepository?>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  if (isar == null) return null;
  return UserOverrideRepository(isar);
});

// Provider for specific user
final userProvider = FutureProvider.family<User?, int>((ref, userId) async {
  final isar = await ref.watch(isarProvider.future);
  if (isar == null) return null;
  return await isar.users.get(userId);
});


// Provider for user's override
final userOverrideProvider = FutureProvider.family<MembershipOverride?, int>((ref, userId) async {
  final repo = ref.read(userOverrideRepositoryProvider);
  if (repo == null) return null;
  return await repo.getOverrideForUser(userId.toString());
});

class UserOverrideEditorScreen extends ConsumerStatefulWidget {
  final int userId;

  const UserOverrideEditorScreen({super.key, required this.userId});

  @override
  ConsumerState<UserOverrideEditorScreen> createState() => _UserOverrideEditorScreenState();
}

class _UserOverrideEditorScreenState extends ConsumerState<UserOverrideEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Set<AppPermission> _grantPermissions = {};
  Set<AppPermission> _denyPermissions = {};
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProvider(widget.userId));
    final overrideAsync = ref.watch(userOverrideProvider(widget.userId));

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Kullanıcı İzinleri',
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveOverrides(context),
            ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Kullanıcı bulunamadı'));

          return overrideAsync.when(
            data: (override) {
              if (!_hasChanges && override != null) {
                _grantPermissions = override.grantPermissions.toSet();
                _denyPermissions = override.denyPermissions.toSet();
              }

              return Column(
                children: [
                  _buildUserHeader(user),
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Bilgiler'),
                      Tab(text: 'Grant'),
                      Tab(text: 'Deny'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(user),
                        _buildGrantTab(user),
                        _buildDenyTab(user),
                      ],
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Hata: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Widget _buildUserHeader(User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(user.email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const Gap(4),
                Text('Rol: ${_getRoleName(user.role)}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(User user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Temel Bilgiler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Gap(16),
        ListTile(
          title: const Text('Ad Soyad'),
          subtitle: Text(user.fullName),
          leading: const Icon(Icons.person),
        ),
        ListTile(
          title: const Text('E-posta'),
          subtitle: Text(user.email),
          leading: const Icon(Icons.email),
        ),
        ListTile(
          title: const Text('Rol'),
          subtitle: Text(_getRoleName(user.role)),
          leading: const Icon(Icons.badge),
        ),
      ],
    );
  }

  Widget _buildGrantTab(User user) {
    return _buildPermissionList(
      selected: _grantPermissions,
      onToggle: (perm, value) {
        setState(() {
          if (value) {
            _grantPermissions.add(perm);
            _denyPermissions.remove(perm);
          } else {
            _grantPermissions.remove(perm);
          }
          _hasChanges = true;
        });
      },
      icon: Icons.check_circle,
      activeColor: Colors.green,
    );
  }

  Widget _buildDenyTab(User user) {
    return _buildPermissionList(
      selected: _denyPermissions,
      onToggle: (perm, value) {
        setState(() {
          if (value) {
            _denyPermissions.add(perm);
            _grantPermissions.remove(perm);
          } else {
            _denyPermissions.remove(perm);
          }
           _hasChanges = true;
        });
      },
       icon: Icons.block,
       activeColor: Colors.red,
    );
  }

  Widget _buildPermissionList({
    required Set<AppPermission> selected,
    required Function(AppPermission, bool) onToggle,
    required IconData icon,
    required Color activeColor,
  }) {
    // Sort permissions alphabetically for better UX
    final permissions = AppPermission.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: permissions.length,
      itemBuilder: (context, index) {
        final perm = permissions[index];
        final isSelected = selected.contains(perm);

        return SwitchListTile(
          title: Text(perm.name),
          subtitle: Text('ID: ${perm.index}'),
          value: isSelected,
          activeColor: activeColor,
          secondary: Icon(icon, color: isSelected ? activeColor : Colors.grey),
          onChanged: (val) => onToggle(perm, val),
        );
      },
    );
  }

  String _getRoleName(AppRole role) {
    switch (role) {
      case AppRole.owner: return 'Sahip';
      case AppRole.admin: return 'Yönetici';
      case AppRole.supervisor: return 'Şantiye Şefi';
      case AppRole.finance: return 'Finans';
      case AppRole.timesheetEditor: return 'Puantaj Sorumlusu';
      case AppRole.viewer: return 'Görüntüleyici';
      case AppRole.guest: return 'Misafir';
    }
  }

  Future<void> _saveOverrides(BuildContext context) async {
    try {
      final repo = ref.read(userOverrideRepositoryProvider);
      if (repo == null) throw Exception('Local database not available');
      
      await repo.setOverride(
        widget.userId.toString(),
        grant: _grantPermissions.toList(),
        deny: _denyPermissions.toList(),
      );


      setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Değişiklikler kaydedildi')),
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
