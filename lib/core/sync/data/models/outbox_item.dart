import 'package:isar/isar.dart';

part 'outbox_item.g.dart';

@collection
class OutboxItem {
  Id id = Isar.autoIncrement;

  late String entityId;    // e.g. Report ID or Attachment ID (if it has one, or transient ID)
  late String entityType;  // 'ATTACHMENT', 'REPORT'
  late String operation;   // 'UPLOAD', 'CREATE', 'UPDATE'

  String? payload;         // JSON data for API
  String? localFilePath;   // For file uploads

  @Index()
  DateTime createdAt = DateTime.now();

  int retryCount = 0;
  String? lastError;

  @Index()
  bool isProcessed = false;
}
