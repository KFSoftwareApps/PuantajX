import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../../core/authz/permissions.dart';
import '../../../core/init/providers.dart';
import '../../auth/data/repositories/role_template_repository.dart';

final roleTemplateRepositoryProvider = Provider<RoleTemplateRepository>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  if (isar == null) throw UnimplementedError('Isar not initialized');
  return RoleTemplateRepository(isar);
});

final roleTemplateProvider = FutureProvider.family<List<AppPermission>, AppRole>((ref, role) async {
  final repo = ref.read(roleTemplateRepositoryProvider);
  final template = await repo.getTemplateForRole(role);
  if (template != null) return template.permissions;
  return defaultRolePermissions[role]?.toList() ?? [];
});

class RoleTemplateEditorScreen extends ConsumerStatefulWidget {
  final String roleStr;
  const RoleTemplateEditorScreen({super.key, required this.roleStr});

  @override
  ConsumerState<RoleTemplateEditorScreen> createState() => _RoleTemplateEditorScreenState();
}

class _RoleTemplateEditorScreenState extends ConsumerState<RoleTemplateEditorScreen> {
  late final AppRole _role;
  Set<AppPermission> _selected = <AppPermission>{};
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _role = AppRole.values.firstWhere(
      (r) => r.name == widget.roleStr,
      orElse: () => AppRole.viewer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final permsAsync = ref.watch(roleTemplateProvider(_role));

    return Scaffold(
      appBar: AppBar(
        title: Text('Şablon: ${_getRoleName(_role)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Varsayılanlara Dön',
            onPressed: _resetToDefaults,
          ),
          if (_hasChanges)
             IconButton(
               icon: const Icon(Icons.save),
               onPressed: _save,
             )
        ],
      ),
      body: permsAsync.when(
        data: (perms) {
          if (_isLoading) {
            // First load initialization
            _selected = perms.toSet();
            _isLoading = false;
          }

          final allPerms = AppPermission.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allPerms.length,
            itemBuilder: (context, index) {
              final perm = allPerms[index];
              final isSelected = _selected.contains(perm);

              return SwitchListTile(
                title: Text(perm.name),
                subtitle: Text('ID: ${perm.index}'),
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val) {
                      _selected.add(perm);
                    } else {
                      _selected.remove(perm);
                    }
                    _hasChanges = true;
                  });
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
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

  Future<void> _save() async {
    try {
      final repo = ref.read(roleTemplateRepositoryProvider);
      await repo.saveTemplate(_role, _selected.toList());
      
      setState(() => _hasChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Şablon güncellendi')),
        );
      }
      // Invalidate provider to reflect changes if necessary, 
      // but strictly we're just updating the repo.
      ref.invalidate(roleTemplateProvider(_role));
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varsayılanlara Dön?'),
        content: const Text('Bu rol için tüm özel izin ayarları silinecek ve varsayılan ayarlara dönülecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sıfırla', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
       try {
        final repo = ref.read(roleTemplateRepositoryProvider);
        await repo.resetToDefaults(_role);
        ref.invalidate(roleTemplateProvider(_role)); // optimized
        setState(() {
           _isLoading = true; // Trigger re-init of state
           _hasChanges = false;
        });
       } catch(e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
          }
       }
    }
  }
}
