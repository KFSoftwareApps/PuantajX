import 'package:isar/isar.dart';
import '../subscription/plan_config.dart';

part 'subscription_model.g.dart';

@collection
class Subscription {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String orgId;

  @enumerated
  late SubscriptionPlan plan;

  /// Store where subscription was purchased (apple, google, web, manual)
  late String store;

  /// Subscription status
  @enumerated
  SubscriptionStatus status = SubscriptionStatus.active;

  /// When the subscription expires (null = lifetime/manual)
  DateTime? expiresAt;

  /// When the subscription was created
  late DateTime createdAt;

  /// Last time subscription was verified with store
  DateTime? lastVerifiedAt;

  /// Store-specific transaction/receipt ID
  String? storeTransactionId;

  /// For grace period handling
  DateTime? gracePeriodEndsAt;
}

enum SubscriptionStatus {
  active,
  expired,
  cancelled,
  gracePeriod,
  suspended,
}
