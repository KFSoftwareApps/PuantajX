import 'package:isar/isar.dart';
import '../../../../core/types/app_types.dart';

part 'worker_model.g.dart';

@collection
class Worker {
  Id id = Isar.autoIncrement;

  @Index()
  late String orgId;

  @Index()
  late String name;

  String? trade;

  String currency = 'TRY';

  bool active = true;

  /// 'worker' | 'crew' gibi (ekranların beklediği alan)
  String type = 'worker';

  String? description;

  @enumerated
  PayType payType = PayType.daily;

  double? dailyRate;
  double? hourlyRate;
  double? monthlySalary; // New field for fixed monthly salary
  double? monthlyRate; // Keeping for compatibility or specific rate? User mentioned monthlySalary.
  double? overtimeRate;
  double? holidayRate;

  DateTime? createdAt;

  @Index()
  DateTime? lastUpdatedAt;

  // Sync fields
  bool isSynced = false;
  String? serverId;

  String? iban;
  String? phone;
}
