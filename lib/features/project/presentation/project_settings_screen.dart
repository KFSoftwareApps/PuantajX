import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/widgets/permission_guard.dart';
import '../data/models/project_model.dart';
import 'providers/project_providers.dart';

class ProjectSettingsScreen extends ConsumerStatefulWidget {
  final int projectId;

  const ProjectSettingsScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends ConsumerState<ProjectSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _codeController;
  late TextEditingController _hoursPerDayController;
  late TextEditingController _monthlyWorkDaysController;
  late TextEditingController _overtimeMultiplierController;
  late TextEditingController _weekendMultiplierController;
  late TextEditingController _holidayMultiplierController;
  late bool _isArchived;

  final _formKey = GlobalKey<FormState>();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _locationController = TextEditingController();
    _codeController = TextEditingController();
    _hoursPerDayController = TextEditingController();
    _monthlyWorkDaysController = TextEditingController();
    _overtimeMultiplierController = TextEditingController();
    _weekendMultiplierController = TextEditingController();
    _holidayMultiplierController = TextEditingController();
    _isArchived = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _codeController.dispose();
    _hoursPerDayController.dispose();
    _monthlyWorkDaysController.dispose();
    _overtimeMultiplierController.dispose();
    _weekendMultiplierController.dispose();
    _holidayMultiplierController.dispose();
    super.dispose();
  }

  void _loadProject(Project project) {
    if (_nameController.text.isEmpty) {
      _nameController.text = project.name;
      _locationController.text = project.location ?? '';
      _codeController.text = project.projectCode ?? '';
      
      // Sanitize corrupted values
      final safeHours = (project.hoursPerDay.isNaN || project.hoursPerDay <= 0 || project.hoursPerDay > 24) 
          ? 8.0 
          : project.hoursPerDay;
      _hoursPerDayController.text = _formatDouble(safeHours);
      
      final safeDays = (project.monthlyWorkDays <= 0 || project.monthlyWorkDays > 31) 
          ? 26 
          : project.monthlyWorkDays;
      _monthlyWorkDaysController.text = safeDays.toString();
      
      _overtimeMultiplierController.text = _formatDouble(project.overtimeMultiplier);
      _weekendMultiplierController.text = _formatDouble(project.weekendMultiplier);
      // If model has 1.0 (default), it will show "1". User asked for 2. 
      // I should probably check if it is 1.0 (default) and maybe suggest 2? 
      // Or "Default should be 2". 
      // If the current value is 1.0 (default from old model), I will leave it as is unless I forcibly migrate it.
      // But if it's 0 or NaN, I can default to 2.
      if (project.holidayMultiplier <= 0 || project.holidayMultiplier.isNaN) {
         _holidayMultiplierController.text = "2";
      } else {
        _holidayMultiplierController.text = _formatDouble(project.holidayMultiplier);
      }
      _isArchived = project.status == ProjectStatus.archived;
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectByIdProvider(widget.projectId));

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Proje Ayarları'),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: () => _saveChanges(projectAsync.value!),
                child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        body: projectAsync.when(
          data: (project) {
            if (project == null) return const Center(child: Text('Proje bulunamadı'));
            _loadProject(project);
    
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                onChanged: () => setState(() => _hasChanges = true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Info Section
                    Text('Temel Bilgiler', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Gap(12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CustomTextField(
                              label: 'Proje Adı',
                              controller: _nameController,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Proje adı zorunludur' : null,
                            ),
                            const Gap(12),
                            CustomTextField(
                              label: 'Konum / Şantiye',
                              controller: _locationController,
                            ),
                            const Gap(12),
                            CustomTextField(
                              label: 'Proje Kodu (Opsiyonel)',
                              controller: _codeController,
                              hint: 'Örn: PRJ-2025-001',
                            ),
                          ],
                        ),
                      ),
                    ),
    
                    const Gap(24),

                    // Financial Settings Section
                    Text('Finansal Ayarlar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Gap(12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Günlük Çalışma (Saat)',
                                    controller: _hoursPerDayController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Zorunlu';
                                      final num = double.tryParse(v.replaceAll(',', '.'));
                                      if (num == null || num <= 0 || num > 24) return 'Geçersiz';
                                      return null;
                                    },
                                  ),
                                ),
                                const Gap(12),
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Aylık İş Günü',
                                    controller: _monthlyWorkDaysController,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Zorunlu';
                                      final num = int.tryParse(v);
                                      if (num == null || num <= 0 || num > 31) return 'Geçersiz';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const Gap(12),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Fazla Mesai Çarpanı',
                                    controller: _overtimeMultiplierController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (v) => (double.tryParse(v?.replaceAll(',', '.') ?? '') ?? 0) <= 0 ? 'Geçersiz' : null,
                                  ),
                                ),
                                const Gap(12),
                                Expanded(
                                  child: CustomTextField(
                                    label: 'Hafta Sonu Çarpanı',
                                    controller: _weekendMultiplierController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (v) => (double.tryParse(v?.replaceAll(',', '.') ?? '') ?? 0) <= 0 ? 'Geçersiz' : null,
                                  ),
                                ),
                              ],
                            ),
                            const Gap(12),
                             CustomTextField(
                                label: 'Resmi Tatil Çarpanı',
                                controller: _holidayMultiplierController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (v) => (double.tryParse(v?.replaceAll(',', '.') ?? '') ?? 0) <= 0 ? 'Geçersiz' : null,
                              ),
                          ],
                        ),
                      ),
                    ),

                    const Gap(24),

                    // Status Section
                    Text('Durum', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Gap(12),
                    Card(
                      child: PermissionGuard(
                        permission: AppPermission.projectArchive,
                        fallback: const SizedBox.shrink(),
                        child: SwitchListTile(
                          title: const Text('Projeyi Arşivle'),
                          subtitle: const Text('Tamamlanan projeleri arşivleyebilirsiniz'),
                          value: _isArchived,
                          onChanged: (val) => setState(() {
                            _isArchived = val;
                            _hasChanges = true;
                          }),
                        ),
                      ),
                    ),
    
                    const Gap(24),
    
                    // Project Members Section
                    Text('Proje Üyeleri', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Gap(12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.group_outlined, color: Colors.indigo),
                        title: const Text('Proje Erişim Yönetimi'),
                        subtitle: const Text('Projeye erişimi olan kullanıcıları yönetin'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/projects/${widget.projectId}/members'),
                      ),
                    ),
    
                    const Gap(32),
    
                    // Save Button
                    PermissionGuard(
                      permission: AppPermission.projectUpdate,
                      child: CustomButton(
                        text: 'Değişiklikleri Kaydet',
                        onPressed: _hasChanges ? () => _saveChanges(project) : null,
                      ),
                    ),
    
                    const Gap(16),
    
                    // Danger Zone
                    PermissionGuard(
                      permission: AppPermission.projectUpdate,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(),
                          const Gap(16),
                          Text(
                            'Tehlikeli Bölge',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          const Gap(12),
                          OutlinedButton.icon(
                            onPressed: () => _confirmDelete(project),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            label: const Text('Projeyi Sil', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Hata: $e')),
        ),
      ),
    );
  }

  Future<bool> _showExitConfirmation(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kaydedilmemiş Değişiklikler'),
        content: const Text('Yaptığınız değişiklikler kaybolacak. Çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çık', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _saveChanges(Project project) async {
    if (!_formKey.currentState!.validate()) return;
    
    final newCode = _codeController.text.trim();
    
    // Uniqueness Check on Project Code
    if (newCode.isNotEmpty) {
      final allProjects = ref.read(projectsProvider).valueOrNull ?? [];
      final codeExists = allProjects.any((p) {
        return p.id != project.id && 
               p.projectCode != null && 
               p.projectCode!.toLowerCase() == newCode.toLowerCase();
      });
      
      if (codeExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu proje kodu başka bir projede kullanılıyor.')),
        );
        return;
      }
    }

    project.name = _nameController.text.trim();
    project.location = _locationController.text.trim();
    project.projectCode = newCode.isEmpty ? null : newCode;
    project.status = _isArchived ? ProjectStatus.archived : ProjectStatus.active;
    
    // Financial fields
    project.hoursPerDay = _parseDouble(_hoursPerDayController.text) ?? 8.0;
    project.monthlyWorkDays = int.tryParse(_monthlyWorkDaysController.text) ?? 26;
    project.overtimeMultiplier = _parseDouble(_overtimeMultiplierController.text) ?? 1.5;
    project.weekendMultiplier = _parseDouble(_weekendMultiplierController.text) ?? 1.5;
    project.holidayMultiplier = _parseDouble(_holidayMultiplierController.text) ?? 2.0;

    await ref.read(projectsProvider.notifier).updateProject(project);

    if (mounted) {
      setState(() => _hasChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proje ayarları güncellendi')),
      );
    }
  }

  double? _parseDouble(String text) {
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  String _formatDouble(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toString().replaceAll('.', ',');
  }

  void _confirmDelete(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projeyi Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${project.name} projesini silmek istediğinize emin misiniz?'),
            const Gap(12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  Gap(8),
                  Expanded(
                    child: Text(
                      'Bu işlem geri alınamaz. Tüm raporlar, puantajlar ve veriler silinecektir.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(projectsProvider.notifier).deleteProject(project.id);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                context.go('/projects'); // Navigate back to projects list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Proje silindi')),
                );
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
