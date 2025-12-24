import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/app_providers.dart';
import '../../../../core/authz/permissions.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../data/models/project_model.dart';
import '../../presentation/providers/project_providers.dart';
import '../providers/archive_metrics_provider.dart';
import '../../../report/data/models/daily_report_model.dart';

class ProjectCard extends ConsumerWidget {
  final Project project;
  final VoidCallback? onTap;
  final Function(Project) onDelete;
  final Function(Project) onEdit;

  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjectId = ref.watch(selectedProjectIdProvider);
    final isActive = activeProjectId == project.id;
    final isArchived = project.status == ProjectStatus.archived;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade200,
          width: isActive ? 2 : 1,
        ),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name, Location, Status Chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.indigo.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      project.name.isNotEmpty ? project.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isActive ? Colors.indigo : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                project.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isArchived)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Arşiv',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            else if (isActive)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.indigo,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Aktif',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        if (project.location != null && project.location!.isNotEmpty) ...[
                          const Gap(4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                              const Gap(4),
                              Expanded(
                                child: Text(
                                  project.location!,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Action Menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'delete') onDelete(project);
                      if (value == 'edit') onEdit(project);
                      if (value == 'set_active') ref.read(selectedProjectIdProvider.notifier).set(project.id);
                    },
                    itemBuilder: (context) => [
                      if (!isActive && !isArchived)
                        const PopupMenuItem(
                          value: 'set_active',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.indigo, size: 20),
                              Gap(8),
                              Text('Aktif Proje Yap'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: PermissionGuard(
                          permission: AppPermission.projectUpdate,
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: Colors.black87, size: 20),
                              Gap(8),
                              Text('Düzenle'),
                            ],
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: PermissionGuard(
                          permission: AppPermission.projectUpdate,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              Gap(8),
                              Text('Sil', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              // Metrics: Archive or Daily Summary
              if (isArchived)
                // Archive Metrics
                ref.watch(archiveMetricsProvider(project.id)).when(
                  data: (metrics) => Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.assignment_outlined, size: 16, color: Colors.grey),
                                const Gap(6),
                                Text(
                                  'Toplam ${metrics.totalReports} rapor',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                const Gap(6),
                                Text(
                                  '${metrics.totalAttendanceDays} gün',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (metrics.lastReportDate != null) ...[
                        const Gap(8),
                        Row(
                          children: [
                            const Icon(Icons.event, size: 16, color: Colors.grey),
                            const Gap(6),
                            Text(
                              'Son rapor: ${DateFormat('dd.MM.yyyy').format(metrics.lastReportDate!)}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  loading: () => const Row(children: [Spacer(), SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)), Spacer()]),
                  error: (_, __) => const SizedBox.shrink(),
                )
              else
                // Daily Summary Stats
                ref.watch(dailySummaryProvider(project.id)).when(
                  data: (summary) => Row(
                    children: [
                      // Daily Report Status
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              summary.reportStatus != null ? Icons.assignment_turned_in : Icons.assignment_late_outlined,
                              size: 16,
                              color: summary.reportStatus != null ? Colors.blue : Colors.orange,
                            ),
                            const Gap(6),
                            Text(
                              summary.reportStatus != null ? 'Rapor Girildi' : 'Rapor Yok',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: summary.reportStatus != null ? Colors.blue.shade700 : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Attendance Status
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.group_outlined, size: 16, color: Colors.grey[700]),
                            const Gap(6),
                            Text(
                              'Puantaj: ${summary.attendanceCount}/${summary.totalWorkers}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Row(children: [Spacer(), SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)), Spacer()]),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              
              const Gap(8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   Text(
                     'Son işlem: ${DateFormat('HH:mm').format(DateTime.now())}',
                     style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                   ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
