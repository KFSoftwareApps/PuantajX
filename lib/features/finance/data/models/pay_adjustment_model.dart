import 'package:isar/isar.dart';

part 'pay_adjustment_model.g.dart';

@collection
class PayAdjustment {
  Id id = Isar.autoIncrement;

  String? remoteId;
  
  late int projectId;

  late int workerId;

  late double amount; // Positive value

  @enumerated
  late AdjustmentType type; // advance, deduction, bonus

  late DateTime date;

  String? description;

  @Index()
  DateTime? lastUpdatedAt;

  bool isSynced = false;

  String? serverId;
}

enum AdjustmentType {
  advance, // Avans (Subtract)
  deduction, // Kesinti (Subtract)
  bonus, // Prim (Add)
}
