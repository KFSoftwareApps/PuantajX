import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import '../../../../core/init/providers.dart';
import '../../data/models/project_model.dart';
import '../../data/models/worker_model.dart';
import '../../data/models/project_worker_model.dart';
import 'project_providers.dart';

part 'active_project_provider.g.dart';

@Riverpod(keepAlive: true)
class ActiveProject extends _$ActiveProject {
  @override
  Future<Project?> build() async {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedId = prefs.getInt('activeProjectId');
    
    final projects = await ref.watch(projectsProvider.future);
    
    // Migration Logic Check
    await _checkAndMigrateWorkers(projects);

    if (projects.isEmpty) return null;

    if (savedId != null) {
      try {
        return projects.firstWhere((p) => p.id == savedId);
      } catch (_) {
        // Saved project not found
      }
    }

    // Auto-select if only one
    if (projects.length == 1) {
      final p = projects.first;
      await set(p.id);
      return p;
    }

    return null;
  }

  Future<void> set(int projectId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('activeProjectId', projectId);
    
    // Validation: Ensure project exists
    final projects = await ref.read(projectsProvider.future);
    try {
      final project = projects.firstWhere((p) => p.id == projectId);
      state = AsyncData(project);
    } catch (e) {
      state = const AsyncData(null);
    }
  }

  Future<void> clear() async {
     final prefs = ref.read(sharedPreferencesProvider);
     await prefs.remove('activeProjectId');
     state = const AsyncData(null);
  }

  Future<void> _checkAndMigrateWorkers(List<Project> projects) async {
     final isar = ref.read(isarProvider).valueOrNull;
     if (isar == null) return;
     if (projects.isEmpty) return;

     // Check if migration needed: No ProjectWorkers but we have Workers
     final pwCount = await isar.projectWorkers.count();
     if (pwCount > 0) return; // Already migrated or started fresh

     final workerCount = await isar.workers.count();
     if (workerCount == 0) return; // No workers to migrate

     final workers = await isar.workers.where().findAll();
     
     // Migrate: Assign ALL existing workers to ALL existing projects
     // This ensures no data visibility loss for existing users
     final newLinks = <ProjectWorker>[];
     
     for (final p in projects) {
        for (final w in workers) {
           newLinks.add(ProjectWorker()
             ..projectId = p.id
             ..workerId = w.id
             ..isActive = true
             ..assignedAt = DateTime.now()
           );
        }
     }

     if (newLinks.isNotEmpty) {
       await isar.writeTxn(() async {
         await isar.projectWorkers.putAll(newLinks);
       });
       print('MIGRATION: Assigned ${workers.length} workers to ${projects.length} projects.');
     }
  }
}
