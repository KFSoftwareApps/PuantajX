import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/authz/app_security.dart';

class RoleTemplatesScreen extends StatelessWidget {
  const RoleTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rol Şablonları')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: AppRole.values.length,
        itemBuilder: (context, i) {
          final role = AppRole.values[i];
          return Card(
            child: ListTile(
              title: Text(_roleLabel(role)),
              subtitle: Text(role.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/owner-panel/role-templates/${role.name}'),
            ),
          );
        },
      ),
    );
  }

  String _roleLabel(AppRole r) => switch (r) {
        AppRole.owner => 'Sahip',
        AppRole.admin => 'Yönetici',
        AppRole.supervisor => 'Şantiye Şefi',
        AppRole.finance => 'Finans',
        AppRole.timesheetEditor => 'Puantaj Sorumlusu',
        AppRole.viewer => 'Görüntüleyici',
        AppRole.guest => 'Misafir',
      };
}
