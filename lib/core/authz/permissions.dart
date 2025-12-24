import 'package:puantaj_x/core/types/app_types.dart';
import 'package:puantaj_x/features/auth/data/models/security_models.dart';

// Tek noktadan tip paylaşımı
export 'package:puantaj_x/core/types/app_types.dart'
    show AppRole, AppPermission, PayType;

final Map<AppRole, Set<AppPermission>> defaultRolePermissions = {
  AppRole.owner: AppPermission.values.toSet(), // Full Access including roleManage, orgReadAdmin

  AppRole.admin: {
    AppPermission.orgReadBasic,
    AppPermission.orgReadAdmin,
    AppPermission.orgUpdate,
    AppPermission.auditLogView,

    AppPermission.memberInvite,
    AppPermission.memberRemove,
    AppPermission.memberRoleAssign, // Restricted role assignment

    AppPermission.projectCreate,
    AppPermission.projectRead,
    AppPermission.projectUpdate,
    AppPermission.projectArchive,
    AppPermission.projectAssignTeam,

    AppPermission.workerRead,
    AppPermission.workerCreate,
    AppPermission.workerUpdate,
    AppPermission.workerAssign,
    AppPermission.workerRateRead,
    AppPermission.workerRateEdit,

    AppPermission.timesheetRead,
    AppPermission.timesheetEdit,
    AppPermission.timesheetApprove,
    AppPermission.timesheetLock,
    AppPermission.timesheetExport,

    AppPermission.reportCreate,
    AppPermission.reportRead,
    AppPermission.reportUpdate,
    AppPermission.reportApprove,
    AppPermission.reportLock,

    AppPermission.attachmentAdd,
    AppPermission.attachmentRead,
    AppPermission.attachmentDelete,
    AppPermission.financeView,
    AppPermission.financeManage,
  },

  AppRole.supervisor: {
    AppPermission.orgReadBasic,
    AppPermission.projectRead,
    AppPermission.workerRead,
    AppPermission.timesheetRead,
    AppPermission.timesheetEdit,
    AppPermission.timesheetSubmit,
    AppPermission.timesheetExport,
    AppPermission.reportCreate,
    AppPermission.reportRead,
    AppPermission.reportUpdate,
    AppPermission.reportSubmit,
    AppPermission.attachmentAdd,
    AppPermission.attachmentRead,
    AppPermission.attachmentDelete,
  },

  AppRole.finance: {
    AppPermission.orgReadBasic,
    AppPermission.auditLogView,
    AppPermission.projectRead,
    AppPermission.workerRead,
    AppPermission.workerRateRead,
    AppPermission.timesheetRead, // Added read access
    AppPermission.timesheetLock, // Payment lock authority
    AppPermission.timesheetExport,
    AppPermission.reportRead,
    AppPermission.attachmentRead,
    AppPermission.financeView,
    AppPermission.financeManage,
  },

  AppRole.timesheetEditor: {
    AppPermission.orgReadBasic,
    AppPermission.projectRead,
    AppPermission.workerRead,
    AppPermission.timesheetRead,
    AppPermission.timesheetEdit,
    AppPermission.timesheetSubmit,
    AppPermission.timesheetExport,
    AppPermission.reportRead, // Usually readonly for editors
    AppPermission.attachmentRead,
  },

  AppRole.viewer: {
    AppPermission.orgReadBasic,
    AppPermission.projectRead,
    AppPermission.reportRead,
    AppPermission.attachmentRead,
    AppPermission.timesheetRead,
  },

  AppRole.guest: {
    AppPermission.orgReadBasic,
    AppPermission.reportRead, // Subject to policy
    AppPermission.attachmentRead, // Subject to policy
  },
};

Set<AppPermission> getEffectivePermissions({
  required AppRole role,
  OrgRoleTemplate? roleTemplate,
  MembershipOverride? override,
  OrgPolicy? policy,
}) {
  Set<AppPermission> effectivePermissions;

  if (roleTemplate != null && roleTemplate.role == role) {
    effectivePermissions = roleTemplate.permissions.toSet();
  } else {
    effectivePermissions = (defaultRolePermissions[role] ?? {}).toSet();
  }

  if (policy != null) {
    if (!policy.financeCanViewPhotos && role == AppRole.finance) {
      effectivePermissions.remove(AppPermission.attachmentRead);
    }

    if (!policy.supervisorCanManageProjectWorkers && role == AppRole.supervisor) {
      effectivePermissions.remove(AppPermission.workerCreate);
      effectivePermissions.remove(AppPermission.workerAssign);
    }
  }

  if (override != null) {
    effectivePermissions.addAll(override.grantPermissions);
    effectivePermissions.removeAll(override.denyPermissions);
  }

  if (role == AppRole.owner) {
    effectivePermissions.add(AppPermission.orgManageBilling);
    effectivePermissions.add(AppPermission.timesheetUnlock);
  }

  return effectivePermissions;
}

extension PermissionSetExtension on Set<AppPermission> {
  bool hasPermission(AppPermission permission) => contains(permission);
}
