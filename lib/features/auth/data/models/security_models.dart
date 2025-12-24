import 'package:isar/isar.dart';
import 'package:puantaj_x/core/types/app_types.dart';

part 'security_models.g.dart';

/// Defines organization-wide security policies.
@collection
class OrgPolicy {
  Id id = Isar.autoIncrement;

  late String orgId;

  // Policies
  bool financeCanViewPhotos = true;
  bool supervisorCanManageProjectWorkers = false;
  bool financeCanApproveTimesheets = false;
  bool exportsRequireApproval = false;
  bool guestSharingEnabled = true;
  bool lockedPeriodUnlockOnlyOwner = true;

  @Index()
  DateTime? updatedAt;
  String? updatedBy;
}

/// Defines custom permission templates for roles per organization.
@collection
class OrgRoleTemplate {
  Id id = Isar.autoIncrement;

  late String orgId;

  @enumerated
  late AppRole role;

  /// List of enabled permissions for this role template.
  @enumerated
  List<AppPermission> permissions = [];

  @Index()
  DateTime? updatedAt;
}

/// Defines user-specific permission overrides (Grant/Deny).
@collection
class MembershipOverride {
  Id id = Isar.autoIncrement;

  late String memberId; // Links to the user/member

  @enumerated
  List<AppPermission> grantPermissions = [];

  @enumerated
  List<AppPermission> denyPermissions = [];

  @Index()
  DateTime? updatedAt;
  String? updatedBy;
}

/// Audit log for critical security actions.
@collection
class AuditLog {
  Id id = Isar.autoIncrement;

  @Index()
  late String orgId;

  @Index()
  late String userId;

  late String action; // e.g., "ROLE_UPDATE", "TIMESHEET_LOCK"

  String? resourceId; // ID of the affected object (e.g. projectID)

  String? details; // JSON or text details

  @Index()
  late DateTime timestamp;
}
