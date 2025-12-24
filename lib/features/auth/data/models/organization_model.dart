import 'package:isar/isar.dart';

part 'organization_model.g.dart';

@collection
class Organization {
  Id id = Isar.autoIncrement;
  
  @Index(unique: true)
  late String code; // Unique Org Code (e.g. PUANTAJX)

  late String name;

  String? address;

  String? taxNumber;

  // Subscription plan
  String plan = 'free'; 
  
  DateTime? createdAt;

  @Index()
  DateTime? lastUpdatedAt;
  
  bool isSynced = false;
  
  String? serverId;

  // Phase 2: Billing & Notifications
  String? billingEmail;
  bool billingEmailVerified = false;
  
  bool notifyBillingUpdates = true; // Plan changes, payments
  bool notifyLimitWarnings = true; // Quota limits
  bool notifyMonthlySummary = true; // Usage summary
}
