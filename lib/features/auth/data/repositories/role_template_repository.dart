import 'package:isar/isar.dart';
import '../models/security_models.dart';
import '../../../../core/types/app_types.dart';
import '../../../../core/authz/permissions.dart';

class RoleTemplateRepository {
  final Isar _isar;

  RoleTemplateRepository(this._isar);

  Future<OrgRoleTemplate?> getTemplateForRole(AppRole role) async {
    return await _isar.orgRoleTemplates
        .filter()
        .roleEqualTo(role)
        .findFirst();
  }

  Future<void> saveTemplate(AppRole role, List<AppPermission> permissions) async {
    final existing = await getTemplateForRole(role);
    final template = existing ?? OrgRoleTemplate()
      ..role = role
      ..orgId = 'default'; // Multi-tenant support later

    template.permissions = permissions;
    template.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.orgRoleTemplates.put(template);
    });
  }

  /// Reset to hardcoded defaults
  Future<void> resetToDefaults(AppRole role) async {
    final defaults = defaultRolePermissions[role]?.toList() ?? [];
    await saveTemplate(role, defaults);
  }
}
