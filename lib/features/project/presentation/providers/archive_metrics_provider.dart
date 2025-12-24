import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added
import '../../../../core/init/providers.dart';
import '../../../report/data/repositories/report_repository.dart';
import '../../../attendance/data/models/attendance_model.dart';
import 'project_providers.dart'; // contains projectRepositoryProvider
import '../../../report/data/models/daily_report_model.dart'; // DailyReport


part 'archive_metrics_provider.g.dart';

class ArchiveMetrics {
  final int totalReports;
  final DateTime? lastReportDate;
  final int totalAttendanceDays;

  ArchiveMetrics({
    required this.totalReports,
    this.lastReportDate,
    required this.totalAttendanceDays,
  });
}

@riverpod
Future<ArchiveMetrics> archiveMetrics(ArchiveMetricsRef ref, int projectId) async {
  final reportRepo = ref.watch(reportRepositoryProvider);
  final isar = ref.watch(isarProvider).valueOrNull;
  final supabase = ref.watch(supabaseClientProvider);
  
  // Need to get Project to know UUID for Web
  final projectRepo = ref.read(projectRepositoryProvider);
  final project = await projectRepo.getProject(projectId);
  
  List<DailyReport> reports = [];
  int uniqueAttendanceDays = 0;

  DateTime? lastDate;

  if (isar != null) {
      // Isar Flow
      reports = await reportRepo.getReportsByProject(projectId);
      
      final allAttendances = await isar.attendances
          .filter()
          .projectIdEqualTo(projectId)
          .findAll();
      
      final uniqueDates = <String>{};
      for (var attendance in allAttendances) {
        final dateKey = '${attendance.date.year}-${attendance.date.month}-${attendance.date.day}';
        uniqueDates.add(dateKey);
      }
      uniqueAttendanceDays = uniqueDates.length;

  } else {
      // Web Flow
      if (project != null && project.serverId != null) {
          // Reports
          reports = await reportRepo.getReportsByProjectUuid(project.serverId!);
          
          // Attendances (Fetch minimal data: date only)
          try {
             final data = await supabase
                 .from('attendances')
                 .select('date')
                 .eq('project_id', project.serverId!);
             
             final uniqueDates = <String>{};
             for (var row in data as List) {
                 final dt = DateTime.parse(row['date']);
                 final dateKey = '${dt.year}-${dt.month}-${dt.day}';
                 uniqueDates.add(dateKey);
             }
             uniqueAttendanceDays = uniqueDates.length;

          } catch (e) {
             // Fail silently or log
          }
      }
  }

  // Calc last date
  if (reports.isNotEmpty) {
    reports.sort((a, b) => b.date.compareTo(a.date));
    lastDate = reports.first.date;
  }

  return ArchiveMetrics(
    totalReports: reports.length,
    lastReportDate: lastDate,
    totalAttendanceDays: uniqueAttendanceDays,
  );
}
