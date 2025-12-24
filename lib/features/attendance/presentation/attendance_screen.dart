import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/csv_export_service.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/permission_guard.dart';
import '../../../core/authz/permissions.dart';
import '../data/repositories/attendance_repository.dart';

import '../../auth/data/repositories/auth_repository.dart'; // ✅ permissionsProvider burada
import '../../project/presentation/providers/project_providers.dart';
import '../../project/presentation/providers/active_project_provider.dart';
import '../data/models/attendance_model.dart';
import '../../../core/utils/cost_calculator.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjectAsync = ref.watch(activeProjectProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? []; // Added

    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Puantaj'),
        actions: [
          PermissionGuard(
            permission: AppPermission.timesheetExport,
            child: IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'CSV İndir',
              onPressed: () async {
                final project = activeProjectAsync.valueOrNull;
                if (project == null) return;

                final date = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                final attendanceList = await ref.read(dailyAttendanceProvider(project.id, date).future);

                if (attendanceList.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dışa aktarılacak veri yok')),
                    );
                  }
                  return;
                }

                await CsvExportService().exportAttendanceToCsv(context, attendanceList, project.name);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                ref.read(selectedDateProvider.notifier).state = date;
              }
            },
          ),
        ],
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

          final isLocked = project.financeLockDate != null &&
              selectedDate.isBefore(project.financeLockDate!.add(const Duration(days: 1)));

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isLocked ? Colors.red.shade50 : Colors.blue.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showProjectSelector(context, ref, projects),
                        child: Row(
                          children: [
                            Icon(
                              isLocked ? Icons.lock : Icons.business,
                              size: 20,
                              color: isLocked ? Colors.red : Colors.blue,
                            ),
                            const Gap(8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isLocked ? 'Kilitli Dönem' : 'Aktif Proje',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      project.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isLocked ? Colors.red : Colors.blue,
                                      ),
                                    ),
                                    if (!isLocked) ...[
                                      const Gap(4),
                                      const Icon(Icons.arrow_drop_down, color: Colors.blue, size: 20),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('dd.MM.yyyy').format(selectedDate),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PermissionGuard(
                  permission: AppPermission.timesheetRead,
                  fallback: const Center(child: Text('Puantaj görüntüleme yetkiniz yok.')),
                  child: _AttendanceList(
                    projectId: project.id,
                    date: selectedDate,
                    isLocked: isLocked,
                  ),
                ),
              ),
              _AttendanceFooter(projectId: project.id, date: selectedDate),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }
  void _showProjectSelector(BuildContext context, WidgetRef ref, List<dynamic> projects) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final p = projects[index];
            return ListTile(
              leading: const Icon(Icons.business),
              title: Text(p.name),
              subtitle: Text(p.location ?? ''),
              onTap: () {
                ref.read(activeProjectProvider.notifier).set(p.id);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}

class _AttendanceList extends ConsumerWidget {
  final int projectId;
  final DateTime date;
  final bool isLocked;

  const _AttendanceList({
    required this.projectId,
    required this.date,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjectAsync = ref.watch(activeProjectProvider); // ✅ burada
    final workersAsync = ref.watch(projectWorkersProvider(projectId));
    final queryDate = DateTime(date.year, date.month, date.day);
    final attendanceAsync = ref.watch(dailyAttendanceProvider(projectId, queryDate));

    return workersAsync.when(
      data: (allWorkers) {
        // Filter out crews from attendance list per user request
        final workers = allWorkers.where((w) => w.type != 'crew').toList();

        if (workers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bu projeye atanmış çalışan yok.'),
                TextButton(
                  onPressed: () => context.push('/projects/$projectId/team'),
                  child: const Text('Ekip Yönetimine Git'),
                ),
              ],
            ),
          );
        }

        return attendanceAsync.when(
          data: (attendances) {
            final attendanceMap = {for (var a in attendances) a.workerId: a};

            return ListView.builder(
              itemCount: workers.length,
              itemBuilder: (context, index) {
                final worker = workers[index];

                final attendance = attendanceMap[worker.id] ??
                    (Attendance()
                      ..projectId = projectId
                      ..workerId = worker.id
                      ..date = queryDate
                      ..hours = 0
                      ..status = AttendanceStatus.absent);

                final isPresent = attendance.status == AttendanceStatus.present;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : null, // Slate 700 in Dark Mode
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final canEdit = ref.read(permissionsProvider).hasPermission(AppPermission.timesheetEdit);

                      if (!isLocked && canEdit) {
                        _showAttendanceBottomSheet(context, ref, attendance, worker, projectId, queryDate);
                      } else if (isLocked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bu dönem kilitli. Değişiklik yapılamaz.')),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          PermissionGuard(
                            permission: AppPermission.timesheetEdit,
                            fallback: _StatusBadge(status: attendance.status),
                            child: InkWell(
                              onTap: () {
                                if (isLocked) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Bu dönem kilitli.')),
                                  );
                                  return;
                                }

                                if (attendance.status == AttendanceStatus.present) {
                                  attendance.status = AttendanceStatus.absent;
                                  attendance.hours = 0;
                                } else {
                                  attendance.status = AttendanceStatus.present;
                                  attendance.hours = 8;
                                }

                                ref
                                    .read(dailyAttendanceProvider(projectId, queryDate).notifier)
                                    .updateAttendance(attendance);
                              },
                              child: _StatusBadge(status: attendance.status, isInteractive: !isLocked),
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(worker.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(worker.trade ?? 'Çalışan',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                if (isPresent) ...[
                                  Text(
                                    '${attendance.hours} Saat ${attendance.overtimeHours > 0 ? '+ ${attendance.overtimeHours} Mesai' : ''} ${attendance.dayType != DayType.normal ? '(${attendance.dayType.name})' : ''}',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                  PermissionGuard(
                                    permission: AppPermission.financeView,
                                    child: Builder(
                                      builder: (context) {
                                        final project = activeProjectAsync.valueOrNull;
                                        if (project == null) return const SizedBox.shrink();

                                        final cost = CostCalculator.calculateDailyCost(
                                          worker: worker,
                                          attendance: attendance,
                                          project: project,
                                        );
                                        
                                        if (cost > 0) {
                                          return Text(
                                            'Tutar: ${cost.toStringAsFixed(2)} ${worker.currency}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }
                                        return const Text(
                                          'Ücret Eksik',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ] else
                                  Text('Gelmedi', style: TextStyle(color: Colors.red[300], fontSize: 13)),
                              ],
                            ),
                          ),
                          PermissionGuard(
                            permission: AppPermission.timesheetEdit,
                            fallback: const SizedBox.shrink(),
                            child: Icon(Icons.edit_outlined, color: Colors.grey[400], size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Hata: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Çalışan listesi hatası: $e')),
    );
  }

  double _calculateDailyCost(dynamic worker, Attendance attendance, dynamic project) {
    if (project == null) return 0;

    return CostCalculator.calculateDailyCost(
      worker: worker,
      attendance: attendance,
      project: project,
    );
    /*
    // Check for specific rates
    final double? specificOvertimeRate = worker.overtimeRate;
    final double? specificHolidayRate = worker.holidayRate;
    final bool isSpecialDay = attendance.dayType == DayType.weekend || attendance.dayType == DayType.holiday;

    // Multipliers (fallback)
    double dayMult = 1.0;
    if (attendance.dayType == DayType.weekend) dayMult = project.weekendMultiplier;
    if (attendance.dayType == DayType.holiday) dayMult = project.holidayMultiplier;

    final overtimeMult = project.overtimeMultiplier;

    double normalCost = 0;
    double overtimeCost = 0;

    if (worker.payType == PayType.daily) {
      final dailyRate = worker.dailyRate ?? 0;
      
      // Normal Cost
      if (isSpecialDay && specificHolidayRate != null) {
        normalCost = specificHolidayRate;
      } else {
        normalCost = dailyRate * dayMult;
      }
      
      // Overtime Cost
      if (attendance.overtimeHours > 0) {
        if (specificOvertimeRate != null) {
           overtimeCost = attendance.overtimeHours * specificOvertimeRate;
        } else {
           overtimeCost = attendance.overtimeHours * (dailyRate / 9) * overtimeMult;
        }
      }
      
    } else if (worker.payType == PayType.monthly) {
       // Monthly -> Hourly conversion
       final monthlySalary = worker.monthlyRate ?? 0;
       final hoursPerDay = project.hoursPerDay;
       final monthlyWorkDays = project.monthlyWorkDays;
       
       final divisor = monthlyWorkDays * hoursPerDay;
       final hourlyRate = divisor > 0 ? (monthlySalary / divisor) : 0.0;

       // Normal Cost
       if (isSpecialDay && specificHolidayRate != null) {
         normalCost = attendance.hours * specificHolidayRate;
       } else {
         normalCost = attendance.hours * hourlyRate * dayMult;
       }
       
       // Overtime Cost
       if (attendance.overtimeHours > 0) {
        if (specificOvertimeRate != null) {
           overtimeCost = attendance.overtimeHours * specificOvertimeRate;
        } else {
           overtimeCost = attendance.overtimeHours * hourlyRate * overtimeMult;
        }
      }

    } else {
      // Hourly
      final hourlyRate = worker.hourlyRate ?? 0;
      
      // Normal Cost
      if (isSpecialDay && specificHolidayRate != null) {
        normalCost = attendance.hours * specificHolidayRate;
      } else {
        normalCost = attendance.hours * hourlyRate * dayMult;
      }
      
      // Overtime Cost
       if (attendance.overtimeHours > 0) {
        if (specificOvertimeRate != null) {
           overtimeCost = attendance.overtimeHours * specificOvertimeRate;
        } else {
           overtimeCost = attendance.overtimeHours * hourlyRate * overtimeMult;
        }
      }
    }

    return normalCost + overtimeCost;
    */
  }

  void _showAttendanceBottomSheet(
    BuildContext context,
    WidgetRef ref,
    Attendance attendance,
    dynamic worker,
    int projectId,
    DateTime queryDate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final hoursCtrl = TextEditingController(text: attendance.hours == 0 ? '' : attendance.hours.toString());
        final overtimeCtrl = TextEditingController(text: attendance.overtimeHours == 0 ? '' : attendance.overtimeHours.toString());
        final noteCtrl = TextEditingController(text: attendance.note ?? '');

        // Initialize state from attendance
        AttendanceStatus selectedStatus = attendance.status;
        DayType selectedDayType = attendance.dayType;

        return StatefulBuilder(
          builder: (context, setState) {
            final activeProject = ref.read(activeProjectProvider).valueOrNull;

            // Helper to calculate cost for preview
            double calculatePreviewCost() {
              if (activeProject == null) return 0;
              
              final h = double.tryParse(hoursCtrl.text.replaceAll(',', '.')) ?? 0;
              final o = double.tryParse(overtimeCtrl.text.replaceAll(',', '.')) ?? 0;

              // Create a temporary object for calculation
              final tempAttendance = Attendance()
                ..status = selectedStatus
                ..dayType = selectedDayType
                ..hours = h
                ..overtimeHours = o;

              return CostCalculator.calculateDailyCost(
                worker: worker,
                attendance: tempAttendance,
                project: activeProject,
              );
            }

            final costPreview = calculatePreviewCost();
            final isAbsent = selectedStatus == AttendanceStatus.absent || selectedStatus == AttendanceStatus.unpaidLeave;
            
            // Auto-fill hours based on status change
            void onStatusChanged(AttendanceStatus? newStatus) {
               if (newStatus == null) return;
               setState(() {
                 selectedStatus = newStatus;
                 if (newStatus == AttendanceStatus.absent || newStatus == AttendanceStatus.unpaidLeave) {
                   hoursCtrl.text = '0';
                   overtimeCtrl.text = '0';
                 } else if (newStatus == AttendanceStatus.present || newStatus == AttendanceStatus.paidLeave) {
                   // Default to project hours if Empty or 0
                   if (hoursCtrl.text.isEmpty || hoursCtrl.text == '0') {
                     double defaultHours = activeProject?.hoursPerDay ?? 8.0;
                     if (defaultHours.isNaN || defaultHours <= 0) defaultHours = 8.0;
                     hoursCtrl.text = defaultHours % 1 == 0 ? defaultHours.toInt().toString() : defaultHours.toString();
                   }
                 }
               });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${worker.name} - Puantaj',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        'Tahmini: ₺${costPreview.toStringAsFixed(2)}',
                         style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const Gap(16),
                  
                  // 1. Status Selection
                  const Text('Durum', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const Gap(4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusChip('Var', AttendanceStatus.present, selectedStatus, Colors.green, (s) => onStatusChanged(s)),
                        const Gap(8),
                        _buildStatusChip('Gelmedi', AttendanceStatus.absent, selectedStatus, Colors.red, (s) => onStatusChanged(s)),
                        const Gap(8),
                        _buildStatusChip('Ücretli İzin', AttendanceStatus.paidLeave, selectedStatus, Colors.blue, (s) => onStatusChanged(s)),
                        const Gap(8),
                        _buildStatusChip('Ücretsiz İzin', AttendanceStatus.unpaidLeave, selectedStatus, Colors.orange, (s) => onStatusChanged(s)),
                         const Gap(8),
                        _buildStatusChip('Raporlu', AttendanceStatus.sick, selectedStatus, Colors.purple, (s) => onStatusChanged(s)),
                      ],
                    ),
                  ),
                  
                  const Gap(16),

                  // 2. Day Type Selection
                  const Text('Gün Tipi', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const Gap(4),
                  SegmentedButton<DayType>(
                    segments: const [
                      ButtonSegment(value: DayType.normal, label: Text('Normal')),
                      ButtonSegment(value: DayType.weekend, label: Text('Hafta Sonu')),
                      ButtonSegment(value: DayType.holiday, label: Text('Tatil')),
                    ],
                    selected: {selectedDayType},
                    onSelectionChanged: (val) => setState(() => selectedDayType = val.first),
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const Gap(16),

                  // 3. Inputs
                  Opacity(
                    opacity: isAbsent ? 0.5 : 1.0,
                    child: AbsorbPointer(
                      absorbing: isAbsent,
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Normal Saat',
                              controller: hoursCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: CustomTextField(
                              label: 'Fazla Mesai',
                              controller: overtimeCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                               onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Gap(12),
                  CustomTextField(label: 'Not', controller: noteCtrl),
                  const Gap(24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final h = double.tryParse(hoursCtrl.text.replaceAll(',', '.')) ?? 0;
                        final o = double.tryParse(overtimeCtrl.text.replaceAll(',', '.')) ?? 0;

                        attendance.hours = h;
                        attendance.overtimeHours = o;
                        attendance.note = noteCtrl.text;
                        attendance.status = selectedStatus;
                        attendance.dayType = selectedDayType;

                        await ref
                            .read(dailyAttendanceProvider(projectId, queryDate).notifier)
                            .updateAttendance(attendance);

                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Kaydet'),
                    ),
                  ),
                  const Gap(24),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildStatusChip(
    String label, 
    AttendanceStatus status, 
    AttendanceStatus current, 
    Color color,
    Function(AttendanceStatus) onSelected
  ) {
    final isSelected = status == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (b) { if(b) onSelected(status); },
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
       checkmarkColor: color,
    );
  }
}

class _AttendanceFooter extends ConsumerWidget {
  final int projectId;
  final DateTime date;

  const _AttendanceFooter({required this.projectId, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryDate = DateTime(date.year, date.month, date.day);
    final attendancesAsync = ref.watch(dailyAttendanceProvider(projectId, queryDate));
    final workersAsync = ref.watch(projectWorkersProvider(projectId));
    final activeProjectAsync = ref.watch(activeProjectProvider);

    if (!workersAsync.hasValue) return const SizedBox();
    final workers = workersAsync.value!;
    if (workers.isEmpty) return const SizedBox();

    final attendances = attendancesAsync.valueOrNull ?? [];

    double totalHours = 0;
    double totalCost = 0;

    final workerMap = {for (var w in workers) w.id: w};
    final project = activeProjectAsync.valueOrNull;

    for (var a in attendances) {
      final worker = workerMap[a.workerId];
      if (worker != null && project != null) {
        // Sum Hours for worked/paid days
        if (a.status == AttendanceStatus.present || a.status == AttendanceStatus.paidLeave) {
          totalHours += a.hours + a.overtimeHours;
        }

        // Accrue Cost using centralized logic
        totalCost += CostCalculator.calculateDailyCost(
          worker: worker,
          attendance: a,
          project: project,
        );
      }
    }

    final formattedHours = totalHours.toStringAsFixed(1).replaceAll('.', ',');
    final formattedCost = totalCost.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1E293B) // Dark mode: Slate 800 (Surface) instead of bright primary
            : Theme.of(context).primaryColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: const [
          BoxShadow(blurRadius: 4, offset: Offset(0, -2), color: Colors.black12),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Toplam Saat', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    formattedHours,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            PermissionGuard(
              permission: AppPermission.financeView,
              child: Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Maliyet', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      '₺$formattedCost',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AttendanceStatus status;
  final bool isInteractive;

  const _StatusBadge({
    required this.status,
    this.isInteractive = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case AttendanceStatus.present:
        color = Colors.green;
        icon = Icons.check_circle_outline;
        label = 'Var';
        break;
      case AttendanceStatus.absent:
        color = Colors.red;
        icon = Icons.cancel_outlined;
        label = 'Yok';
        break;
      case AttendanceStatus.paidLeave:
        color = Colors.blue;
        icon = Icons.beach_access;
        label = 'Ücretli İzin';
        break;
      case AttendanceStatus.unpaidLeave:
        color = Colors.orange;
        icon = Icons.money_off;
        label = 'Ücretsiz İzin';
        break;
      case AttendanceStatus.sick:
        color = Colors.purple;
        icon = Icons.sick_outlined;
        label = 'Raporlu';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const Gap(6),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
          ),
          if (isInteractive) ...[
            const Gap(6),
            Icon(Icons.touch_app, size: 14, color: color.withOpacity(0.8)),
          ],
        ],
      ),
    );
  }
}
