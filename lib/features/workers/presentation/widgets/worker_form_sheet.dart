import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:isar/isar.dart';
import '../../../../core/types/app_types.dart';
import '../../../project/data/models/worker_model.dart';
import '../../../project/data/repositories/worker_repository.dart';
import '../../../project/data/models/project_worker_model.dart';
import '../../../project/presentation/providers/project_providers.dart';
import '../../../../core/init/providers.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../features/auth/data/repositories/auth_repository.dart';
import '../../../../features/project/presentation/providers/workers_provider.dart';
// import '../../../../core/widgets/custom_dropdown.dart'; // Not found, using DropdownButtonFormField instead

class WorkerFormSheet extends ConsumerStatefulWidget {
  final int? workerId;
  final int? initialProjectId;
  final String? initialType; // 'worker' or 'crew'

  const WorkerFormSheet({
    super.key,
    this.workerId,
    this.initialProjectId,
    this.initialType,
  });

  @override
  ConsumerState<WorkerFormSheet> createState() => _WorkerFormSheetState();
}

class _WorkerFormSheetState extends ConsumerState<WorkerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _tradeController;
  late TextEditingController _dailyRateController;
  late TextEditingController _ibanController;
  late TextEditingController _phoneController;
  
  PayType _payType = PayType.daily;
  String _type = 'worker';
  String _currency = 'TRY';
  int? _selectedCrewId;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _tradeController = TextEditingController();
    _dailyRateController = TextEditingController();
    _ibanController = TextEditingController();
    _phoneController = TextEditingController();
    
    if (widget.initialType != null) {
      _type = widget.initialType!;
    }

    if (widget.workerId != null) {
      _loadWorker();
    }
  }

  Future<void> _loadWorker() async {
    setState(() => _isLoading = true);
    try {
       // Using repo to get worker by ID or using the list provider
       // Since the list provider might not have ALL workers if it was filtered, but usually it does for project.
       // Safe bet: use the repository directly if we had a getWorker method, but we might not.
       // Let's stick to the list provider for now as implemented before.
       final allWorkers = await ref.read(projectWorkersProvider(widget.initialProjectId ?? 0).future);
       final worker = allWorkers.cast<Worker?>().firstWhere((w) => w?.id == widget.workerId, orElse: () => null);

      if (worker != null) {
        _nameController.text = worker.name;
        _tradeController.text = worker.trade ?? '';
        _dailyRateController.text = worker.dailyRate?.toString() ?? '';
        _ibanController.text = worker.iban ?? '';
        _phoneController.text = worker.phone ?? '';
        _payType = worker.payType;
        _type = worker.type;
        _currency = worker.currency;
      }
      
      // Load Crew ID
      if (widget.initialProjectId != null && widget.workerId != null) {
          final isar = ref.read(isarProvider).valueOrNull;
          if (isar != null) {
             final link = await isar.projectWorkers
               .filter()
               .projectIdEqualTo(widget.initialProjectId!)
               .workerIdEqualTo(widget.workerId!)
               .findFirst();
             if (link != null) {
               _selectedCrewId = link.crewId;
             }
          }
       }
    } catch (e) {
      debugPrint('Error loading worker: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tradeController.dispose();
    _dailyRateController.dispose();
    _ibanController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCrew = _type == 'crew';

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      widget.workerId == null 
                          ? (isCrew ? 'Yeni Ekip Oluştur' : 'Yeni Personel Oluştur')
                          : (isCrew ? 'Ekibi Düzenle' : 'Personeli Düzenle'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (widget.workerId == null) ...[
                        Center(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'worker', label: Text('Personel'), icon: Icon(Icons.person)),
                              ButtonSegment(value: 'crew', label: Text('Ekip'), icon: Icon(Icons.group)),
                            ],
                            selected: {_type},
                            onSelectionChanged: (Set<String> newSelection) {
                              if (widget.workerId == null) {
                                setState(() => _type = newSelection.first);
                              }
                            },
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                        const Gap(24),
                      ],

                      CustomTextField(
                        label: isCrew ? 'Ekip Adı' : 'Ad Soyad',
                        controller: _nameController,
                        validator: (v) => v?.isEmpty == true ? 'Zorunlu alan' : null,
                      ),
                      const Gap(16),

                      if (isCrew) ...[
                        CustomTextField(
                          label: 'Açıklama (Opsiyonel)',
                          controller: _tradeController,
                          hint: 'Örn: Sıva Ekibi',
                        ),
                      ] else ...[
                        CustomTextField(
                          label: 'Meslek / Ünvan',
                          controller: _tradeController,
                          hint: 'Örn: Kalıpçı Ustası',
                        ),
                        const Gap(16),

                        // Crew Selection
                        if (widget.initialProjectId != null) ...[
                           Consumer(
                             builder: (context, ref, child) {
                               final workersAsync = ref.watch(projectWorkersProvider(widget.initialProjectId!));
                               return workersAsync.when(
                                 data: (workers) {
                                   final crews = workers.where((w) => w.type == 'crew').toList();
                                   if (crews.isEmpty) return const SizedBox.shrink();
                                   
                                   return Column(
                                     children: [
                                       DropdownButtonFormField<int>(
                                         decoration: const InputDecoration(labelText: 'Bağlı Olduğu Ekip (Opsiyonel)', border: OutlineInputBorder()),
                                         value: _selectedCrewId,
                                         items: [
                                           const DropdownMenuItem<int>(value: null, child: Text('Ekipsiz / Bağımsız')),
                                           ...crews.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                                         ],
                                         onChanged: (v) => setState(() => _selectedCrewId = v),
                                       ),
                                       const Gap(16),
                                     ],
                                   );
                                 },
                                 loading: () => const LinearProgressIndicator(),
                                 error: (_,__) => const SizedBox.shrink(),
                               );
                             }
                           ),
                        ],
                        
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<PayType>(
                                decoration: const InputDecoration(labelText: 'Ödeme Tipi', border: OutlineInputBorder()),
                                value: _payType,
                                items: const [
                                  DropdownMenuItem(value: PayType.daily, child: Text('Günlük')),
                                  DropdownMenuItem(value: PayType.monthly, child: Text('Aylık')),
                                  DropdownMenuItem(value: PayType.hourly, child: Text('Saatlik')),
                                ],
                                onChanged: (v) => setState(() => _payType = v!),
                              ),
                            ),
                            const Gap(12),
                            Expanded(
                              flex: 3,
                              child: CustomTextField(
                                label: 'Ücret',
                                controller: _dailyRateController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(16),
                        CustomTextField(
                          label: 'Telefon',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                        ),
                        const Gap(16),
                        CustomTextField(
                          label: 'IBAN',
                          controller: _ibanController,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: CustomButton(
                  text: 'Kaydet',
                  isLoading: _isLoading,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final worker = Worker()
        ..id = widget.workerId ?? Isar.autoIncrement
        ..orgId = (await ref.read(authRepositoryProvider).getCurrentUser())?.currentOrgId ?? 'DEFAULT'
        ..name = _nameController.text
        ..type = _type
        ..trade = _tradeController.text
        ..payType = _payType
        ..currency = _currency
        ..phone = _phoneController.text
        ..iban = _ibanController.text
        ..dailyRate = double.tryParse(_dailyRateController.text)
        ..monthlyRate = double.tryParse(_dailyRateController.text) 
        ..hourlyRate = double.tryParse(_dailyRateController.text)
        ..createdAt = DateTime.now()
        ..lastUpdatedAt = DateTime.now();
        
      if (_payType == PayType.daily) worker.monthlyRate = null;
      if (_payType == PayType.monthly) worker.dailyRate = null;
        
      await ref.read(workerRepositoryProvider).saveWorker(worker);
      
      // If we are in project context and it's a new worker, assign them to the project
      if (widget.initialProjectId != null && widget.workerId == null) {
         await ref.read(projectWorkersProvider(widget.initialProjectId!).notifier).assignWorkers([worker.id]);
      }

      // Assign Crew
      if (widget.initialProjectId != null && _type != 'crew') {
         await ref.read(projectWorkersProvider(widget.initialProjectId!).notifier).assignCrew(worker.id, _selectedCrewId);
      }

      // Refresh providers
      ref.invalidate(projectWorkersProvider(widget.initialProjectId ?? 0));
      ref.invalidate(workersProvider);
      
      if (mounted) Navigator.pop(context);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
