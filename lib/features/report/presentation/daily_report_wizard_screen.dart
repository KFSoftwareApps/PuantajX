import '../../../core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import '../../../core/widgets/platform_image.dart'; // New Import
import '../../../core/utils/platform/platform_file_helper.dart'; // New Import
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../project/presentation/providers/project_providers.dart';
import '../../project/presentation/providers/active_project_provider.dart';
import '../data/models/daily_report_model.dart';
import '../data/repositories/report_repository.dart';
import 'providers/report_providers.dart';
import '../../../core/services/sync_service.dart';
import '../../auth/data/repositories/auth_repository.dart'; // Import AuthController


// Wizard State Providers
final wizardPageProvider = StateProvider.autoDispose<int>((ref) => 0);
final wizardReportProvider = StateProvider.autoDispose<DailyReport>((ref) {
  final user = ref.watch(authControllerProvider).value;
  return DailyReport()
    ..date = DateTime.now()
    ..shift = 'Gündüz'
    ..projectId = 0
    ..orgId = user?.currentOrgId ?? ''; // Initialize orgId to prevent crash
});
final wizardSubmissionProvider = StateProvider.autoDispose<bool>((ref) => false); // false = Draft, true = Submitted

class DailyReportWizardScreen extends ConsumerStatefulWidget {
  final DailyReport? initialReport;
  const DailyReportWizardScreen({super.key, this.initialReport});

  @override
  ConsumerState<DailyReportWizardScreen> createState() => _DailyReportWizardScreenState();
}

class _DailyReportWizardScreenState extends ConsumerState<DailyReportWizardScreen> {
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Seed data if editing
    if (widget.initialReport != null) {
      Future.microtask(() {
         ref.read(wizardReportProvider.notifier).state = _copyReport(widget.initialReport!);
         // If status is submitted, we might want to keep it? But usually we are editing DRAFT.
         // If editing submitted, we might revert to draft or keep submitted?
         // Let's assume we keep current status bit logic.
         // Also update page to 0.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(wizardPageProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final isEditing = widget.initialReport != null;

    if (projects.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yeni Rapor')),
        body: const Center(child: Text('Önce proje oluşturmalısınız.')),
      );
    }

    // Total steps: 5 (General, WorkLog, Crew, Photos, Summary)
    const totalSteps = 5;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Raporu Düzenle (${page + 1}/$totalSteps)' : 'Günlük Rapor Oluştur (${page + 1}/$totalSteps)'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Stepper Indicator
          LinearProgressIndicator(value: (page + 1) / totalSteps),
          
          Expanded(
            child: IndexedStack(
              index: page,
              children: const [
                _StepGeneralInfo(),
                _StepWorkLog(),
                _StepCrewAndResources(), 
                _StepPhotos(),
                _StepSummary(),
              ],
            ),
          ),
          
          // Bottom Navigation
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                if (page > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => ref.read(wizardPageProvider.notifier).state--,
                      child: const Text('Geri'),
                    ),
                  )
                else
                  const Spacer(),
                const Gap(16),
                Expanded(
                  child: CustomButton(
                    text: page == totalSteps - 1 ? 'Tamamla' : 'Devam Et',
                    isLoading: _isSubmitting,
                    onPressed: () {
                      if (page < totalSteps - 1) {
                        ref.read(wizardPageProvider.notifier).state++;
                      } else {
                        _submitReport(context, ref);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(BuildContext context, WidgetRef ref) async {
    setState(() => _isSubmitting = true);
    try {
      var report = ref.read(wizardReportProvider);
      final projects = ref.read(projectsProvider).valueOrNull ?? [];

      // Ensure Project ID is valid
      if (report.projectId == 0) {
        if (projects.isNotEmpty) {
          report.projectId = projects.first.id;
        } else {
           throw Exception('Lütfen bir proje seçin.');
        }
      }

      // Basic validation
      if (report.generalNote == null || report.generalNote!.isEmpty) {
        throw Exception('Genel not alanı zorunludur.');
      }
      
      // Set status based on user choice
      final shouldSubmit = ref.read(wizardSubmissionProvider);
      debugPrint('Report Submission: shouldSubmit=$shouldSubmit');
      
      final currentUser = ref.read(authControllerProvider).value;
      if (currentUser != null) {
        report.orgId = currentUser.currentOrgId; 
      }

      report = report.copyWith(
        status: shouldSubmit ? ReportStatus.submitted : ReportStatus.draft,
        lastUpdatedAt: DateTime.now(),
      );

      // Save
      if (widget.initialReport != null) {
         debugPrint('Updating existing report...');
         await ref.read(reportRepositoryProvider).updateReport(report);
         ref.invalidate(reportByIdProvider(report.id));
         ref.invalidate(projectReportsProvider(report.projectId));
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapor güncellendi.')));
         }
      } else {
         debugPrint('Creating new report...');
         await ref.read(projectReportsProvider(report.projectId).notifier).createReport(report);
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapor oluşturuldu.')));
         }
      }
      
      ref.read(syncServiceProvider).syncAll();

      if (context.mounted) {
         context.pop();
      }
    } catch (e) {
      debugPrint('Report Submission Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _StepGeneralInfo extends ConsumerStatefulWidget {
  const _StepGeneralInfo();
  @override
  ConsumerState<_StepGeneralInfo> createState() => _StepGeneralInfoState();
}

class _StepGeneralInfoState extends ConsumerState<_StepGeneralInfo> {
  late TextEditingController _weatherController;

  @override
  void initState() {
    super.initState();
    // Initialize with current value from provider
    final currentReport = ref.read(wizardReportProvider);
    _weatherController = TextEditingController(text: currentReport.weather);
  }

  @override
  void dispose() {
    _weatherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(wizardReportProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final activeProject = ref.watch(activeProjectProvider).valueOrNull;

    // Auto-set project ID if active project exists and report has no project set (0)
    if (activeProject != null && report.projectId == 0) {
       Future.microtask(() {
         ref.read(wizardReportProvider.notifier).update((state) => _copyReport(state)..projectId = activeProject.id);
       });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Proje ve Genel Bilgiler', style: Theme.of(context).textTheme.titleLarge),
          const Gap(16),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Proje', border: OutlineInputBorder()),
            value: report.projectId == 0 ? null : report.projectId,
            items: projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
            onChanged: (val) {
              if (val != null) {
                ref.read(wizardReportProvider.notifier).update((state) {
                   return _copyReport(state)..projectId = val;
                });
              }
            },
            validator: (val) => val == null || val == 0 ? 'Proje seçimi zorunludur' : null,
          ),
          const Gap(16),
          CustomTextField(
            label: 'Tarih',
            readOnly: true,
            hint: DateFormat('dd.MM.yyyy').format(report.date),
            suffixIcon: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: report.date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                ref.read(wizardReportProvider.notifier).update((state) {
                   return _copyReport(state)..date = date;
                });
              }
            },
          ),
          const Gap(16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Vardiya', border: OutlineInputBorder()),
            initialValue: report.shift ?? 'Gündüz',
            items: const ['Gündüz', 'Gece'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) {
                 ref.read(wizardReportProvider.notifier).update((state) {
                   return _copyReport(state)..shift = val;
                });
            },
          ),
          const Gap(16),
          CustomTextField(
            label: 'Hava Durumu',
            hint: 'Örn: Güneşli, 25C',
            controller: _weatherController,
            onChanged: (val) {
                 ref.read(wizardReportProvider.notifier).update((state) {
                   return _copyReport(state)..weather = val;
                });
            },
          ),
        ],
      ),
    );
  }
}

class _StepWorkLog extends ConsumerStatefulWidget {
  const _StepWorkLog();
  @override
  ConsumerState<_StepWorkLog> createState() => _StepWorkLogState();
}

class _StepWorkLogState extends ConsumerState<_StepWorkLog> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final report = ref.read(wizardReportProvider);
    _noteController = TextEditingController(text: report.generalNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
           Text('Yapılan İşler (Log)', style: Theme.of(context).textTheme.titleLarge),
           const Gap(16),
           Expanded(
             child: CustomTextField(
               label: 'Bugün neler yapıldı?',
               maxLines: 10,
               hint: '- A Blok beton döküldü\n- B Blok duvar örümü başladı...',
               controller: _noteController,
               onChanged: (val) {
                 ref.read(wizardReportProvider.notifier).update((state) {
                   return _copyReport(state)..generalNote = val;
                 });
               },
             ),
           ),
        ],
      ),
    );
  }
}

class _StepCrewAndResources extends ConsumerWidget {
  const _StepCrewAndResources();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _DynamicSection(title: 'Ekip Bilgileri', category: 'crew', icon: Icons.people),
          const Gap(24),
          _DynamicSection(title: 'Malzeme ve Kaynaklar', category: 'resource', icon: Icons.inventory_2),
        ],
      ),
    );
  }
}

class _DynamicSection extends ConsumerWidget {
  final String title;
  final String category;
  final IconData icon;

  const _DynamicSection({required this.title, required this.category, required this.icon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(wizardReportProvider);
    final items = report.items.where((i) => i.category == category).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const Gap(8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: () {
                ref.read(wizardReportProvider.notifier).update((state) {
                  final newItems = List<ReportItem>.from(state.items);
                  newItems.add(ReportItem()..category = category..description = ''..quantity = null);
                  return _copyReport(state)..items = newItems;
                });
              },
            ),
          ],
        ),
          if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              children: [
                Icon(Icons.format_list_bulleted, size: 48, color: Colors.grey[300]),
                const Gap(8),
                Text('Henüz kayıt eklenmedi.', style: TextStyle(color: Colors.grey[600])),
                const Gap(8),
                Wrap(
                  spacing: 8,
                  children: (category == 'crew' 
                      ? ['Usta', 'Kalfa', 'İşçi'] 
                      : ['Çimento', 'Tuğla', 'Kum', 'Demir', 'Beton'])
                      .map((label) => ActionChip(
                    label: Text(label),
                    onPressed: () {
                        ref.read(wizardReportProvider.notifier).update((state) {
                          final newItems = List<ReportItem>.from(state.items);
                          newItems.add(ReportItem()..category = category..description = label..quantity = 1);
                          return _copyReport(state)..items = newItems;
                        });
                    },
                  )).toList(),
                )
              ],
            ),
          ),
        ...items.map((item) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: item.description,
                      decoration: const InputDecoration(labelText: 'Açıklama / İsim', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      onChanged: (val) {
                        item.description = val;
                        // No state update triggers here to avoid rebuild loops while typing in dynamic list
                      },
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      initialValue: item.quantity?.toString().replaceAll(RegExp(r'\.0$'), '') ?? '',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Adet', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                      onChanged: (val) => item.quantity = double.tryParse(val),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      ref.read(wizardReportProvider.notifier).update((state) {
                         final newItems = List<ReportItem>.from(state.items);
                         newItems.remove(item);
                         return _copyReport(state)..items = newItems;
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class _StepPhotos extends ConsumerStatefulWidget {
  const _StepPhotos();
  @override
  ConsumerState<_StepPhotos> createState() => _StepPhotosState();
}

class _StepPhotosState extends ConsumerState<_StepPhotos> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return;

      if (!mounted) return;
      
      final attachment = await showDialog<Attachment>(
        context: context,
        builder: (c) => _AttachmentDialog(imagePath: image.path),
      );

      if (attachment != null) {
        // Use Platform Helper to save file (or return blob path on web)
        final savedPath = await getPlatformFileHelper().saveReportPhoto(image.path);
        
        attachment.localPath = savedPath;
        attachment.takenAt = DateTime.now();

        ref.read(wizardReportProvider.notifier).update((state) {
            final newAttachments = List<Attachment>.from(state.attachments);
            newAttachments.add(attachment);
            return _copyReport(state)..attachments = newAttachments;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(wizardReportProvider);
    final attachments = report.attachments;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fotoğraflar / Kanıtlar', style: Theme.of(context).textTheme.titleLarge),
              PopupMenuButton<ImageSource>(
                icon: const Icon(Icons.add_a_photo, color: Colors.blue, size: 28),
                onSelected: _pickImage,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: ImageSource.camera, child: Row(children: [Icon(Icons.camera_alt), Gap(8), Text('Kamera')])),
                  const PopupMenuItem(value: ImageSource.gallery, child: Row(children: [Icon(Icons.photo_library), Gap(8), Text('Galeri')])),
                ],
              )
            ],
          ),
          const Gap(8),
          const Text('Rapora eklenecek şantiye görsellerini buradan yönetebilirsiniz.'),
          const Gap(16),
          
          Expanded(
            child: attachments.isEmpty 
             ? InkWell(
                 onTap: () async {
                    final source = await showModalBottomSheet<ImageSource>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Kamera'),
                              onTap: () => Navigator.pop(context, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Galeri'),
                              onTap: () => Navigator.pop(context, ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (source != null) _pickImage(source);
                 },
                 child: Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.add_a_photo_outlined, size: 64, color: Colors.grey[300]),
                       const Gap(16),
                       Text('Fotoğraf eklemek için dokunun', style: TextStyle(color: Colors.grey[600])),
                     ],
                   ),
                 ),
               )
             : GridView.builder(
                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                   crossAxisCount: 2, 
                   crossAxisSpacing: 12,
                   mainAxisSpacing: 12,
                   childAspectRatio: 0.8,
                 ),
                 itemCount: attachments.length,
                 itemBuilder: (context, index) {
                   final att = attachments[index];
                   return Card(
                     clipBehavior: Clip.antiAlias,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     child: Stack(
                       fit: StackFit.expand,
                       children: [
                         if (att.localPath != null)
                           PlatformImageImpl.create(path: att.localPath!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image)))
                         else 
                           const Center(child: Icon(Icons.broken_image)),
                         Positioned(
                           bottom: 0, left: 0, right: 0,
                           child: Container(
                             padding: const EdgeInsets.all(8),
                             decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 if (att.category != null)
                                   Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)), child: Text(att.category!, style: const TextStyle(color: Colors.white, fontSize: 10))),
                                 if (att.note != null && att.note!.isNotEmpty)
                                   Text(att.note!, style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                               ],
                             ),
                           ),
                         ),
                         Positioned(
                           top: 4, right: 4,
                           child: InkWell(
                             onTap: () {
                               ref.read(wizardReportProvider.notifier).update((state) {
                                  final newAttachments = List<Attachment>.from(state.attachments);
                                  newAttachments.removeAt(index);
                                  return _copyReport(state)..attachments = newAttachments;
                               });
                             },
                             child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)),
                           ),
                         ),
                       ],
                     ),
                   );
                 },
               ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentDialog extends StatefulWidget {
  final String imagePath;
  const _AttachmentDialog({required this.imagePath});
  @override
  State<_AttachmentDialog> createState() => _AttachmentDialogState();
}

class _AttachmentDialogState extends State<_AttachmentDialog> {
  final _noteController = TextEditingController();
  final List<String> _categories = ['Öncesi', 'Sonrası', 'İş İlerleme', 'Sorun', 'Teslimat', 'İSG', 'Diğer'];
  String _selectedCategory = 'İş İlerleme';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fotoğraf Detayı'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16/9, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: PlatformImageImpl.create(path: widget.imagePath, fit: BoxFit.cover))),
            const Gap(16),
            const Text('Kategori:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Gap(8),
            Wrap(
              spacing: 8, runSpacing: 0,
              children: _categories.map((cat) {
                 final isSelected = _selectedCategory == cat;
                 return ChoiceChip(label: Text(cat), selected: isSelected, onSelected: (val) { setState(() => _selectedCategory = cat); });
              }).toList(),
            ),
            const Gap(16),
            TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Not / Açıklama', border: OutlineInputBorder()), maxLines: 2),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          onPressed: () {
            final attachment = Attachment()..localPath = widget.imagePath..category = _selectedCategory..note = _noteController.text;
            Navigator.pop(context, attachment);
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

class _StepSummary extends ConsumerWidget {
  const _StepSummary();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
     final report = ref.watch(wizardReportProvider);
     final isSubmissionChecked = ref.watch(wizardSubmissionProvider);

     return Padding(
       padding: const EdgeInsets.all(16),
       child: Column(
         children: [
           const Icon(Icons.assignment_turned_in, size: 80, color: Colors.blue),
           const Gap(16),
           Text('Önizleme & Onay', style: Theme.of(context).textTheme.headlineSmall),
           const Gap(24),
           
           Card(
             child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Column(
                 children: [
                   _SummaryRow('Tarih', DateFormat('dd.MM.yyyy').format(report.date)),
                   _SummaryRow('Vardiya', report.shift ?? '-'),
                   _SummaryRow('Hava', report.weather ?? '-'),
                   const Divider(),
                   _SummaryRow('Kalemler', '${report.items.length} adet'),
                   _SummaryRow('Fotoğraflar', '${report.attachments.length} adet'),
                 ],
               ),
             ),
           ),
           const Gap(24),
           
           // Submission Choice
           SwitchListTile(
             title: const Text('Raporu Onaya Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
             subtitle: const Text('Raporunuzu tamamladıktan sonra yöneticinize onaya gönderin. Gönderilmezse taslak olarak kaydedilir.'),
             value: isSubmissionChecked,
             onChanged: (val) {
               ref.read(wizardSubmissionProvider.notifier).state = val;
             },
             activeColor: Colors.blue,
           ),

           const Spacer(),
         ],
       ),
     );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

DailyReport _copyReport(DailyReport original) {
  return DailyReport()
    ..id = original.id
    ..projectId = original.projectId
    ..date = original.date
    ..shift = original.shift
    ..weather = original.weather
    ..generalNote = original.generalNote
    ..crewDescription = original.crewDescription
    ..resourceDescription = original.resourceDescription
    ..status = original.status
    ..createdBy = original.createdBy
    ..items = List.from(original.items)
    ..attachments = List.from(original.attachments)
    ..lastUpdatedAt = DateTime.now();
}
