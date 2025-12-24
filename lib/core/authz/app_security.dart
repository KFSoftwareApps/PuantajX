enum AppRole { owner, admin, supervisor, finance, timesheetEditor, viewer, guest }

enum PayType { daily, hourly, monthly }

enum AppPermission {
  orgRead,
  orgUpdate,
  orgManageBilling,

  memberInvite,
  memberRemove,
  memberRefRoles,

  projectCreate,
  projectRead,
  projectUpdate,
  projectDelete,
  projectAssignTeam,

  workerRead,
  workerCreate,
  workerUpdate,
  workerAssign,
  workerRateRead,
  workerRateEdit,

  timesheetRead,
  timesheetEdit,
  timesheetSubmit,
  timesheetApprove,
  timesheetLock,
  timesheetUnlock,
  timesheetExport,

  reportCreate,
  reportRead,
  reportUpdate,
  reportSubmit,
  reportApprove,
  reportLock,
  reportUnlock,

  attachmentAdd,
  attachmentRead,
  attachmentDelete,

  financeView,
  financeManage,
}

class Permissions {
  final Set<AppPermission> set;
  const Permissions(this.set);

  bool hasPermission(AppPermission p) => set.contains(p);

  const Permissions.all() : set = const {...AppPermission.values};
}
