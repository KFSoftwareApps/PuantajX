import 'permissions.dart';
import 'roles.dart';

const Map<AppRole, Set<AppPermission>> rolePermissions = {
  AppRole.owner: {
    AppPermission.orgReadBasic, AppPermission.orgReadAdmin,
    AppPermission.orgUpdate, AppPermission.orgManageBilling,
    AppPermission.auditLogView,
    AppPermission.roleManage,
    AppPermission.memberInvite, AppPermission.memberRemove, AppPermission.memberRoleAssign,
    AppPermission.projectCreate, AppPermission.projectRead, AppPermission.projectUpdate, AppPermission.projectArchive, AppPermission.projectDelete, AppPermission.projectAssignTeam,
    AppPermission.reportCreate, AppPermission.reportRead, AppPermission.reportUpdate, AppPermission.reportDelete,
    AppPermission.reportSubmit, AppPermission.reportApprove, AppPermission.reportLock, AppPermission.reportUnlock,
    AppPermission.attachmentAdd, AppPermission.attachmentRead, AppPermission.attachmentDelete,
    AppPermission.timesheetRead, AppPermission.timesheetEdit, AppPermission.timesheetApprove, AppPermission.timesheetLock, AppPermission.timesheetUnlock, AppPermission.timesheetExport,
    AppPermission.workerRead, AppPermission.workerCreate, AppPermission.workerUpdate, AppPermission.workerAssign,
    AppPermission.workerRateRead, AppPermission.workerRateEdit,
    AppPermission.financeView, AppPermission.financeManage,
  },

  AppRole.admin: {
    AppPermission.orgReadBasic, AppPermission.orgReadAdmin,
    AppPermission.orgUpdate,
    AppPermission.auditLogView,
    AppPermission.memberInvite, AppPermission.memberRemove, AppPermission.memberRoleAssign,
    AppPermission.projectCreate, AppPermission.projectRead, AppPermission.projectUpdate, AppPermission.projectArchive, AppPermission.projectAssignTeam,
    AppPermission.reportCreate, AppPermission.reportRead, AppPermission.reportUpdate, AppPermission.reportApprove, AppPermission.reportLock,
    AppPermission.attachmentAdd, AppPermission.attachmentRead, AppPermission.attachmentDelete,
    AppPermission.timesheetRead, AppPermission.timesheetEdit, AppPermission.timesheetApprove, AppPermission.timesheetLock, AppPermission.timesheetExport,
    AppPermission.workerRead, AppPermission.workerCreate, AppPermission.workerUpdate, AppPermission.workerAssign,
    AppPermission.workerRateRead, AppPermission.workerRateEdit,
    AppPermission.financeView,
  },

  AppRole.supervisor: {
    AppPermission.orgReadBasic,
    AppPermission.projectRead,
    AppPermission.projectAssignTeam,
    AppPermission.reportCreate, AppPermission.reportRead, AppPermission.reportUpdate, AppPermission.reportSubmit,
    AppPermission.attachmentAdd, AppPermission.attachmentRead, AppPermission.attachmentDelete,
    AppPermission.timesheetRead, AppPermission.timesheetEdit, AppPermission.timesheetSubmit, AppPermission.timesheetExport,
    AppPermission.workerRead, AppPermission.workerCreate, AppPermission.workerUpdate, // Policy dependent usually
  },

  AppRole.finance: {
    AppPermission.orgReadBasic,
    AppPermission.auditLogView,
    AppPermission.projectRead,
    AppPermission.reportRead,
    AppPermission.attachmentRead,
    AppPermission.timesheetRead, AppPermission.timesheetLock, AppPermission.timesheetExport,
    AppPermission.workerRead, AppPermission.workerRateRead,
    AppPermission.financeView, AppPermission.financeManage,
  },

  AppRole.timesheetEditor: {
    AppPermission.orgReadBasic,
    AppPermission.projectRead,
    AppPermission.timesheetRead, AppPermission.timesheetEdit, AppPermission.timesheetSubmit, AppPermission.timesheetExport,
    AppPermission.workerRead,
    AppPermission.reportRead, AppPermission.attachmentRead,
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
    AppPermission.reportRead,
    AppPermission.attachmentRead,
  },
};

bool hasPermission(AppRole? role, AppPermission permission) {
  if (role == null) return false;
  return rolePermissions[role]?.contains(permission) ?? false;
}
