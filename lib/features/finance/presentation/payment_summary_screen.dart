import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added


import '../../../core/utils/file_download_helper.dart';
import '../../project/data/models/project_worker_model.dart';
import '../../../core/init/providers.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/widgets/permission_guard.dart';
import '../../../core/widgets/entitlement_gate.dart';
import '../../../core/subscription/plan_config.dart';
import '../../attendance/data/models/attendance_model.dart';
import '../../project/data/models/project_model.dart';
import '../../project/data/models/worker_model.dart';
import '../../../core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/share_stub.dart' if (dart.library.io) 'package:share_plus/share_plus.dart';
import '../../project/presentation/providers/project_providers.dart';
import '../../project/presentation/providers/active_project_provider.dart';
import '../../../core/utils/cost_calculator.dart';
import 'widgets/locking_wizard_dialog.dart';
import 'services/payroll_export_service.dart';

// Date Range Provider
final dateRangeProvider = StateProvider<DateRange>((ref) {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return DateRange(start: startOfMonth, end: endOfToday);
});

class DateRange {
  final DateTime start;
  final DateTime end;
  DateRange({required this.start, required this.end});
}

class PaymentSummaryScreen extends ConsumerWidget {
  const PaymentSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjectAsync = ref.watch(activeProjectProvider);
    final dateRange = ref.watch(dateRangeProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: '',
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              final project = activeProjectAsync.valueOrNull;
              if (project == null) return;

              if (value == 'lock') {
                await showDialog(
                  context: context,
                  builder: (context) => LockingWizardDialog(projectId: project.id),
                );
              } else if (value == 'unlock') {
                project.financeLockDate = null;
                await ref.read(projectRepositoryProvider).updateProject(project);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dönem kilidi kaldırıldı.')),
                  );
                }
              }
            },
            itemBuilder: (BuildContext context) {
              final isLocked = activeProjectAsync.valueOrNull?.financeLockDate != null;
              return <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'lock',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.red, size: 20),
                      Gap(12),
                      Text('Ödemeyi Yap ve Kilitle'),
                    ],
                  ),
                ),
                if (isLocked)
                  const PopupMenuItem<String>(
                    value: 'unlock',
                    child: Row(
                      children: [
                        Icon(Icons.lock_open, color: Colors.green, size: 20),
                        Gap(12),
                        Text('Kilidi Aç'),
                      ],
                    ),
                  ),
              ];
            },
          ),
          EntitlementGate(
            requiredEntitlement: Entitlement.pdfNoWatermark,
            fallback: IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'PDF (Filigranlı - Pro ile filigransız)',
              onPressed: () async {
                 await _handlePdfAction(context, ref, activeProjectAsync.valueOrNull, dateRange, true);
              },
            ),
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'PDF (Filigransız)',
              onPressed: () async {
                 await _handlePdfAction(context, ref, activeProjectAsync.valueOrNull, dateRange, false);
              },
            ),
          ),
        ],
      ),
      body: PermissionGuard(
        permission: AppPermission.financeView,
        fallback: const Center(child: Text('Bu ekranı görüntüleme yetkiniz yok.')),
        child: activeProjectAsync.when(
          data: (project) {
            if (project == null) return const Center(child: Text('Proje seçiniz'));
            return _SummaryList(projectId: project.id, dateRange: dateRange);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Hata: $e')),
        ),
      ),
    );
  }

  Future<void> _handlePdfAction(BuildContext context, WidgetRef ref, Project? project, DateRange dateRange, bool watermark) async {
    if (project == null) return;

    final summary = await ref.read(paymentSummaryProvider((project.id, dateRange)).future);
    if (summary.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veri yok')));
      return;
    }

    if (!context.mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             ListTile(
               title: const Text('Rapor Formatı Seçin', style: TextStyle(fontWeight: FontWeight.bold)),
             ),
             const Divider(),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF Paylaş'),
              onTap: () async {
                Navigator.pop(context);
                final bytes = await PayrollExportService.generatePdf(
                  items: summary, 
                  startDate: dateRange.start, 
                  endDate: dateRange.end, 
                  projectName: project.name, 
                  watermark: watermark
                );
                await Printing.sharePdf(bytes: bytes, filename: 'hakedis_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
              },
            ),
             ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.red),
              title: const Text('PDF İndir'),
              onTap: () async {
                Navigator.pop(context);
                final bytes = await PayrollExportService.generatePdf(
                  items: summary, 
                  startDate: dateRange.start, 
                  endDate: dateRange.end, 
                  projectName: project.name, 
                  watermark: watermark
                );
                 if (context.mounted) {
                   await FileDownloadHelper.saveAndNotify(
                     context, 
                     bytes, 
                     'hakedis_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf'
                   );
                 }
              },
            ),
             const Divider(),
             ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Excel Paylaş'),
              onTap: () async {
                Navigator.pop(context);
                final bytes = await PayrollExportService.generateExcel(
                  items: summary, 
                  startDate: dateRange.start, 
                  endDate: dateRange.end, 
                  projectName: project.name
                );
                
                // Share Excel
                if (kIsWeb) {
                   await FileDownloadHelper.saveAndNotify(context, Uint8List.fromList(bytes), 'hakedis.xlsx');
                } else {
                   final tempDir = await getTemporaryDirectory();
                   final file = File('${tempDir.path}/hakedis.xlsx');
                   await file.writeAsBytes(bytes);
                   await Share.shareXFiles([XFile(file.path)], subject: 'Hakediş Raporu');
                }
              },
            ),
             ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.green),
              title: const Text('Excel İndir'),
              onTap: () async {
                Navigator.pop(context);
                final bytes = await PayrollExportService.generateExcel(
                   items: summary, 
                   startDate: dateRange.start, 
                   endDate: dateRange.end, 
                   projectName: project.name
                 );
                 if (context.mounted) {
                   // Note: FileDownloadHelper might expect PDF, but generic bytes work for any extension if named correctly.
                   await FileDownloadHelper.saveAndNotify(
                     context, 
                     Uint8List.fromList(bytes), 
                     'hakedis_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx'
                   );
                 }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryList extends ConsumerWidget {
  final int projectId;
  final DateRange dateRange;

  const _SummaryList({required this.projectId, required this.dateRange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ record param
    final summaryAsync = ref.watch(paymentSummaryProvider((projectId, dateRange)));

    return summaryAsync.when(
      data: (items) {
        if (items.isEmpty) return const Center(child: Text('Veri bulunamadı.'));

        double grandTotal = 0;
        for (var item in items) {
          grandTotal += item.totalAmount;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const Gap(8),
                  Text(
                    '${DateFormat('dd.MM.yyyy').format(dateRange.start)} - ${DateFormat('dd.MM.yyyy').format(dateRange.end)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: InkWell(
                      onTap: () {
                        context.push(
                            '/reports/payment-summary/${item.workerId}?projectId=$projectId');
                      },
                      child: ListTile(
                        title: Text(item.workerName,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${item.daysWorked} Gün çalıştı • ${item.hoursWorked.toStringAsFixed(1)} Saat',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        trailing: PermissionGuard(
                          permission: AppPermission.financeView,
                          fallback: const SizedBox.shrink(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.totalAmount.toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                item.payType == PayType.daily ? 'Günlük' : 'Saatlik',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            PermissionGuard(
              permission: AppPermission.financeView,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOPLAM HAKEDİŞ',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(
                      '${grandTotal.toStringAsFixed(2)} TL',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Hata: $e')),
    );
  }
}

class PaymentSummaryItem {
  final int workerId;
  final String workerName;
  final PayType payType;
  final int daysWorked;
  final double hoursWorked;
  final double totalAmount;

  PaymentSummaryItem({
    required this.workerId,
    required this.workerName,
    required this.payType,
    required this.daysWorked,
    required this.hoursWorked,
    required this.totalAmount,
  });
}

// Provider to fetch and aggregate data
final paymentSummaryProvider =
    FutureProvider.family<List<PaymentSummaryItem>, (int, DateRange)>((ref, args) async {
  final isar = ref.watch(isarProvider).valueOrNull;
  final supabase = ref.watch(supabaseClientProvider);
  final projectId = args.$1;
  final dateRange = args.$2;

  // 1. Fetch Project
  // We use repo to get hybrid support
  final projectRepo = ref.read(projectRepositoryProvider);
  final project = await projectRepo.getProject(projectId);
  if (project == null) return [];

  // 2. Fetch Workers
  final workers = await projectRepo.getProjectWorkers(projectId);
  if (workers.isEmpty) return [];

  // 3. Fetch Attendances (Hybrid)
  List<Attendance> attendances = [];
  if (isar != null) {
      attendances = await (isar as dynamic).attendances
        .filter()
        .projectIdEqualTo(projectId)
        .dateBetween(dateRange.start, dateRange.end)
        .findAll();
  } else {
      // Web Fallback (Supabase)
      if (project.serverId != null) {
         try {
           final data = await supabase
               .from('attendances')
               .select()
               .eq('project_id', project.serverId!) // UUID
               .gte('date', dateRange.start.toIso8601String())
               .lte('date', dateRange.end.toIso8601String());
           
            attendances = (data as List).map((row) {
              final wUuid = row['worker_id'];
              final worker = workers.firstWhere((w) => w.serverId == wUuid, orElse: () => Worker()..id = -1);
              
              return Attendance()
                ..id = -1
                ..remoteId = row['id']
                ..projectId = projectId
                ..workerId = worker.id // Link via resolved integer ID
                ..date = DateTime.parse(row['date'])
                ..hours = (row['hours'] as num).toDouble()
                ..overtimeHours = (row['overtime_hours'] as num? ?? 0).toDouble()
                ..status = AttendanceStatus.values.firstWhere((e) => e.name == row['status'], orElse: () => AttendanceStatus.present)
                ..dayType = DayType.values.firstWhere((e) => e.name == row['day_type'], orElse: () => DayType.normal);
           }).where((a) => a.workerId != -1).toList();

         } catch (e) {
           debugPrint('Supabase Attendance Fetch Error: $e');
         }
      }
  }


  // 4. Calculate
  final summary = <PaymentSummaryItem>[];
  final validWorkers = workers.where((w) => w.active).toList(); // Filter active?

  for (final worker in validWorkers) {
    final workerAttendances =
        attendances.where((a) => a.workerId == worker.id).toList();

    int days = 0;
    double hours = 0;
    double amount = 0;

    for (final att in workerAttendances) {
      if ((att.status == AttendanceStatus.present || att.status == AttendanceStatus.paidLeave) &&
          att.hours > 0) {
        days++;
        hours += att.hours;
      }
      
      amount += CostCalculator.calculateDailyCost(
        worker: worker,
        attendance: att,
        project: project,
      );
    }

    if (days > 0 || hours > 0) {
      summary.add(
        PaymentSummaryItem(
          workerId: worker.id,
          workerName: worker.name,
          payType: worker.payType,
          daysWorked: days,
          hoursWorked: hours,
          totalAmount: amount,
        ),
      );
    }
  }

  return summary;
});
