import 'package:isar/isar.dart';

part 'daily_report_model.g.dart';

@collection
class DailyReport {
  Id id = Isar.autoIncrement;

  String? remoteId;

  late int projectId; // Link to Project.id (local)

  late DateTime date;

  String? weather;

  String? shift;

  String? generalNote;

  String? crewDescription;

  String? resourceDescription;

  @enumerated
  ReportStatus status = ReportStatus.draft;

  String? createdBy;

  String? approvedBy;
  
  String? rejectionNote;

  DateTime? lockedAt;

  List<ReportItem> items = [];

  @Index()
  DateTime? lastUpdatedAt;

  @Index()
  late String orgId;

  bool isSynced = false;

  String? serverId;

  List<Attachment> attachments = [];

  DailyReport copyWith({
    int? projectId,
    DateTime? date,
    String? weather,
    String? shift,
    String? generalNote,
    String? crewDescription,
    String? resourceDescription,
    ReportStatus? status,
    String? createdBy,
    String? approvedBy,
    String? rejectionNote,
    List<ReportItem>? items,
    List<Attachment>? attachments,
    DateTime? lastUpdatedAt,
  }) {
    return DailyReport()
      ..id = id
      ..projectId = projectId ?? this.projectId
      ..date = date ?? this.date
      ..weather = weather ?? this.weather
      ..shift = shift ?? this.shift
      ..generalNote = generalNote ?? this.generalNote
      ..crewDescription = crewDescription ?? this.crewDescription
      ..resourceDescription = resourceDescription ?? this.resourceDescription
      ..status = status ?? this.status
      ..createdBy = createdBy ?? this.createdBy
      ..approvedBy = approvedBy ?? this.approvedBy
      ..rejectionNote = rejectionNote ?? this.rejectionNote
      ..items = items ?? List.from(this.items)
      ..attachments = attachments ?? List.from(this.attachments)
      ..lastUpdatedAt = lastUpdatedAt ?? this.lastUpdatedAt
      ..remoteId = remoteId
      ..serverId = serverId
      ..orgId = this.orgId // Link orgId
      ..isSynced = isSynced;
  }
}

@embedded
class Attachment {
  String? id;
  String? type;
  String? localPath;
  String? remoteUrl;
  String? category; // Öncesi, Sonrası, İSG, etc.
  String? note;
  DateTime? takenAt;
  
  Attachment({
    this.id,
    this.type,
    this.localPath,
    this.remoteUrl,
    this.category,
    this.note,
    this.takenAt,
  });
}

@embedded
class ReportItem {
  String? category;
  String? description;
  double? quantity;
  String? unit;
}

extension DailyReportExt on DailyReport {
  int get crewCount {
    return items
        .where((item) => item.category == 'crew')
        .fold(0, (sum, item) => sum + (item.quantity?.toInt() ?? 0));
  }
}

enum ReportStatus {
  draft,
  submitted,
  approved,
  locked,
  rejected,
}
