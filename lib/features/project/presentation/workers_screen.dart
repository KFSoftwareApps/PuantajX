import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/widgets/permission_guard.dart';
import '../../../core/types/app_types.dart'; // ✅ PayType buradan gelsin

import '../data/models/worker_model.dart'; // ✅ PayType çakışmasını kes
import 'providers/workers_provider.dart';
import '../../workers/presentation/widgets/worker_form_sheet.dart';

class WorkersScreen extends ConsumerWidget {
  const WorkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workersAsync = ref.watch(workersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ekip / Çalışanlar'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Çalışanlar'),
              Tab(text: 'Ekipler'),
            ],
          ),
        ),
        floatingActionButton: PermissionGuard(
          permission: AppPermission.workerCreate,
          child: FloatingActionButton(
            onPressed: () => _showAddWorkerDialog(context, ref),
            child: const Icon(Icons.person_add),
          ),
        ),
        body: workersAsync.when(
          data: (workers) {
            final individualWorkers =
                workers.where((w) => w.type == 'worker').toList();
            final crews = workers.where((w) => w.type == 'crew').toList();

            return TabBarView(
              children: [
                _WorkerList(
                  workers: individualWorkers,
                  type: 'worker',
                  ref: ref,
                  onDelete: (w) => _confirmDelete(context, ref, w),
                ),
                _WorkerList(
                  workers: crews,
                  type: 'crew',
                  ref: ref,
                  onDelete: (w) => _confirmDelete(context, ref, w),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Hata: $err')),
        ),
      ),
    );
  }

  void _showAddWorkerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final tradeController = TextEditingController();
    final rateController = TextEditingController();
    final overtimeRateController = TextEditingController();
    final holidayRateController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String selectedType = 'worker';
    PayType selectedPayType = PayType.daily;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Text('Yeni Kayıt Ekle',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Gap(16),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'worker',
                        label: Text('Personel'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: 'crew',
                        label: Text('Ekip'),
                        icon: Icon(Icons.group),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        selectedType = newSelection.first;
                      });
                    },
                  ),
                  const Gap(16),
                  CustomTextField(
                    label: selectedType == 'worker' ? 'Ad Soyad' : 'Ekip Adı',
                    controller: nameController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                  ),
                  const Gap(12),
                  CustomTextField(
                    label: selectedType == 'worker'
                        ? 'Ünvan / Görev'
                        : 'Ekip Uzmanlığı (örn. Sıvacı)',
                    controller: tradeController,
                  ),

                  // Wage Fields - Protected
                  if (selectedType == 'worker') ...[
                    const Gap(12),
                    PermissionGuard(
                      permission: AppPermission.financeManage,
                      fallback: const SizedBox.shrink(),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hakediş Bilgileri (Opsiyonel)',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                            const Gap(8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<PayType>(
                                    value: selectedPayType,
                                    decoration: const InputDecoration(
                                      labelText: 'Ücret Tipi',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: PayType.daily,
                                          child: Text('Günlük')),
                                      DropdownMenuItem(
                                          value: PayType.hourly,
                                          child: Text('Saatlik')),
                                      DropdownMenuItem(
                                          value: PayType.monthly,
                                          child: Text('Aylık')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => selectedPayType = val);
                                      }
                                    },
                                  ),
                                ),
                                const Gap(12),
                                Expanded(
                                  flex: 3,
                                  child: CustomTextField(
                                    label: selectedPayType == PayType.daily
                                        ? 'Günlük Tutar (TL)'
                                        : selectedPayType == PayType.hourly
                                            ? 'Saatlik Ücret (TL)'
                                            : 'Aylık Ücret (TL)',
                                    controller: rateController,
                                    keyboardType: const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (selectedPayType == PayType.monthly) ...[
                              const Gap(8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                    const Gap(8),
                                    Expanded(
                                      child: Text(
                                        'Hesap: Aylık / (26 gün * 8 saat)\nVarsayılan değerler proje ayarlarından değiştirilebilir.',
                                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Gap(12),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Saatlik Mesai (TL)',
                                    controller: overtimeRateController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                                const Gap(12),
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Tatil/Bayram (TL)',
                                    controller: holidayRateController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const Gap(12),
                  CustomTextField(
                    label: 'Kısa Açıklama (Opsiyonel)',
                    controller: descController,
                    maxLines: 2,
                  ),
                  const Gap(24),
                  CustomButton(
                    text: 'Kaydet',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final rate = double.tryParse(
                        rateController.text.trim().replaceAll(',', '.'),
                      );
                      final overtimeRate = double.tryParse(
                        overtimeRateController.text.trim().replaceAll(',', '.'),
                      );
                      final holidayRate = double.tryParse(
                        holidayRateController.text.trim().replaceAll(',', '.'),
                      );

                      await ref.read(workersProvider.notifier).addWorker(
                            name: nameController.text.trim(),
                            trade: tradeController.text.trim().isEmpty
                                ? null
                                : tradeController.text.trim(),
                            currency: 'TRY',
                            payType: selectedType == 'worker'
                                ? selectedPayType
                                : PayType.daily,
                            dailyRate: (selectedType == 'worker' &&
                                    selectedPayType == PayType.daily)
                                ? rate
                                : null,
                            hourlyRate: (selectedType == 'worker' &&
                                    selectedPayType == PayType.hourly)
                                ? rate
                                : null,
                            monthlyRate: (selectedType == 'worker' &&
                                    selectedPayType == PayType.monthly)
                                ? rate
                                : null,
                            overtimeRate: selectedType == 'worker' ? overtimeRate : null,
                            holidayRate: selectedType == 'worker' ? holidayRate : null,
                            type: selectedType,
                            description: descController.text.trim().isEmpty
                                ? null
                                : descController.text.trim(),
                            active: true,
                            orgId: 'local-org',
                          );

                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Worker worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silme İşlemi'),
        content: Text('${worker.name} silinsin mi? Geçmiş kayıtlar etkilenebilir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          PermissionGuard(
            permission: AppPermission.workerUpdate,
            fallback: const SizedBox.shrink(),
            child: TextButton(
              onPressed: () {
                ref.read(workersProvider.notifier).deleteWorker(worker.id);
                Navigator.pop(context);
              },
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerList extends StatelessWidget {
  final List<Worker> workers;
  final String type;
  final WidgetRef ref;
  final Function(Worker) onDelete;

  const _WorkerList({
    required this.workers,
    required this.type,
    required this.ref,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (workers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(type == 'worker' ? Icons.person_off : Icons.group_off,
                size: 64, color: Colors.grey[300]),
            const Gap(16),
            Text(
              type == 'worker' ? 'Kayıtlı personel yok.' : 'Kayıtlı ekip yok.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final worker = workers[index];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                type == 'crew' ? Colors.orange.shade100 : Colors.blue.shade100,
            child: Icon(type == 'crew' ? Icons.group : Icons.person,
                color: type == 'crew' ? Colors.orange : Colors.blue),
          ),
          title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (worker.trade != null && worker.trade!.isNotEmpty)
                Text(worker.trade!, style: TextStyle(color: Colors.grey[700])),
              if (worker.description != null && worker.description!.isNotEmpty)
                Text(
                  worker.description!,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              PermissionGuard(
                permission: AppPermission.financeView,
                child: worker.dailyRate != null
                    ? Text(
                        'Maliyet: ${worker.dailyRate} TL',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          trailing: PermissionGuard(
            permission: AppPermission.workerUpdate,
            fallback: Switch(value: worker.active, onChanged: null),
            child: Switch(
              value: worker.active,
              onChanged: (_) {
                ref.read(workersProvider.notifier).toggleStatus(worker);
              },
            ),
          ),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => WorkerFormSheet(
                workerId: worker.id,
                // Global edit, no project context
              ),
            );
          },
          onLongPress: () => onDelete(worker),
        );
      },
    );
  }
}
