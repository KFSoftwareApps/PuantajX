import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puantaj_x/features/project/presentation/providers/project_providers.dart';
import 'package:puantaj_x/features/project/data/repositories/worker_repository.dart';
import 'package:puantaj_x/features/report/data/repositories/report_repository.dart';
import 'package:puantaj_x/features/auth/data/repositories/auth_repository.dart';


class DashboardStats {
  final int activeProjects;
  final int totalWorkers;
  final int totalReports;

  DashboardStats({
    required this.activeProjects,
    required this.totalWorkers,
    required this.totalReports,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  // Watch providers to rebuild if underlying data changes? 
  // Ideally, repositories should emit streams or we invalidate this provider manually.
  // For now, we'll just read repositories directly for a snapshot or watch list providers if available.
  
  // Active Projects
  final projects = await ref.watch(projectsProvider.future);
  final activeProjectsCount = projects.length; // Assuming all returned are "active" for now

  final user = await ref.watch(authControllerProvider.future);
  final orgId = user?.currentOrgId ?? 'DEFAULT';

  // Workers (Total across all projects/org)
  final workerRepo = ref.watch(workerRepositoryProvider);
  final workers = await workerRepo.getByOrg(orgId);
  final totalWorkersCount = workers.length;

  // Reports (Total reports maybe?) - This might be heavy if we fetch all.
  // Ideally we want count. Isar has count() operations. 
  // But our repos currently return Lists. MVP shortcut: just fetching list for now (optimize later).
  // Or better, let's create a specific count method in repos later.
  // For MVP, we likely have few reports.
  final reportRepo = ref.watch(reportRepositoryProvider);
  // We don't have a "getAllReports" in repo yet, only by project.
  // Let's iterate projects and sum up? Or just show "0" for now until we improve repo.
  // Or fetch for the first project if exists.
  int totalReportsCount = 0;
  if (projects.isNotEmpty) {
      // Just sampling first project for MVP stats or implementing a proper `countAll` later
      // Let's keep it simple: 0 because fetching all is inefficient here without repo support.
      // We will leave it as 0 or implement 'count' in Repo strictly.
      // Actually, let's try to get Isar instance and do a count if possible, but we don't have direct Isar access here easily without exposing it.
      // Let's skip report count aggregation for this step to keep it clean.
  }

  return DashboardStats(
    activeProjects: activeProjectsCount,
    totalWorkers: totalWorkersCount,
    totalReports: totalReportsCount,
  );
});
