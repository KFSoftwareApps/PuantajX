import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/providers/missing_providers.dart';
import '../../../core/widgets/custom_app_bar.dart';
import 'providers/home_providers.dart';
import '../../project/presentation/providers/project_providers.dart';
import 'package:intl/intl.dart';
import '../../project/data/models/project_model.dart';
import '../../report/data/models/daily_report_model.dart';
import '../../project/presentation/widgets/project_selector_chip.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final statsAsync = ref.watch(homeStatsProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final selectedProjectId = ref.watch(selectedProjectIdProvider);

    // Auto-select if only 1 project exists and none selected
    if (selectedProjectId == null && projects.length == 1) {
      Future.microtask(() => ref.read(selectedProjectIdProvider.notifier).set(projects.first.id));
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Hoşgeldin, ${user?.fullName ?? "Misafir"} 👋',
        showProjectChip: false, 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            _SummaryCard(
              selectedProject: (selectedProjectId != null && projects.isNotEmpty)
                  ? projects.firstWhere(
                      (p) => p.id == selectedProjectId,
                      orElse: () => projects.first,
                    )
                  : (projects.isNotEmpty ? projects.first : null),
              projects: projects,
              onProjectSelected: (id) => ref.read(selectedProjectIdProvider.notifier).set(id),
            ),
            const Gap(24),

            if (selectedProjectId != null)
               _DailyChecklist(projectId: selectedProjectId),

            const Gap(24),

            // KPI Section
            statsAsync.when(
              data: (stats) => Row(
                children: [
                   Expanded(
                    child: _StatCard(
                      value: '${stats.dailyReportCount} / ${stats.activeProjects}',
                      label: 'Bugün Rapor',
                      icon: Icons.assignment,
                      color: Colors.blue,
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: _StatCard(
                      value: '${stats.dailyAttendanceCount} / ${stats.totalWorkers}',
                      label: 'Bugün Puantaj',
                      icon: Icons.group,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Veri yüklenemedi: $e'),
            ),
            
            const Gap(32),
            
            // Quick Actions
            Text(
              'Hızlı İşlemler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Gap(16),
            Row(
              children: [
                _QuickActionButton(
                  label: 'Yeni Rapor',
                  icon: Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.primary, 
                  backgroundColor: Theme.of(context).colorScheme.surface, 
                  onTap: () => context.go('/reports/new'),
                ),
                const Gap(8),
                _QuickActionButton(
                  label: 'Puantaj',
                  icon: Icons.access_time,
                  color: Colors.orange.shade700,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onTap: () => context.go('/attendance'),
                ),
                const Gap(8),
                _QuickActionButton(
                  label: 'Ekip',
                  icon: Icons.people_outline,
                  color: Colors.blueGrey,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  onTap: () {
                    final projectId = ref.read(selectedProjectIdProvider);
                    if (projectId != null) {
                      context.go('/projects/$projectId/team');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lütfen önce bir proje seçiniz')),
                      );
                    }
                  }, 
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, // Use Theme Card Color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor), // Use Theme Divider
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const Gap(16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? backgroundColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Corporate Look: Neutral background (or white/surface), colored icon
    final bg = backgroundColor ?? Colors.grey.shade50;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
             Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: bg,
                 borderRadius: BorderRadius.circular(16),
                 border: Border.all(color: Colors.grey.shade200), // Subtle border
               ),
               alignment: Alignment.center,
               child: Icon(icon, color: color, size: 28),
             ),
             const Gap(8),
             Text(
               label,
               textAlign: TextAlign.center,
               style: const TextStyle(
                 fontSize: 12,
                 fontWeight: FontWeight.w500,
                 color: Colors.black87,
               ),
             ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  final Project? selectedProject;
  final List<Project> projects;
  final Function(int) onProjectSelected;

  const _SummaryCard({
    this.selectedProject,
    required this.projects,
    required this.onProjectSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedProject == null && projects.isEmpty) return _buildEmptyState(context, projects, ref);

    final summaryAsync = selectedProject != null 
        ? ref.watch(dailySummaryProvider(selectedProject!.id))
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title & Selector
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Bugünün Özeti',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleMedium?.color
                    ),
                  ),
                  const Gap(8),
                   if (projects.isNotEmpty)
                    Transform.scale(
                      scale: 0.85, // Sıkışıklığı gidermek için biraz küçültüldü
                      child: ProjectSelectorChip(
                        selectedProject: selectedProject,
                        projects: projects,
                        onSelected: onProjectSelected,
                      ),
                    ),
                ],
              ),
              
              // Tarih bilgisini biraz küçültüp sağa yasladık
              Text(
                DateFormat('dd.MM.yyyy').format(DateTime.now()), 
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Gap(16),
          
          if (summaryAsync != null)
            summaryAsync.when(
              data: (summary) => Column(
                children: [
                  _StatusRow(
                     label: 'Günlük Rapor', 
                     child: _buildReportStatus(summary.reportStatus, context),
                     onTap: () {
                        if (summary.reportStatus == null || summary.reportStatus == ReportStatus.draft) {
                          context.push('/reports/new');
                        } else {
                          context.go('/reports'); 
                        }
                     },
                     cta: (summary.reportStatus == null) 
                        ? _MiniCta(label: 'Rapor Gir', onTap: () => context.push('/reports/new'), isPrimary: true)
                        : _MiniCta(label: 'Gör', onTap: () => context.go('/reports'), isPrimary: false), // Outline for "See"
                  ),
                  const Divider(height: 24),
                  _StatusRow(
                     label: 'Puantaj Durumu', 
                     child: _buildAttendanceStatus(summary),
                     onTap: () => context.go('/attendance'),
                     cta: (summary.attendancePercentage < 1.0)
                        ? _MiniCta(label: 'Tamamla', onTap: () => context.go('/attendance'), isPrimary: false) // Outline for "Complete"
                        : null,
                  ),
                ],
              ),
              loading: () => Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, s) => Text('Veri yüklenemedi: $e', style: const TextStyle(color: Colors.red)),
            )
          else
             Container(
               padding: const EdgeInsets.symmetric(vertical: 24),
               alignment: Alignment.center,
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.touch_app_outlined, size: 32, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                   const Gap(8),
                   Text(
                     'Lütfen üstten bir proje seçiniz',
                     style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                   ),
                 ],
               ),
             ),
        ],
      ),
    );
  }

  Widget _buildReportStatus(ReportStatus? status, BuildContext context) {
     if (status == null) {
       return const Text('Girilmedi', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
     }
     Color color;
     String text;
     IconData icon;
     switch(status) {
       case ReportStatus.draft: color=Colors.orange; text='Taslak'; icon=Icons.edit; break;
       case ReportStatus.submitted: color=Colors.blue; text='Gönderildi'; icon=Icons.send; break;
       case ReportStatus.approved: color=Colors.green; text='Onaylandı'; icon=Icons.check_circle; break;
       case ReportStatus.rejected: color=Colors.red; text='Reddedildi'; icon=Icons.cancel; break;
       case ReportStatus.locked: color=Colors.red; text='Kilitli'; icon=Icons.lock; break;
     }
     return Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Icon(icon, size: 16, color: color),
         const Gap(4),
         Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
       ],
     );
  }

  Widget _buildAttendanceStatus(ProjectDailySummary summary) {
     final pct = (summary.attendancePercentage * 100).toInt();
     final countText = '${summary.attendanceCount}/${summary.totalWorkers} tamamlandı';
     
     return Text(
        summary.attendancePercentage == 0 ? countText : '$countText (%$pct)',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade900, fontSize: 13) // Slightly larger
     );
  }

  Widget _buildEmptyState(BuildContext context, List<Project> projects, WidgetRef ref) {
    if (projects.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Henüz proje oluşturmadınız.',
            style: TextStyle(fontSize: 14),
          ),
          const Gap(8),
          ElevatedButton.icon(
            onPressed: () => context.go('/projects'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('İlk Projenizi Oluşturun'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İşlem yapmak için bir proje seçiniz:',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        const Gap(12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showProjectSelector(context, projects, ref),
            icon: const Icon(Icons.business),
            label: const Text('Proje Seç'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo,
              elevation: 1,
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Colors.indigo),
            ),
          ),
        ),
      ],
    );
  }

  void _showProjectSelector(BuildContext context, List<Project> projects, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               const Padding(
                 padding: EdgeInsets.all(16.0),
                 child: Text('Proje Seç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
               ),
               const Divider(height: 1),
               Flexible(
                 child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final p = projects[index];
                    return ListTile(
                      leading: const Icon(Icons.business, color: Colors.indigo),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(p.location ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        ref.read(selectedProjectIdProvider.notifier).set(p.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                 ),
               ),
               const Gap(16),
             ],
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback onTap;
  final Widget? cta;

  const _StatusRow({required this.label, required this.child, required this.onTap, this.cta});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.w500)),
            Row(
              children: [
                child,
                if (cta != null) ...[
                  const Gap(8),
                  cta!,
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _MiniCta({required this.label, required this.onTap, this.isPrimary = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: isPrimary 
      ? ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          child: Text(label),
        )
      : OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            side: BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
          child: Text(label),
        ),
    );
  }
}

class _DailyChecklist extends ConsumerStatefulWidget {
  final int projectId;
  const _DailyChecklist({required this.projectId});

  @override
  ConsumerState<_DailyChecklist> createState() => _DailyChecklistState();
}

class _DailyChecklistState extends ConsumerState<_DailyChecklist> {
  bool _hideCompleted = false;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dailySummaryProvider(widget.projectId));
    
    return summaryAsync.when(
      data: (summary) {
        final isReportDone = summary.reportStatus != null;
        final isAttendanceDone = summary.attendancePercentage >= 1.0;
        
        final allItems = [
          _ChecklistItemModel(
            isDone: isAttendanceDone,
            text: isAttendanceDone ? 'Puantaj tamamlandı (${summary.attendanceCount}/${summary.totalWorkers})' : 'Puantaj eksik',
            actionLabel: isAttendanceDone ? null : 'Tamamla',
            onTap: () => context.go('/attendance'),
          ),
          _ChecklistItemModel(
            isDone: isReportDone,
            text: isReportDone ? 'Günlük rapor girildi' : 'Günlük rapor girilmedi',
            actionLabel: isReportDone ? null : 'Şimdi Gir',
            onTap: () => isReportDone ? context.go('/reports') : context.push('/reports/new'),
          ),
        ];

        final visibleItems = _hideCompleted 
            ? allItems.where((item) => !item.isDone).toList() 
            : allItems;

        if (_hideCompleted && visibleItems.isEmpty) {
           // All done and hidden state
          return Container(
             margin: const EdgeInsets.only(top: 16),
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
             decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
             ),
             child: Row(
               children: [
                 const Icon(Icons.check_circle, color: Colors.green, size: 20),
                 const Gap(8),
                 const Expanded(child: Text("Tüm görevler tamamlandı! 🎉", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                 TextButton(
                   onPressed: () => setState(() => _hideCompleted = false),
                   child: const Text('Göster', style: TextStyle(fontSize: 12)),
                 ),
               ],
             ),
           );
        }
        
        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text('Bugün Yapılacaklar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                   InkWell(
                     onTap: () => setState(() => _hideCompleted = !_hideCompleted),
                     borderRadius: BorderRadius.circular(4),
                     child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                       child: Text(
                         _hideCompleted ? 'Tümünü Göster' : 'Tamamlananları Gizle',
                         style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                       ),
                     ),
                   ),
                ],
              ),
              const Gap(12),
              
              if (visibleItems.isEmpty) ...[
                 const Padding(
                   padding: EdgeInsets.symmetric(vertical: 8),
                   child: Text("Yapılacak iş kalmadı.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                 ),
              ] else ...[
                ...visibleItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _ChecklistItem(
                    isDone: item.isDone,
                    label: item.text,
                    onTap: item.onTap,
                    actionLabel: item.actionLabel,
                  ),
                )),
              ],

              const Gap(4),
              // Last Updated
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

class _ChecklistItemModel {
  final bool isDone;
  final String text;
  final String? actionLabel;
  final VoidCallback onTap;

  _ChecklistItemModel({required this.isDone, required this.text, this.actionLabel, required this.onTap});
}

class _ChecklistItem extends StatelessWidget {
  final bool isDone;
  final String label;
  final VoidCallback onTap;
  final String? actionLabel;

  const _ChecklistItem({
    required this.isDone,
    required this.label,
    required this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding( // Padding for click area
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle : Icons.warning_amber_rounded, // Amber alert icon
              color: isDone ? Colors.green : Colors.amber.shade700,
              size: 20,
            ),
            const Gap(8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDone ? Colors.grey[700] : Colors.black87,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  fontSize: 13,
                ),
              ),
            ),
            if (actionLabel != null)
              Container( // Pill shape for action
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).primaryColor),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 11
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
