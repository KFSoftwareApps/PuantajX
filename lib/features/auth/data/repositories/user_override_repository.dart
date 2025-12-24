import 'package:isar/isar.dart';
import '../models/security_models.dart';
import '../../../../core/types/app_types.dart';

class UserOverrideRepository {
  final Isar _isar;

  UserOverrideRepository(this._isar);

  Future<MembershipOverride?> getOverrideForUser(String userId) async {
    return await _isar.membershipOverrides
        .filter()
        .memberIdEqualTo(userId)
        .findFirst();
  }

  Future<void> updateOverride(MembershipOverride override) async {
    await _isar.writeTxn(() async {
      await _isar.membershipOverrides.put(override);
    });
  }

  Future<void> setOverride(String userId, {required List<AppPermission> grant, required List<AppPermission> deny}) async {
    final existing = await getOverrideForUser(userId);
    final override = existing ?? MembershipOverride()
      ..memberId = userId;
    
    override.grantPermissions = grant;
    override.denyPermissions = deny;
    override.updatedAt = DateTime.now();
    
    await _isar.writeTxn(() async {
      await _isar.membershipOverrides.put(override);
    });
  }

  Future<void> deleteOverride(String userId) async {
    final override = await getOverrideForUser(userId);
    if (override != null) {
      await _isar.writeTxn(() async {
        await _isar.membershipOverrides.delete(override.id);
      });
    }
  }
}
