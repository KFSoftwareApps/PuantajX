import 'package:isar/isar.dart';

part 'project_member_model.g.dart';

/// Represents a login user's assignment to a project
@collection
class ProjectMember {
  Id id = Isar.autoIncrement;

  @Index()
  late int projectId;

  @Index()
  late int userId; // Login user (from User model)

  /// If true, this user has a custom role for this project (stored separately)
  bool hasRoleOverride = false;
  
  /// Role override as string (to avoid nullable enum issues)
  String? roleOverrideStr;

  late DateTime assignedAt;

  bool isActive = true;

  // Sync fields
  bool isSynced = false;
  String? serverId;
  @Index()
  DateTime? lastUpdatedAt;
}
