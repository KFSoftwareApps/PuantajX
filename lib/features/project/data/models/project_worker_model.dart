import 'package:isar/isar.dart';

part 'project_worker_model.g.dart';

@collection
class ProjectWorker {
  Id id = Isar.autoIncrement;

  @Index()
  late int projectId;

  @Index()
  late int workerId;

  @Index()
  int? crewId; // Reference to a Worker of type 'crew'

  bool isActive = true;

  late DateTime assignedAt;

  // Sync fields
  bool isSynced = false;
  String? serverId;
  @Index()
  DateTime? lastUpdatedAt;
}
