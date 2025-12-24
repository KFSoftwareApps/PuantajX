import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'dart:async';

import 'payment_summary_screen.dart';
import '../data/models/pay_adjustment_model.dart';
import '../data/repositories/pay_adjustment_repository.dart';
import '../../../core/init/providers.dart';
import '../../../core/widgets/permission_guard.dart';
import '../../../core/authz/permissions.dart';
import '../../project/presentation/providers/active_project_provider.dart';

final workerAdjustmentsForRangeProvider = StreamProvider.family
    .autoDispose<List<PayAdjustment>, (int projectId, int workerId, DateTime start, DateTime end)>(
        (ref, args) async* {
  final isar = await ref.watch(isarProvider.future);
  final projectId = args.$1;
  final workerId = args.$2;
  final start = args.$3;
  final end = args.$4;

  Future<List<PayAdjustment>> fetch() async {
    if (isar == null) return [];
    
    final all = await isar.payAdjustments
        .filter()
        .projectIdEqualTo(projectId)
        .workerIdEqualTo(workerId)
        .findAll();

    final filtered = all
        .where((a) => !a.date.isBefore(start) && !a.date.isAfter(end))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  // Initial
  yield await fetch();

  if (isar != null) {
      // Watch
      final port = isar.payAdjustments
          .filter()
          .projectIdEqualTo(projectId)
          .workerIdEqualTo(workerId)
          .watchLazy();

      final controller = StreamController<void>();
      final sub = port.listen((_) => controller.add(null));

      ref.onDispose(() {
        sub.cancel();
        controller.close();
      });

      await for (final _ in controller.stream) {
        yield await fetch();
      }
  }

});

class WorkerPaymentDetailScreen extends ConsumerWidget {
  final int projectId;
  final int workerId;

  const WorkerPaymentDetailScreen({super.key, required this.projectId, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(dateRangeProvider); // ✅ buradan
    final summaryListAsync = ref.watch(paymentSummaryProvider((projectId, dateRange))); // ✅ record
    final adjustmentsAsync = ref.watch(
      workerAdjustmentsForRangeProvider((projectId, workerId, dateRange.start, dateRange.end)),
    );

    final activeProjectAsync = ref.watch(activeProjectProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Personel Hakediş Detayı')),
      floatingActionButton: PermissionGuard(
        permission: AppPermission.workerRateEdit,
        child: FloatingActionButton(
          onPressed: () {
            final project = activeProjectAsync.valueOrNull;
            if (project == null) return;
            _showAddAdjustmentDialog(context, ref, project.financeLockDate);
          },
          child: const Icon(Icons.add),
        ),
      ),
      body: PermissionGuard(
        permission: AppPermission.financeView,
        fallback: const Center(child: Text('Bu ekranı görüntüleme yetkiniz yok.')),
        child: summaryListAsync.when(
          data: (summaryList) {
            final workerSummary = summaryList.firstWhere(
              (s) => s.workerId == workerId,
              orElse: () => PaymentSummaryItem(
                workerId: workerId,
                workerName: 'Bilinmiyor',
                payType: PayType.daily,
                daysWorked: 0,
                hoursWorked: 0,
                totalAmount: 0,
              ),
            );

            return adjustmentsAsync.when(
              data: (adjustments) {
                return _buildContent(
                  context,
                  ref,
                  workerSummary,
                  adjustments,
                  dateRange,
                  activeProjectAsync.valueOrNull?.financeLockDate,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Hata: $e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Hata: $e')),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    PaymentSummaryItem summary,
    List<PayAdjustment> adjustments,
    DateRange range,
    DateTime? lockDate,
  ) {
    final earnings = summary.totalAmount;

    double totalAdvance = 0;
    double totalDeduction = 0;
    double totalBonus = 0;

    for (var a in adjustments) {
      if (a.type == AdjustmentType.advance) totalAdvance += a.amount;
      if (a.type == AdjustmentType.deduction) totalDeduction += a.amount;
      if (a.type == AdjustmentType.bonus) totalBonus += a.amount;
    }

    final netPay = earnings + totalBonus - totalAdvance - totalDeduction;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(summary.workerName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Net Ödenecek Tutar', style: TextStyle(color: Colors.blue.shade900)),
                  const Gap(8),
                  Text('${netPay.toStringAsFixed(2)} TL',
                      style: TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                  const Gap(8),
                  Text(
                    '${DateFormat('dd.MM.yyyy').format(range.start)} - ${DateFormat('dd.MM.yyyy').format(range.end)}',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ],
              ),
            ),
          ),
          const Gap(24),

          _SummaryRow(label: 'Hakediş (Çalışma)', amount: earnings, isPositive: true),
          _SummaryRow(label: 'Prim / Ek Ödeme', amount: totalBonus, isPositive: true),
          const Divider(),
          _SummaryRow(label: 'Avans', amount: totalAdvance, isPositive: false),
          _SummaryRow(label: 'Kesinti / Ceza', amount: totalDeduction, isPositive: false),

          const Gap(24),
          const Text('Hareket Geçmişi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Gap(8),

          if (adjustments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Henüz ek işlem yok.', style: TextStyle(color: Colors.grey)),
            ),

          ...adjustments.map((adj) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_getIcon(adj.type), color: _getColor(adj.type)),
                  title: Text(_getTypeLabel(adj.type)),
                  subtitle: Text('${DateFormat('dd.MM.yyyy').format(adj.date)} • ${adj.description ?? ""}'),
                  trailing: Text(
                    '${adj.amount.toStringAsFixed(2)} TL',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _getColor(adj.type)),
                  ),
                  onLongPress: () async {
                    if (lockDate != null && adj.date.isBefore(lockDate.add(const Duration(days: 1)))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kilitli döneme ait kayıt silinemez.')),
                      );
                      return;
                    }
                    await ref.read(payAdjustmentRepositoryProvider).deleteAdjustment(adj.id);
                    ref.invalidate(workerAdjustmentsForRangeProvider(
                      (projectId, workerId, range.start, range.end),
                    ));
                  },
                ),
              )),
          const Gap(80),
        ],
      ),
    );
  }

  IconData _getIcon(AdjustmentType type) {
    switch (type) {
      case AdjustmentType.advance:
        return Icons.money_off;
      case AdjustmentType.deduction:
        return Icons.remove_circle;
      case AdjustmentType.bonus:
        return Icons.add_circle;
    }
  }

  Color _getColor(AdjustmentType type) {
    switch (type) {
      case AdjustmentType.advance:
        return Colors.orange;
      case AdjustmentType.deduction:
        return Colors.red;
      case AdjustmentType.bonus:
        return Colors.green;
    }
  }

  String _getTypeLabel(AdjustmentType type) {
    switch (type) {
      case AdjustmentType.advance:
        return 'Avans';
      case AdjustmentType.deduction:
        return 'Kesinti';
      case AdjustmentType.bonus:
        return 'Prim';
    }
  }

  void _showAddAdjustmentDialog(BuildContext context, WidgetRef ref, DateTime? lockDate) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    AdjustmentType selectedType = AdjustmentType.advance;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDateLocked =
              lockDate != null && selectedDate.isBefore(lockDate.add(const Duration(days: 1)));

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('İşlem Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(16),
                SegmentedButton<AdjustmentType>(
                  segments: const [
                    ButtonSegment(value: AdjustmentType.advance, label: Text('Avans')),
                    ButtonSegment(value: AdjustmentType.deduction, label: Text('Kesinti')),
                    ButtonSegment(value: AdjustmentType.bonus, label: Text('Prim')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (v) => setState(() => selectedType = v.first),
                ),
                const Gap(16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tutar (TL)', border: OutlineInputBorder()),
                ),
                const Gap(12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder()),
                ),
                const Gap(12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => selectedDate = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Tarih', border: OutlineInputBorder()),
                    child: Text(DateFormat('dd.MM.yyyy').format(selectedDate)),
                  ),
                ),
                if (isDateLocked)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('Seçilen tarih kilitli dönem içinde!',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                const Gap(24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isDateLocked
                        ? null
                        : () async {
                            final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
                            if (amount <= 0) return;

                            final adj = PayAdjustment()
                              ..projectId = projectId
                              ..workerId = workerId
                              ..amount = amount
                              ..type = selectedType
                              ..date = selectedDate
                              ..description = descCtrl.text;

                            await ref.read(payAdjustmentRepositoryProvider).addAdjustment(adj);

                            final range = ref.read(dateRangeProvider);
                            ref.invalidate(workerAdjustmentsForRangeProvider(
                              (projectId, workerId, range.start, range.end),
                            ));

                            if (context.mounted) Navigator.pop(context);
                          },
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isPositive;

  const _SummaryRow({required this.label, required this.amount, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            '${isPositive ? '+' : '-'} ${amount.toStringAsFixed(2)} TL',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
