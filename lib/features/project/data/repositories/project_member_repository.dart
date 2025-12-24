import 'package:isar/isar.dart';
import '../models/project_member_model.dart';

class ProjectMemberRepository {
  final Isar _isar;

  ProjectMemberRepository(this._isar);

  Future<List<ProjectMember>> getProjectMembers(int projectId) async {
    return await _isar.projectMembers
        .filter()
        .projectIdEqualTo(projectId)
        .isActiveEqualTo(true)
        .findAll();
  }

  Future<List<ProjectMember>> getUserProjects(int userId) async {
    return await _isar.projectMembers
        .filter()
        .userIdEqualTo(userId)
        .isActiveEqualTo(true)
        .findAll();
  }

  Future<void> assignUserToProject(int projectId, int userId) async {
    await _isar.writeTxn(() async {
      final member = ProjectMember()
        ..projectId = projectId
        ..userId = userId
        ..assignedAt = DateTime.now();
      await _isar.projectMembers.put(member);
    });
  }

  Future<void> removeUserFromProject(int projectId, int userId) async {
    final member = await _isar.projectMembers
        .filter()
        .projectIdEqualTo(projectId)
        .userIdEqualTo(userId)
        .findFirst();
    
    if (member != null) {
      await _isar.writeTxn(() async {
        member.isActive = false;
        await _isar.projectMembers.put(member);
      });
    }
  }
}
