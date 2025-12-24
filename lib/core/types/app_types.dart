enum AppRole {
  owner,
  admin,
  supervisor,
  finance,
  timesheetEditor,
  viewer,
  guest,
}

enum AppPermission {
  // Organization
  orgReadBasic, // Name, Currency, Timezone (Safe for all)
  orgReadAdmin, // ID, Settings, Config (Admin/Owner)
  orgUpdate,
  orgManageBilling,
  
  // Policies & Logs
  policyManage,
  auditLogView,

  // Members
  memberInvite,
  memberRemove,
  memberRefRoles, // Deprecated? Or keep for reference? Keeping for now.
  memberRoleAssign, // Admin can assign limited roles
  roleManage, // Owner can manage all roles

  // Projects
  projectCreate,
  projectRead,
  projectUpdate,
  projectArchive,
  projectDelete,
  projectAssignTeam,

  // Workers
  workerRead,
  workerCreate,
  workerUpdate,
  workerAssign,
  workerRateRead,
  workerRateEdit,

  // Timesheet
  timesheetRead,
  timesheetEdit,
  timesheetSubmit,
  timesheetApprove,
  timesheetLock,
  timesheetUnlock,
  timesheetExport,

  // Reports
  reportCreate,
  reportRead,
  reportUpdate,
  reportSubmit,
  reportApprove,
  reportLock,
  reportUnlock,
  reportDelete,

  // Attachments
  attachmentAdd,
  attachmentRead,
  attachmentDelete,

  // Finance
  financeView,
  financeManage,
}

enum PayType {
  daily,
  monthly,
  hourly,
}
