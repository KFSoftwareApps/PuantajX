import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/project/data/models/project_model.dart';
import '../../features/project/data/models/worker_model.dart';
import '../../features/report/data/models/daily_report_model.dart';
import '../../features/attendance/data/models/attendance_model.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/data/models/organization_model.dart';
import '../sync/data/models/outbox_item.dart';
import '../../features/project/data/models/project_worker_model.dart';
import '../../core/subscription/subscription_model.dart';
import '../../features/auth/data/models/security_models.dart';
import '../../features/project/data/models/project_member_model.dart';
import '../../features/report/data/models/share_token_model.dart';
import '../../features/finance/data/models/pay_adjustment_model.dart';

class DatabaseService {
  late Future<Isar?> db;

  DatabaseService() {
    db = _initDb();
  }

  Future<Isar?> _initDb() async {
    if (kIsWeb) {
      debugPrint('Web detected: Skipping Isar initialization (Mock/No-Op Mode)');
      return null;
    }
    if (Isar.instanceNames.isNotEmpty) {
      return Future.value(Isar.getInstance());
    }

    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [
        ProjectSchema,
        WorkerSchema,
        DailyReportSchema,
        AttendanceSchema,
        UserSchema,
        OrganizationSchema,
        OutboxItemSchema,
        ProjectWorkerSchema,
        SubscriptionSchema,
        // Security & Policies
        OrgPolicySchema,
        OrgRoleTemplateSchema,
        MembershipOverrideSchema,
        AuditLogSchema,
        ProjectMemberSchema,
        ShareTokenSchema,
        PayAdjustmentSchema,
      ],
      directory: dir.path,
      inspector: kDebugMode,
    );
    
    return isar;
  }
}
