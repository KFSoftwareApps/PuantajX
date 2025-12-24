import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:puantaj_x/features/project/data/models/project_model.dart';
import 'package:puantaj_x/features/project/presentation/providers/project_providers.dart';
import 'package:puantaj_x/features/project/data/repositories/worker_repository.dart';
import 'package:puantaj_x/features/report/data/repositories/report_repository.dart';
import 'package:puantaj_x/features/report/data/models/daily_report_model.dart';
import 'package:puantaj_x/features/attendance/data/repositories/attendance_repository.dart';
import 'package:puantaj_x/features/project/presentation/providers/workers_provider.dart';
import 'dart:async';
import '../../../../core/init/providers.dart';
import '../../../project/data/models/project_worker_model.dart';
import '../../../attendance/data/models/attendance_model.dart';
import 'package:isar/isar.dart';


part 'home_providers.g.dart';

class HomeStats {
  final int activeProjects;
  final int totalWorkers;
  final int dailyReportCount;
  final int dailyAttendanceCount;

  HomeStats({
    required this.activeProjects,
    required this.totalWorkers,
    required this.dailyReportCount,
    required this.dailyAttendanceCount,
  });
}

@riverpod
Stream<HomeStats> homeStats(HomeStatsRef ref) async* {
  final isar = ref.watch(isarProvider).valueOrNull;
  final projects = await ref.watch(projectsProvider.future);
  final workers = await ref.watch(workersProvider.future);
  
  // Helper to calculate stats
  Future<HomeStats> calculate() async {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      
      int reportCount = 0;
      int attendanceCount = 0;

      if (isar != null) {
          for (var p in projects) {
              final hasReport = await isar.dailyReports.filter()
                .projectIdEqualTo(p.id)
                .dateBetween(startOfDay, endOfDay, includeUpper: false)
                .isNotEmpty();
              if (hasReport) reportCount++;

              final attCount = await isar.attendances.filter()
                .projectIdEqualTo(p.id)
                .dateBetween(startOfDay, endOfDay, includeUpper: false)
                .count();
              attendanceCount += attCount;
          }
      } else {
        // Web Fallback: Mock or simplified stats
        // To do real stats we'd need heavy Supabase queries.
        // For MVP Web: return 0 or cached.
        // Assuming we might have some data if we fetched reports via Repo?
        // But here we want cross-project stats.
        // Let's return basics.
      }

      final activeWorkersCount = workers.where((w) => w.active).length;

      return HomeStats(
        activeProjects: projects.length, 
        totalWorkers: activeWorkersCount,
        dailyReportCount: reportCount,
        dailyAttendanceCount: attendanceCount,
      );
  }

  // Initial Yield
  yield await calculate();

  if (isar != null) {
      // Watch for changes only on Mobile
      final portReports = isar.dailyReports.watchLazy();
      final portAttendances = isar.attendances.watchLazy();
      
      final controller = StreamController<void>();
      final sub1 = portReports.listen((_) => controller.add(null));
      final sub2 = portAttendances.listen((_) => controller.add(null));

      ref.onDispose(() {
        sub1.cancel();
        sub2.cancel();
        controller.close();
      });

      await for (final _ in controller.stream) {
        yield await calculate();
      }
  }
}

class ProjectDailySummary {
  final ReportStatus? reportStatus;
  final int attendanceCount;
  final int totalWorkers;

  double get attendancePercentage => totalWorkers > 0 ? (attendanceCount / totalWorkers) : 0.0;

  ProjectDailySummary({this.reportStatus, required this.attendanceCount, required this.totalWorkers});
}

@riverpod
Stream<ProjectDailySummary> dailySummary(DailySummaryRef ref, int projectId) async* {
  final isar = ref.watch(isarProvider).valueOrNull;
  
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  Future<ProjectDailySummary> fetch() async {
    if (isar != null) {
        // Report Status
        final report = await isar.dailyReports
            .filter()
            .projectIdEqualTo(projectId)
            .dateBetween(startOfDay, endOfDay, includeUpper: false)
            .findFirst();

        // Attendance Count
        final attendanceCount = await isar.attendances
            .filter()
            .projectIdEqualTo(projectId)
            .dateBetween(startOfDay, endOfDay, includeUpper: false)
            .count();
        
        // Total Active Workers
        final workerCount = await isar.projectWorkers
            .filter()
            .projectIdEqualTo(projectId)
            .isActiveEqualTo(true)
            .count();

        return ProjectDailySummary(
          reportStatus: report?.status,
          attendanceCount: attendanceCount,
          totalWorkers: workerCount,
        );
    } else {
        // Web Fallback
        // TODO: Implement Supabase fetch if critical
        return ProjectDailySummary(
          reportStatus: null,
          attendanceCount: 0,
          totalWorkers: 0,
        );
    }
  }

  // Initial Yield
  yield await fetch();

  if (isar != null) {
      // Watch for changes
      final port1 = isar.dailyReports.filter().projectIdEqualTo(projectId).watchLazy();
      final port2 = isar.attendances.filter().projectIdEqualTo(projectId).watchLazy();
      final port3 = isar.projectWorkers.filter().projectIdEqualTo(projectId).watchLazy();

      // Merge streams
      final controller = StreamController<void>();
      final sub1 = port1.listen((_) => controller.add(null));
      final sub2 = port2.listen((_) => controller.add(null));
      final sub3 = port3.listen((_) => controller.add(null));

      ref.onDispose(() {
        sub1.cancel();
        sub2.cancel();
        sub3.cancel();
        controller.close();
      });

      await for (final _ in controller.stream) {
        yield await fetch();
      }
  }
}
