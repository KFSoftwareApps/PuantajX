import 'package:isar/isar.dart';

part 'project_model.g.dart';

@collection
class Project {
  Id id = Isar.autoIncrement;

  String? remoteId;

  late String orgId;

  late String name;

  String? location;

  @Index()
  String? projectCode;

  @enumerated
  late ProjectStatus status;

  late DateTime createdAt;

  @Index()
  DateTime? lastUpdatedAt;

  bool isSynced = false;

  String? serverId; // ID from the cloud DB
  
  // Finance Multipliers
  double overtimeMultiplier = 1.5;
  double weekendMultiplier = 1.0;
  double holidayMultiplier = 1.0;
  
  double hoursPerDay = 8.0;
  int monthlyWorkDays = 26;
  
  DateTime? financeLockDate;
}

enum ProjectStatus {
  active,
  archived,
}
