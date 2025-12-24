import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../project/presentation/providers/project_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../project/presentation/providers/project_providers.dart';
import '../../project/presentation/providers/active_project_provider.dart';
import '../data/models/daily_report_model.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/widgets/permission_guard.dart';
import 'providers/report_providers.dart';
import 'providers/report_filter_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjectAsync = ref.watch(activeProjectProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Günlük Raporlar',
        showProjectChip: true,
      ),
      floatingActionButton: PermissionGuard(
        permission: AppPermission.reportCreate,
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/reports/new'),
          label: const Text('Yeni Rapor'),
          icon: const Icon(Icons.add),
        ),
      ),
      body: activeProjectAsync.when(
        data: (project) {
          if (project == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                  const Gap(16),
                  const Text('Lütfen işlem yapmak için bir proje seçin.'),
                  const Gap(16),
                  ElevatedButton(
                    onPressed: () => context.go('/projects'),
                    child: const Text('Projelere Git'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Active Project Header (Visual Feedback)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.purple.withOpacity(0.15) 
                    : Colors.purple.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 20, color: Colors.purple),
                    const Gap(8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Aktif Proje', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                      ],
                    ),
                  ],
                ),
              ),
              
              const _FilterBar(),
              const Divider(height: 1),

              Expanded(
                child: PermissionGuard(
                  permission: AppPermission.reportRead,
                  fallback: const Center(child: Text('Raporları görüntüleme yetkiniz yok.')),
                  child: _ReportList(projectId: project.id),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.cardColor,
      child: Column(
        children: [
          // Row 1: Search + Date
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Ara (Rapor No, Not...)',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    fillColor: theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                    filled: true,
                    suffixIcon: filter.searchQuery.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => ref.read(reportFilterProvider.notifier).state = filter.copyWith(searchQuery: ''))
                      : null,
                  ),
                  onChanged: (val) {
                    ref.read(reportFilterProvider.notifier).state = filter.copyWith(searchQuery: val);
                  },
                  controller: TextEditingController(text: filter.searchQuery)..selection = TextSelection.fromPosition(TextPosition(offset: filter.searchQuery.length)),
                ),
              ),
              const Gap(8),
              InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context, 
                    firstDate: DateTime(2020), 
                    lastDate: DateTime.now().add(const Duration(days: 1))
                  );
                  if (picked != null) {
                    ref.read(reportFilterProvider.notifier).state = filter.copyWith(dateRange: picked);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: filter.dateRange != null ? theme.primaryColor.withOpacity(0.1) : (theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(8),
                    border: filter.dateRange != null ? Border.all(color: theme.primaryColor) : null,
                  ),
                  child: Icon(Icons.calendar_month, color: filter.dateRange != null ? theme.primaryColor : Colors.grey),
                ),
              ),
            ],
          ),
          
          if (filter.dateRange != null) ...[
            const Gap(8),
            Row(
              children: [
                Chip(
                  label: Text('${DateFormat('dd.MM').format(filter.dateRange!.start)} - ${DateFormat('dd.MM').format(filter.dateRange!.end)}'),
                  onDeleted: () => ref.read(reportFilterProvider.notifier).state = ReportFilterState(searchQuery: filter.searchQuery, selectedStatuses: filter.selectedStatuses),
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  side: BorderSide.none,
                  labelStyle: TextStyle(color: theme.primaryColor, fontSize: 12),
                ),
              ],
            ),
          ],

          const Gap(12),
          // Row 2: Status Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ReportStatus.values.map((status) {
                final isSelected = filter.selectedStatuses?.contains(status) ?? false;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(() {
                      switch (status) {
                        case ReportStatus.draft: return 'TASLAK';
                        case ReportStatus.submitted: return 'ONAY BEKLİYOR';
                        case ReportStatus.approved: return 'ONAYLANDI';
                        case ReportStatus.rejected: return 'REDDEDİLDİ';
                        case ReportStatus.locked: return 'KİLİTLİ';
                      }
                    }()),
                    selected: isSelected,
                    onSelected: (val) {
                       final current = filter.selectedStatuses ?? {};
                       final newSet = Set<ReportStatus>.from(current);
                       if (val) {
                         newSet.add(status);
                       } else {
                         newSet.remove(status);
                       }
                       ref.read(reportFilterProvider.notifier).state = filter.copyWith(selectedStatuses: newSet);
                    },
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(fontSize: 10, color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.bold),
                    selectedColor: _getStatusColor(status),
                    checkmarkColor: Colors.white,
                    backgroundColor: theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none), 
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(ReportStatus status) {
    switch(status) {
      case ReportStatus.draft: return Colors.orange;
      case ReportStatus.submitted: return Colors.blue;
      case ReportStatus.approved: return Colors.green;
      case ReportStatus.rejected: return Colors.red;
      case ReportStatus.locked: return Colors.grey;
    }
  }
}

class _ReportList extends ConsumerWidget {
  final int projectId;
  const _ReportList({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch FILTERED reports logic
    final reports = ref.watch(filteredReportsProvider(projectId));
    final reportsAsync = ref.watch(projectReportsProvider(projectId)); // Just for loading status if needed

    // Define the Payment Summary Card
    final paymentSummaryCard = PermissionGuard(
      permission: AppPermission.workerRateRead,
      fallback: const SizedBox.shrink(),
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.blue.withOpacity(0.15) 
            : Colors.blue.shade50,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.payments, color: Colors.white),
          ),
          title: const Text('Hakediş ve Ödeme Özeti', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          subtitle: const Text('Personel hakedişlerini ve proje maliyetlerini görüntüle'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
          onTap: () => context.push('/reports/payment-summary'),
        ),
      ),
    );
    
    // Check loading state from main provider
    if (reportsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (reports.isEmpty) {
       final hasFilters = ref.watch(reportFilterProvider).hasFilters;
       if (hasFilters) {
         return Center(child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             const Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
             const Gap(16),
             const Text('Filtrelere uygun rapor bulunamadı.'),
             TextButton(onPressed: () => ref.refresh(reportFilterProvider), child: const Text('Filtreleri Temizle')),
           ],
         ));
       }
       
       return Column(
        children: [
          paymentSummaryCard,
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Bu proje için henüz rapor yok.'),
                  PermissionGuard(
                    permission: AppPermission.reportCreate,
                    child: TextButton(
                      onPressed: () => context.push('/reports/new'),
                      child: const Text('İlk Raporu Oluştur'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: reports.length + 1, // +1 for Payment Summary Card at top
      itemBuilder: (context, index) {
        if (index == 0) return paymentSummaryCard;
        final report = reports[index - 1];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: _StatusBadge(status: report.status),
            title: Text(
              DateFormat('dd.MM.yyyy').format(report.date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.generalNote != null && report.generalNote!.isNotEmpty)
                  Text(report.generalNote!, maxLines: 1, overflow: TextOverflow.ellipsis),
                
                const Gap(4),
                _StatusChip(status: report.status),
                const Gap(4),
                // NEW: Status Icons Row
                Row(
                  children: [
                    if ((report.crewCount ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.people, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${report.crewCount}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    
                    if (report.attachments.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.photo_camera, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${report.attachments.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                  ],
                )
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/reports/${report.id}'),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ReportStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (status) {
      case ReportStatus.draft:
        color = Colors.orange;
        icon = Icons.edit_note;
        break;
      case ReportStatus.submitted:
        color = Colors.blue;
        icon = Icons.send;
        break;
      case ReportStatus.approved:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case ReportStatus.rejected:
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case ReportStatus.locked:
        color = Colors.grey;
        icon = Icons.lock;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ReportStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case ReportStatus.draft:
        color = Colors.orange;
        label = 'Taslak';
        break;
      case ReportStatus.submitted:
        color = Colors.blue;
        label = 'Onay Bekliyor';
        break;
      case ReportStatus.approved:
        color = Colors.green;
        label = 'Onaylandı';
        break;
      case ReportStatus.rejected:
        color = Colors.red;
        label = 'Reddedildi';
        break;
      case ReportStatus.locked:
        color = Colors.grey;
        label = 'Kilitli';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
