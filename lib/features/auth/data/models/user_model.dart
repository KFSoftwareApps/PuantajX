import 'package:isar/isar.dart';
import '../../../../core/authz/roles.dart';

part 'user_model.g.dart';

@collection
class User {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String email;

  late String fullName;

  String? phoneNumber;

  late String passwordHash;

  late String currentOrgId;

  @enumerated
  AppRole role = AppRole.owner;

  DateTime? createdAt;

  @Index()
  DateTime? lastUpdatedAt;

  bool isSynced = false;

  String? serverId;

  String? authProvider = 'email'; // email, google, apple

  @enumerated
  UserStatus status = UserStatus.active;

  List<int> assignedProjectIds = [];

  String? avatarUrl; // Remote URL
  String? avatarPath; // Local path

  // Legal Consent
  DateTime? termsAcceptedAt;
  String? termsVersion;

  DateTime? privacyAcceptedAt;
  String? privacyVersion;
}

enum UserStatus {
  active,
  pending,
  suspended,
}
