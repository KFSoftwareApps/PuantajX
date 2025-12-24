import 'package:isar/isar.dart';

part 'attendance_model.g.dart';

@collection
class Attendance {
  Id id = Isar.autoIncrement;

  String? remoteId;

  late int projectId; // Link to Project.id

  late int workerId; // Link to Worker.id

  late DateTime date;

  double hours = 0;

  double overtimeHours = 0;

  @enumerated
  AttendanceStatus status = AttendanceStatus.present;
  
  @enumerated
  DayType dayType = DayType.normal;
  
  @enumerated
  WorkflowStatus workflowStatus = WorkflowStatus.draft;

  String? note;
  @Index()
  DateTime? lastUpdatedAt;

  bool isSynced = false;

  String? serverId;
  
  String? approvedBy; // User ID who approved
  DateTime? approvedAt;
}

enum AttendanceStatus {
  present,
  absent,
  paidLeave,
  unpaidLeave,
  sick,
}

enum DayType {
  normal,
  weekend,
  holiday,
}

enum WorkflowStatus {
  draft,
  submitted,
  approved,
  locked,
}
