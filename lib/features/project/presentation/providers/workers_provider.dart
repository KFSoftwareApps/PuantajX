import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart' hide Worker; // Hide Worker from Isar if conflicting, but here we likely need it or not? Actually let's just standard import

import '../../../../core/init/providers.dart';
import '../../../../core/types/app_types.dart';
import '../../data/models/worker_model.dart';
import 'active_project_provider.dart';
import 'project_members_provider.dart';
import 'project_providers.dart'; // Contains workerRepositoryProvider
import '../../../auth/data/repositories/auth_repository.dart'; // May contain authRepositoryProvider if defined there, or providers.dart
// authRepositoryProvider is usually in core/init/providers.dart but let's check where it is.
// Based on previous logs, it might be in `lib/core/init/providers.dart`.
// `project_providers.dart` likely has `workerRepositoryProvider`.

final workersProvider =
    AsyncNotifierProvider.autoDispose<WorkersController, List<Worker>>(
  WorkersController.new,
);

class WorkersController extends AutoDisposeAsyncNotifier<List<Worker>> {
  
  @override
  Future<List<Worker>> build() async {
    // Rely on Repository which handles Hybrid logic
    final repository = ref.watch(workerRepositoryProvider);
    // We assume the user has a current org. Ideally we fetch from user provider.
    // For now, let's fetch all (Repo likely needs method "getAll" or we filter by User's Org)
    // The previous code fetched ALL workers from Isar.
    // Repository method `getByOrg` matches this intent if we pass the orgId.
    
    // Hack: Fetch user's org to pass to repo
    // Or just fetch all local if Isar, but on Supabase we must filter by Org.
    
    // For now, let's stick to the Repo's 'getByOrg' if we can find the org.
    // Use a placeholder or fetch from UserProvider if available.
    // If running on Web without Auth, it's problematic.
    // But we are likely auth'ed.
    
    // Let's defer to a simple "get all local" equivalent in Repo if exists, or use `getByOrg`.
    // Since previous code didn't filter by Org explicitly (it did `workers.where().findAll()`), 
    // it returned everything.
    
    // Let's use `getByOrg('DEFAULT')` or obtain real Org.
    // Better: Update this controller to use the Repository which we just fixed.
    
    // Note: The previous code had `orgId = 'local-org'` default in `addWorker`.
    // We should maintain that behavior or improve it.
    
    // Let's try to find the current user's org from Auth Repo? 
    // Or just use a provider?
    
    // SIMPLIFICATION:
    // Just wrap the implementation here with null checks to compile first, 
    // OR delegate to `workerRepositoryProvider`.
    // Delegating is better architecture.
    
    // But `WorkerRepository` requires `orgId` for `getByOrg`.
    // The previous implementation was `_isar.workers.where().findAll()`.
    
    // To minimize risk, I will implement Hybrid logic directly here similar to Repository 
    // BUT correctly using the `workerRepositoryProvider` is much safer for consistency.
    
    // Let's use `workerRepositoryProvider.getByOrg(currentOrgId)`.
    // But where do we get `currentOrgId`?
    // From `ref.watch(authRepositoryProvider).getCurrentUser()?.currentOrgId`?
    // That returns a Future.
    
    // Let's modify build to await user?
    final authRepo = ref.watch(authRepositoryProvider);
    final user = await authRepo.getCurrentUser();
    final orgId = user?.currentOrgId ?? 'DEFAULT';
    
    return ref.watch(workerRepositoryProvider).getByOrg(orgId);
  }

  Future<void> addWorker({
    required String name,
    String? trade,
    String currency = 'TRY',
    PayType payType = PayType.daily,
    double? dailyRate,
    double? hourlyRate,
    double? monthlyRate,
    double? overtimeRate,
    double? holidayRate,
    String type = 'worker', // worker / crew
    String? description,
    bool active = true,
    String orgId = 'local-org', 
  }) async {
    final worker = Worker()
      ..orgId = orgId
      ..name = name
      ..trade = trade
      ..currency = currency
      ..payType = payType
      ..dailyRate = dailyRate
      ..hourlyRate = hourlyRate
      ..monthlyRate = monthlyRate
      ..overtimeRate = overtimeRate
      ..holidayRate = holidayRate
      ..type = type
      ..description = description
      ..active = active
      ..createdAt = DateTime.now()
      ..lastUpdatedAt = DateTime.now();

    await ref.read(workerRepositoryProvider).createWorker(worker);

    // 2. Auto-Assign to Active Project (if any)
    final activeProject = ref.read(activeProjectProvider).valueOrNull;
    if (activeProject != null) {
       try {
         await ref.read(projectMembersProvider(activeProject.id).notifier).addMember(worker.id);
       } catch (e) {
       }
    }

    ref.invalidateSelf(); // Refresh list
  }

  Future<void> deleteWorker(int id) async {
    await ref.read(workerRepositoryProvider).deleteWorker(id);
    ref.invalidateSelf();
  }

  Future<void> toggleStatus(Worker worker) async {
    worker
      ..active = !worker.active
      ..lastUpdatedAt = DateTime.now();

    await ref.read(workerRepositoryProvider).updateWorker(worker);
    ref.invalidateSelf();
  }
}
