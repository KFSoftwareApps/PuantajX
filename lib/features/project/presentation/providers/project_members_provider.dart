import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:isar/isar.dart';
import '../../../../core/init/providers.dart';
import '../../data/models/project_member_model.dart';

part 'project_members_provider.g.dart';

@riverpod
class ProjectMembers extends _$ProjectMembers {
  @override
  Future<List<ProjectMember>> build(int projectId) async {
    final isar = ref.watch(isarProvider).valueOrNull;
    if (isar == null) return [];

    return await isar.projectMembers
        .filter()
        .projectIdEqualTo(projectId)
        .isActiveEqualTo(true)
        .findAll();
  }

  Future<void> addMember(int userId, {String? roleOverride}) async {
    final isar = ref.read(isarProvider).valueOrNull;
    if (isar == null) return;

    final projectId = this.projectId;

    // Check if already exists
    final existing = await isar.projectMembers
        .filter()
        .projectIdEqualTo(projectId)
        .userIdEqualTo(userId)
        .findFirst();

    if (existing != null) {
      // Reactivate if inactive
      if (!existing.isActive) {
        await isar.writeTxn(() async {
          existing.isActive = true;
          existing.lastUpdatedAt = DateTime.now();
          if (roleOverride != null) {
            existing.hasRoleOverride = true;
            existing.roleOverrideStr = roleOverride;
          }
          await isar.projectMembers.put(existing);
        });
      } else {
        throw Exception('Bu kullanıcı zaten proje üyesi');
      }
    } else {
      // Create new
      final member = ProjectMember()
        ..projectId = projectId
        ..userId = userId
        ..assignedAt = DateTime.now()
        ..isActive = true
        ..lastUpdatedAt = DateTime.now();

      if (roleOverride != null) {
        member.hasRoleOverride = true;
        member.roleOverrideStr = roleOverride;
      }

      await isar.writeTxn(() async {
        await isar.projectMembers.put(member);
      });
    }

    ref.invalidateSelf();
  }

  Future<void> removeMember(int userId) async {
    final isar = ref.read(isarProvider).valueOrNull;
    if (isar == null) return;

    final projectId = this.projectId;

    final member = await isar.projectMembers
        .filter()
        .projectIdEqualTo(projectId)
        .userIdEqualTo(userId)
        .findFirst();

    if (member != null) {
      await isar.writeTxn(() async {
        member.isActive = false;
        member.lastUpdatedAt = DateTime.now();
        await isar.projectMembers.put(member);
      });
    }

    ref.invalidateSelf();
  }

  Future<void> updateMemberRole(int userId, String role) async {
    final isar = ref.read(isarProvider).valueOrNull;
    if (isar == null) return;

    final projectId = this.projectId;

    final member = await isar.projectMembers
        .filter()
        .projectIdEqualTo(projectId)
        .userIdEqualTo(userId)
        .findFirst();

    if (member != null) {
      await isar.writeTxn(() async {
        member.hasRoleOverride = true;
        member.roleOverrideStr = role;
        member.lastUpdatedAt = DateTime.now();
        await isar.projectMembers.put(member);
      });
    }

    ref.invalidateSelf();
  }
}
