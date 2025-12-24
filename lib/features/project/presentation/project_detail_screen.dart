import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'providers/project_providers.dart';
import '../../home/presentation/providers/home_providers.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/widgets/permission_guard.dart';
import '../data/models/project_model.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final int projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  
  @override
  void initState() {
    super.initState();
    // Set active project immediately when entering the hub
    Future.microtask(() {
      ref.read(selectedProjectIdProvider.notifier).set(widget.projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectByIdProvider(widget.projectId));
    final summaryAsync = ref.watch(dailySummaryProvider(widget.projectId));
    final activeProjectId = ref.watch(selectedProjectIdProvider);
    final isActiveProject = activeProjectId == widget.projectId;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Proje Dashboard', showProjectChip: false),
      body: projectAsync.when(
        data: (project) {
          if (project == null) return const Center(child: Text('Proje bulunamadı'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header / Info Card with Active Switch
                _ProjectHeader(project: project, isActive: isActiveProject),
                
                const Gap(24),

                // Today's Summary with CTAs
                Text('Bugünün Özeti', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Gap(12),
                summaryAsync.when(
                  data: (summary) => _TodaySummaryCard(
                    summary: summary,
                    projectId: widget.projectId,
                  ),
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (e, s) => const SizedBox(),
                ),

                const Gap(24),

                // Daily Checklist
                Text('Bugün Yapılacaklar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Gap(12),
                _DailyChecklistCard(projectId: widget.projectId),
                
                const Gap(24),
                
                // Quick Actions
                Text('Hızlı İşlemler', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Gap(12),
                _QuickActionsGrid(projectId: widget.projectId),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}

class _ProjectHeader extends ConsumerWidget {
  final Project project;
  final bool isActive;

  const _ProjectHeader({required this.project, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isActive ? Colors.indigo : Colors.grey.shade200, width: isActive ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.indigo.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    project.name.isNotEmpty ? project.name[0].toUpperCase() : 'P',
                    style: TextStyle(
                      color: isActive ? Colors.indigo : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const Gap(4),
                      if (project.location != null && project.location!.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const Gap(4),
                            Expanded(
                              child: Text(
                                project.location!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (isActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Aktif Proje',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          Text(
                            'Bu proje şu anda seçili.',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(selectedProjectIdProvider.notifier).set(project.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${project.name} aktif proje olarak ayarlandı')),
                    );
                  },
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Bu Projeyi Aktif Yap'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final ProjectDailySummary summary;
  final int projectId;

  const _TodaySummaryCard({required this.summary, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final hasReport = summary.reportStatus != null;
    final attendanceComplete = summary.attendancePercentage >= 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Report Row
          Row(
            children: [
              Icon(
                hasReport ? Icons.assignment_turned_in : Icons.assignment_late_outlined,
                color: hasReport ? Colors.green : Colors.orange,
                size: 20,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Günlük Rapor',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      hasReport ? 'Girilmiş' : 'Henüz girilmedi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: hasReport ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniCta(
                label: hasReport ? 'Gör' : 'Rapor Gir',
                isPrimary: !hasReport,
                onTap: () => hasReport ? context.go('/reports') : context.push('/reports/new'),
              ),
            ],
          ),
          const Divider(height: 24),
          // Attendance Row
          Row(
            children: [
              Icon(
                attendanceComplete ? Icons.check_circle : Icons.group_outlined,
                color: attendanceComplete ? Colors.green : Colors.blue,
                size: 20,
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Puantaj Durumu',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      '${summary.attendanceCount}/${summary.totalWorkers} tamamlandı',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: attendanceComplete ? Colors.green.shade700 : Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              _MiniCta(
                label: attendanceComplete ? 'Gör' : 'Tamamla',
                isPrimary: !attendanceComplete,
                onTap: () => context.go('/attendance'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyChecklistCard extends ConsumerWidget {
  final int projectId;

  const _DailyChecklistCard({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dailySummaryProvider(projectId));
    
    return summaryAsync.when(
      data: (summary) {
        final isReportDone = summary.reportStatus != null;
        final isAttendanceDone = summary.attendancePercentage >= 1.0;
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChecklistItem(
                isDone: isAttendanceDone,
                label: isAttendanceDone ? 'Puantaj tamamlandı (${summary.attendanceCount}/${summary.totalWorkers})' : 'Puantaj eksik',
                onTap: () => context.go('/attendance'),
                actionLabel: isAttendanceDone ? null : 'Tamamla',
              ),
              const Gap(8),
              _ChecklistItem(
                isDone: isReportDone,
                label: isReportDone ? 'Günlük rapor girildi' : 'Günlük rapor girilmedi',
                onTap: () => isReportDone ? context.go('/reports') : context.push('/reports/new'),
                actionLabel: isReportDone ? null : 'Şimdi Gir',
              ),
              const Gap(12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Son güncelleme: ${DateFormat('HH:mm').format(DateTime.now())}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_,__) => const SizedBox.shrink(),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final bool isDone;
  final String label;
  final VoidCallback onTap;
  final String? actionLabel;

  const _ChecklistItem({required this.isDone, required this.label, required this.onTap, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.warning_amber_rounded,
              color: isDone ? Colors.green : Colors.amber,
              size: 20,
            ),
            const Gap(12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? Colors.grey : Colors.black87,
                ),
              ),
            ),
            if (actionLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).primaryColor),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniCta extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _MiniCta({required this.label, this.isPrimary = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).primaryColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isPrimary ? Colors.white : Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final int projectId;

  const _QuickActionsGrid({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _ActionCard(
          title: 'Puantaj',
          icon: Icons.timer_outlined,
          color: Colors.blue,
          onTap: () => context.go('/attendance'),
        ),
        _ActionCard(
          title: 'Raporlar',
          icon: Icons.assignment_outlined,
          color: Colors.purple,
          onTap: () => context.go('/reports'),
        ),
        PermissionGuard(
          permission: AppPermission.workerRead,
          fallback: _ActionCard(
            title: 'Ekip',
            icon: Icons.group_outlined,
            color: Colors.grey,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu işlem için yetkiniz yok')));
            },
          ),
          child: _ActionCard(
            title: 'Ekip',
            icon: Icons.group_outlined,
            color: Colors.orange,
            onTap: () => context.push('/projects/$projectId/team'),
          ),
        ),
        PermissionGuard(
           permission: AppPermission.projectUpdate,
           fallback: _ActionCard(
             title: 'Proje Ayarları',
             icon: Icons.settings_outlined,
             color: Colors.grey.withOpacity(0.5),
             onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu işlem için yetkiniz yok')));
             },
           ),
           child: _ActionCard(
            title: 'Proje Ayarları',
            icon: Icons.settings_outlined,
            color: Colors.blueGrey,
            onTap: () => context.push('/projects/$projectId/settings'),
          ),
         ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const Gap(8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
