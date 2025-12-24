import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/models/daily_report_model.dart';
import '../../../../core/init/providers.dart'; // For isarProvider if needed, but repo handles it
import 'package:flutter/foundation.dart';
import '../../../../features/project/presentation/providers/project_providers.dart';
import '../../../../features/project/data/models/project_model.dart';

part 'report_providers.g.dart';

@riverpod
class ProjectReports extends _$ProjectReports {
  @override
  Future<List<DailyReport>> build(int projectId) async {
    final repository = ref.watch(reportRepositoryProvider);
    
    if (kIsWeb) {
       try {
         final projects = await ref.watch(projectsProvider.future);
         final project = projects.firstWhere((p) => p.id == projectId, orElse: () => Project());
         if (project.serverId != null) {
            return repository.getReportsByProjectUuid(project.serverId!);
         }
       } catch (e) {
         debugPrint('Web Report Fetch Error: $e');
       }
    }

    // Repository already sorts by date desc
    return repository.getReportsByProject(projectId);
  }

  Future<void> createReport(DailyReport report) async {
      final repository = ref.read(reportRepositoryProvider);
      await repository.createReport(report);
      ref.invalidateSelf();
  }
  
  Future<void> deleteReport(int id) async {
      final repository = ref.read(reportRepositoryProvider);
      await repository.deleteReport(id);
      ref.invalidateSelf();
  }
}

// Keep this as manual FutureProvider or convert to functional if preferred. 
// Functional generator:
// @riverpod
// Future<DailyReport?> reportById(ReportByIdRef ref, int id) async {
//   final repository = ref.watch(reportRepositoryProvider);
//   return repository.getReportById(id);
// }
// Keeping it manual to avoid changing call sites (name mismatch) if generator produces 'reportByIdProvider'. 
// Actually generator DOES produce 'reportByIdProvider'. 
// But the manual one is 'final reportByIdProvider = ...'
// Using manual here for simplicity and to match previous file content style if suitable.
// But since I'm using part file, might as well use generator? 
// No, the existing call sites use 'reportByIdProvider(id)'. Generator makes 'reportByIdProvider(id)'.
// Let's stick to valid manual definition to avoid generator complexity if family syntax differs.
final reportByIdProvider = FutureProvider.family<DailyReport?, int>((ref, id) async {
  final repository = ref.watch(reportRepositoryProvider);
  return repository.getReportById(id);
});
