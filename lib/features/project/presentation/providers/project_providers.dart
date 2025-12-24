import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:isar/isar.dart';
import '../../../../core/init/providers.dart';
import '../../../../core/subscription/subscription_providers.dart';
import '../../data/models/project_model.dart';
import '../../data/models/worker_model.dart';
import '../../data/models/project_worker_model.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../data/repositories/worker_repository.dart';
import '../../domain/repositories/i_project_repository.dart';
import '../../../../features/auth/data/repositories/auth_repository.dart';
import '../../../../core/services/sync_service.dart';

part 'project_providers.g.dart';

final projectRepositoryProvider = Provider<IProjectRepository>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  final supabase = ref.watch(supabaseClientProvider);
  // Isar null check removed handled in Repo
  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return ProjectRepository(isar, supabase, subscriptionService);
});

final workerRepositoryProvider = Provider((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  final supabase = ref.watch(supabaseClientProvider);
  // Isar null check removed
  return WorkerRepository(isar, supabase, ref);
});

@riverpod
class Projects extends _$Projects {
  @override
  Future<List<Project>> build() async {
    final authRepo = ref.watch(authRepositoryProvider);
    final user = await authRepo.getCurrentUser();
    if (user == null) return [];

    final repository = ref.watch(projectRepositoryProvider);
    return repository.getProjects(user.currentOrgId);
  }

  Future<void> addProject(String name, String? location) async {
    final repository = ref.read(projectRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);
    final user = await authRepo.getCurrentUser();
    
    final project = Project()
      ..name = name
      ..location = location
      ..status = ProjectStatus.active
      ..orgId = user?.currentOrgId ?? 'local-org' 
      ..createdAt = DateTime.now();

    await repository.createProject(project);
    ref.invalidateSelf();
    ref.read(syncServiceProvider).triggerSync();
  }

  Future<void> updateProject(Project project) async {
    final repository = ref.read(projectRepositoryProvider);
    project.lastUpdatedAt = DateTime.now();
    await repository.updateProject(project);
    ref.invalidateSelf();
    ref.read(syncServiceProvider).triggerSync();
  }

  Future<void> deleteProject(int id) async {
    final repository = ref.read(projectRepositoryProvider);
    await repository.deleteProject(id);
    ref.invalidateSelf();
    ref.read(syncServiceProvider).triggerSync();
  }
}

// Fetch single project by ID for Hub
@riverpod
Future<Project?> projectById(ProjectByIdRef ref, int id) async {
  final projects = await ref.watch(projectsProvider.future);
  try {
    return projects.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
}

// ------ Project Worker Management ------

@riverpod
class ProjectWorkers extends _$ProjectWorkers {
  @override
  Future<List<Worker>> build(int projectId) async {
    final repository = ref.watch(projectRepositoryProvider);
    return repository.getProjectWorkers(projectId);
  }

  Future<void> removeWorker(int workerId) async {
      final repository = ref.read(projectRepositoryProvider);
      await repository.removeWorkerFromProject(this.projectId, workerId);
      
      ref.invalidateSelf();
      ref.invalidate(availableWorkersProvider(projectId));
      ref.read(syncServiceProvider).triggerSync();
  }

  Future<void> assignWorkers(List<int> workerIds) async {
    final repository = ref.read(projectRepositoryProvider);
    await repository.addWorkersToProject(this.projectId, workerIds);

    ref.invalidateSelf();
    ref.invalidate(availableWorkersProvider(projectId));
    ref.read(syncServiceProvider).triggerSync();
  }
  Future<void> assignCrew(int workerId, int? crewId) async {
    final repository = ref.read(projectRepositoryProvider);
    await repository.assignWorkerToCrew(this.projectId, workerId, crewId);

    ref.invalidateSelf();
    ref.invalidate(projectWorkersWithoutCrewProvider(projectId));
    // If oldCrewId tracking needed, specialized logic would be in repo but invalidating specific crew provider 
    // without knowing old crew is hard unless repo returns it. 
    // For now brute force invalidate all crews? Or Repository handles it?
    // Repository logic was just DB update. 
    // To keep UI consistent without heavy Logic transfer: Just invalidate this provider (list of project workers)
    // and maybe we assume lists refresh.
    // Ideally we invalidate basic lists.
    
    ref.read(syncServiceProvider).triggerSync();
  }
}

@riverpod
Future<List<Worker>> availableWorkers(AvailableWorkersRef ref, int projectId) async {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.getAvailableWorkers(projectId);
}

@riverpod
Future<List<Worker>> projectCrewMembers(ProjectCrewMembersRef ref, {required int projectId, required int crewId}) async {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.getProjectCrewMembers(projectId, crewId);
}

@riverpod
Future<List<Worker>> projectWorkersWithoutCrew(ProjectWorkersWithoutCrewRef ref, int projectId) async {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.getProjectWorkersWithoutCrew(projectId);
}
