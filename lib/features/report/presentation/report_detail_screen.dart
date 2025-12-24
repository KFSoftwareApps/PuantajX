import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import '../../../core/widgets/platform_image.dart'; // New Import
import '../../../core/utils/platform/platform_file_helper.dart'; // New Import
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:uuid/uuid.dart';
import '../../../core/utils/share_stub.dart' if (dart.library.io) 'package:share_plus/share_plus.dart';

import '../../project/presentation/providers/active_project_provider.dart';
import '../../project/presentation/providers/project_providers.dart';
import '../../auth/data/repositories/auth_repository.dart'; // Fixed import
import '../../../core/services/sync_service.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/utils/file_download_helper.dart';
import '../data/models/daily_report_model.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/widgets/permission_guard.dart';
import '../../../core/widgets/locked_feature_placeholder.dart';
import '../../../core/providers/global_providers.dart'; // for exportSettingsProvider
import '../../../core/subscription/subscription_providers.dart'; // for hasEntitlementProvider
import '../../../core/subscription/plan_config.dart'; // for Entitlement
import 'providers/report_providers.dart';
import '../data/repositories/report_repository.dart'; // Fixed import
import 'share_report_dialog.dart';
import '../../payment/presentation/paywall_screen.dart'; // Import PaywallContent

class ReportDetailScreen extends ConsumerWidget {
  final int reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportByIdProvider(reportId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapor Detayı'),
        actions: [
          PermissionGuard(
            permission: AppPermission.reportDelete,
            child: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Raporu Sil'),
                    content: const Text(
                        'Bu rapor kalıcı olarak silinecektir. Onaylıyor musunuz?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () async {
                          final projectId = reportAsync.value?.projectId;
                          
                          await ref
                              .read(reportRepositoryProvider)
                              .deleteReport(reportId);
                          
                          if (projectId != null) {
                             ref.invalidate(projectReportsProvider(projectId));
                          }

                          if (context.mounted) {
                            Navigator.pop(context); // Close dialog
                            if (context.canPop()) context.pop(); // Close screen
                          }
                        },
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              showDialog(context: context, builder: (_) => ShareReportDialog(reportId: reportId));
            },
          ),
        ],
      ),
      body: reportAsync.when(
        data: (report) {
          if (report == null) return const Center(child: Text('Rapor bulunamadı.'));
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Section
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report.status).withOpacity(0.1),
                    border: Border.all(color: _getStatusColor(report.status)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: _getStatusColor(report.status)),
                      const Gap(12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Durum: ${() {
                            switch (report.status) {
                              case ReportStatus.draft: return 'TASLAK';
                              case ReportStatus.submitted: return 'ONAY BEKLİYOR';
                              case ReportStatus.approved: return 'ONAYLANDI';
                              case ReportStatus.rejected: return 'REDDEDİLDİ';
                              case ReportStatus.locked: return 'KİLİTLİ';
                            }
                          }()}', style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(report.status))),
                          if (report.approvedBy != null) Text('Onaylayan: ${report.approvedBy}', style: const TextStyle(fontSize: 12)),
                          if (report.status == ReportStatus.rejected && report.rejectionNote != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Not: ${report.rejectionNote}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.red)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                _DetailRow(label: 'Tarih', value: DateFormat('dd.MM.yyyy').format(report.date)),
                const Divider(height: 32),
                
                Text('Yapılan İşler', style: Theme.of(context).textTheme.titleLarge),
                const Gap(8),
                Text(report.generalNote ?? '-'),

                const Divider(height: 32),
                
                // Items
                Text('Detaylı Kalemler', style: Theme.of(context).textTheme.titleLarge),
                const Gap(8),
                if (report.items.isEmpty) const Text('Kalem girilmemiş', style: TextStyle(color: Colors.grey)),
                ...report.items.map((item) => Card(
                     child: ListTile(
                       leading: Icon(item.category == 'crew' ? Icons.people : Icons.inventory_2),
                       title: Text(item.description ?? '-'),
                       trailing: Text('${item.quantity?.toString() ?? '-'} ${item.unit ?? ""}'),
                     ),
                )),
                
                const Divider(height: 32),
                
                // Photos
                 Row(
                   children: [
                     Text('Fotoğraflar / Kanıtlar (${report.attachments.length})', style: Theme.of(context).textTheme.titleLarge),
                     const Spacer(),
                     IconButton(
                       icon: Icon(Icons.add_circle, color: (report.status == ReportStatus.draft || report.status == ReportStatus.submitted) ? Colors.blue : Colors.grey),
                       onPressed: (report.status == ReportStatus.draft || report.status == ReportStatus.submitted) ? () => _pickAndAddPhoto(context, ref, report) : null,
                     ),
                   ],
                 ),
                 
                 const Gap(16),
                 if (report.attachments.isEmpty) 
                      const Text('Henüz fotoğraf yok. Eklemek için + butonuna basın.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                 else
                   GridView.builder(
                     shrinkWrap: true,
                     physics: const NeverScrollableScrollPhysics(),
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 3,
                       mainAxisSpacing: 8,
                       crossAxisSpacing: 8,
                     ),
                     itemCount: report.attachments.length,
                     itemBuilder: (context, index) => _PhotoCard(attachment: report.attachments[index]),
                   ),
                   
                   const Gap(80),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
      bottomNavigationBar: reportAsync.value != null ? _buildBottomBar(context, ref, reportAsync.value!) : null,
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
  
  String _getStatusText(ReportStatus status) {
      switch (status) {
        case ReportStatus.draft:
          return 'Taslak';
        case ReportStatus.submitted:
          return 'Onay Bekliyor';
        case ReportStatus.approved:
          return 'Onaylandı';
        case ReportStatus.rejected:
          return 'Reddedildi';
        case ReportStatus.locked:
          return 'Kilitli';
      }
    }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref, DailyReport report) {
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,-2))]),
       child: SafeArea(
         child: Row(
           mainAxisAlignment: MainAxisAlignment.end,
           children: [
             if (report.status == ReportStatus.draft) ...[
                PermissionGuard(
                  permission: AppPermission.reportUpdate,
                  fallback: const Spacer(),
                  child: Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Düzenle'),
                      onPressed: () {
                        context.push('/reports/edit', extra: report);
                      },
                    ),
                  ),
                ),
                const Gap(12),
                PermissionGuard(
                   permission: AppPermission.reportSubmit,
                   fallback: const Spacer(),
                   child: Expanded(
                     child: ElevatedButton.icon(
                       icon: const Icon(Icons.send),
                       label: const Text('Onaya Gönder'),
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                       onPressed: () => _showConfirmation(context, 'Raporu onaya göndermek istiyor musunuz?', () => _updateStatus(context, ref, report, ReportStatus.submitted)),
                     ),
                   ),
                ),
             ]
             else if (report.status == ReportStatus.submitted) ...[
                PermissionGuard(
                  permission: AppPermission.reportApprove,
                  fallback: const Spacer(), // Maintain layout balance if possible, or just hide
                  child: Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Reddet', style: TextStyle(color: Colors.red)),
                      onPressed: () => _showRejectionDialog(context, ref, report),
                    ),
                  ),
                ),
                const Gap(12),
                PermissionGuard(
                   permission: AppPermission.reportApprove,
                   fallback: const Spacer(),
                   child: Expanded(
                     child: ElevatedButton.icon(
                       icon: const Icon(Icons.check_circle),
                       label: const Text('Onayla'),
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                       onPressed: () => _updateStatus(context, ref, report, ReportStatus.approved),
                     ),
                   ),
                ),
             ]
             else if (report.status == ReportStatus.rejected) ...[
                PermissionGuard(
                  permission: AppPermission.reportUpdate,
                  fallback: const Spacer(),
                  child: Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Düzenle'),
                      onPressed: () {
                        context.push('/reports/edit', extra: report);
                      },
                    ),
                  ),
                ),
                const Gap(12),
                PermissionGuard(
                   permission: AppPermission.reportSubmit,
                   fallback: const Spacer(),
                   child: Expanded(
                     child: ElevatedButton.icon(
                       icon: const Icon(Icons.refresh),
                       label: const Text('Tekrar Gönder'),
                       onPressed: () => _updateStatus(context, ref, report, ReportStatus.submitted),
                     ),
                   ),
                ),
             ] 
             // APPROVED Actions
             else if (report.status == ReportStatus.approved) ...[
               // PDF
               Expanded(
                 child: OutlinedButton.icon(
                   icon: const Icon(Icons.picture_as_pdf),
                   label: const Text('PDF'),
                   onPressed: () async { 
                     // CHECK PREMIUM FOR PDF
                     final hasPremium = await ref.read(hasEntitlementProvider(Entitlement.excelExport).future); // Using same entitlement for now
                     if (!hasPremium) {
                        if (context.mounted) {
                          final shouldUpgrade = await _showPremiumDialog(context, 'PDF İndir', 'PDF formatında rapor indirmek için Premium plana geçiniz.');
                          if (shouldUpgrade == true && context.mounted) {
                             // Use ModalBottomSheet instead of push to avoid Navigator crash
                             showModalBottomSheet(
                               context: context,
                               isScrollControlled: true, // Allow full height if needed
                               useSafeArea: true,
                               builder: (context) => const PaywallContent(isDialog: true),
                             );
                          }
                        }
                        return;
                     }

                     final settings = ref.read(exportSettingsProvider);
                     final project = await ref.read(projectByIdProvider(report.projectId).future);
                     if (project == null || !context.mounted) return;
                     
                     // Show Action Sheet (Share or Download)
                     showModalBottomSheet(
                       context: context,
                       builder: (context) => SafeArea(
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             ListTile(
                               leading: const Icon(Icons.share),
                               title: const Text('Paylaş'),
                               onTap: () async {
                                 Navigator.pop(context);
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF Hazırlanıyor...')));
                                 try {
                                   await PdfExportService().shareDailyReportPdf(report, project, settings);
                                 } catch (e) {
                                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                                 }
                               },
                             ),
                             ListTile(
                               leading: const Icon(Icons.download),
                               title: const Text('Cihaza Kaydet'),
                               onTap: () async {
                                 Navigator.pop(context);
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF İndiriliyor...')));
                                 try {
                                   final bytes = await PdfExportService().generateDailyReportPdf(report, project, settings);
                                   if (context.mounted) {
                                     await FileDownloadHelper.saveAndNotify(
                                       context, 
                                       bytes, 
                                       'rapor_${report.id}.pdf'
                                     );
                                   }
                                 } catch (e) {
                                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                                 }
                               },
                             ),
                           ],
                         ),
                       ),
                     );
                   },
                 ),
               ),
               const Gap(8),
               // Excel
               Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.table_view, color: Colors.green),
                    label: const Text('Excel'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green.shade700),
                    onPressed: () async {
                       // CHECK PREMIUM FOR EXCEL
                        final hasExcel = await ref.read(hasEntitlementProvider(Entitlement.excelExport).future);
                        if (!hasExcel) {
                          if (context.mounted) {
                            final shouldUpgrade = await _showPremiumDialog(context, 'Excel İndir', 'Excel formatında rapor indirmek için Premium plana geçiniz.');
                            if (shouldUpgrade == true && context.mounted) {
                                // Use ModalBottomSheet instead of push to avoid Navigator crash
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  builder: (context) => const PaywallContent(isDialog: true),
                                );
                            }
                          }
                          return;
                        }

                        if(!context.mounted) return;

                        final project = await ref.read(projectByIdProvider(report.projectId).future);
                        if (project == null || !context.mounted) return;

                        showModalBottomSheet(
                          context: context,
                          builder: (context) => SafeArea(
                             child: Column(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 ListTile(
                                   leading: const Icon(Icons.share),
                                   title: const Text('Paylaş'),
                                   onTap: () async {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Hazırlanıyor...')));
                                      try {
                                        final bytes = await ExcelExportService.generateDailyReportExcel(report, project);
                                        if (kIsWeb) {
                                           final xfile = XFile.fromData(Uint8List.fromList(bytes), mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: 'rapor_${report.id}.xlsx');
                                           await Share.shareXFiles([xfile], text: 'Günlük Rapor Excel');
                                        } else {
                                          final temp = await getTemporaryDirectory();
                                          final file = File('${temp.path}/rapor_${report.id}.xlsx');
                                          await file.writeAsBytes(bytes);
                                          await Share.shareXFiles([XFile(file.path)], text: 'Günlük Rapor Excel');
                                        }
                                      } catch (e) {
                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                                      }
                                   },
                                 ),
                                 ListTile(
                                   leading: const Icon(Icons.download),
                                   title: const Text('Cihaza Kaydet'),
                                   onTap: () async {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel İndiriliyor...')));
                                      try {
                                        final bytes = await ExcelExportService.generateDailyReportExcel(report, project);
                                        if (context.mounted) {
                                           await FileDownloadHelper.saveAndNotify(context, bytes, 'rapor_${report.id}.xlsx');
                                        }
                                      } catch (e) {
                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                                      }
                                   },
                                 ),
                               ]
                             )
                          )
                        );
                    },
                  ),
               ),
             ]
           ],
         ),
       ),
     );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, DailyReport report, ReportStatus newStatus) async {
    try {
      final updated = report.copyWith(
        status: newStatus, 
        lastUpdatedAt: DateTime.now(),
        approvedBy: newStatus == ReportStatus.approved ? ref.read(authControllerProvider).valueOrNull?.fullName : null,
      );
      // FORCE SYNC: Mark as unsynced so SyncService picks it up
      updated.isSynced = false;
      
      await ref.read(reportRepositoryProvider).updateReport(updated);
      ref.invalidate(reportByIdProvider(report.id)); 
      ref.invalidate(projectReportsProvider(report.projectId)); 
      
      // Trigger sync
      ref.read(syncServiceProvider).triggerSync(); 
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Durum güncellendi: ${_getStatusText(newStatus)}')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _pickAndAddPhoto(BuildContext context, WidgetRef ref, DailyReport report) async {
    final picker = ImagePicker();
    
    // Show Source Selection
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

    if (source == null) return;

    try {
      final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return;
      
      if (!context.mounted) return;
      final attachment = await showDialog<Attachment>(
        context: context, 
        builder: (_) => _DetailAttachmentDialog(imagePath: image.path)
      );

      if (attachment != null) {
        // Use Platform Helper to save file (or return blob path on web)
        final savedPath = await getPlatformFileHelper().saveReportPhoto(image.path);
        
        // Update attachment with local path and ID (if not set in dialog, but I set ID in dialog)
        attachment.localPath = savedPath;
        
        final updatedReport = report.copyWith(
          attachments: [...report.attachments, attachment],
          lastUpdatedAt: DateTime.now(),
        );
        
        await ref.read(reportRepositoryProvider).updateReport(updatedReport);
        ref.invalidate(reportByIdProvider(report.id));
        ref.invalidate(projectReportsProvider(report.projectId));
        
        ref.read(syncServiceProvider).syncAll();
        
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf eklendi')));
        }
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _showConfirmation(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(onPressed: () { Navigator.pop(context); onConfirm(); }, child: const Text('Evet')),
        ],
      ),
    );
  }

  void _showRejectionDialog(BuildContext context, WidgetRef ref, DailyReport report) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Raporu Reddet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bu raporu neden reddediyorsunuz?'),
            const Gap(8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Red sebebi / Revizyon notu...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (controller.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir not girin.')));
                return;
              }
              
              Navigator.pop(c);
              
              try {
                final updated = report.copyWith(
                  status: ReportStatus.rejected,
                  rejectionNote: controller.text,
                  lastUpdatedAt: DateTime.now(),
                );
                // FORCE SYNC
                updated.isSynced = false;
                
                ref.read(reportRepositoryProvider).updateReport(updated);
                ref.invalidate(reportByIdProvider(report.id));
                ref.invalidate(projectReportsProvider(report.projectId));
                ref.read(syncServiceProvider).triggerSync();
                
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapor reddedildi')));
              } catch (e) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
              }
            }, 
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPremiumDialog(BuildContext context, String title, String description) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
             const Icon(Icons.workspace_premium, color: Colors.amber),
             const Gap(8),
             Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false), // Return false
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
            onPressed: () {
               Navigator.pop(dialogContext, true); // Return true to signal upgrade
            },
            child: const Text('Paketi Yükselt'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final Attachment attachment;
  const _PhotoCard({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        children: [
           if (attachment.localPath != null)
             PlatformImageImpl.create(path: attachment.localPath!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image)))
           else
             const Center(child: Icon(Icons.image_not_supported)),
           
           // Overlay (Note + Category)
           Positioned(
             bottom: 0, left: 0, right: 0,
             child: Container(
               padding: const EdgeInsets.all(8),
               color: Colors.black54,
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    if(attachment.category != null)
                      Text(attachment.category!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    if(attachment.note != null && attachment.note!.isNotEmpty)
                      Text(attachment.note!, style: const TextStyle(color: Colors.white70, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                 ],
               ),
             ),
           ),
           
           // Status Indicator
           Positioned(
             top: 4, left: 4,
             child: _StatusBadge(isSynced: attachment.remoteUrl != null),
           ),
           
           // Zoom Action
           Positioned(
             top: 4, right: 4,
             child: InkWell(
               onTap: () => _showFullImage(context, attachment),
               child: Container(
                 padding: const EdgeInsets.all(4),
                 decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                 child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
               ),
             ),
           ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, Attachment att) {
    if (att.localPath == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
             InteractiveViewer(
               child: PlatformImageImpl.create(path: att.localPath!),
             ),
             Positioned(
               top: 10, right: 10,
               child: IconButton(
                 icon: const Icon(Icons.close, color: Colors.white, size: 30),
                 onPressed: () => Navigator.pop(context),
               ),
             ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isSynced;
  const _StatusBadge({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    if (isSynced) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
        child: const Icon(Icons.cloud_done, color: Colors.white, size: 14),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
      child: const Icon(Icons.cloud_upload, color: Colors.white, size: 14),
    );
  }
}

class _DetailAttachmentDialog extends StatefulWidget {
  final String imagePath;
  const _DetailAttachmentDialog({required this.imagePath});
  @override
  State<_DetailAttachmentDialog> createState() => _DetailAttachmentDialogState();
}

class _DetailAttachmentDialogState extends State<_DetailAttachmentDialog> {
  final _noteController = TextEditingController();
  String _selectedCategory = 'İş İlerleme';
  final List<String> _categories = ['Öncesi', 'Sonrası', 'İş İlerleme', 'Sorun', 'Teslimat', 'İSG', 'Diğer'];

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
                 return ChoiceChip(
                   label: Text(cat), 
                   selected: isSelected, 
                   onSelected: (val) { if(val) setState(() => _selectedCategory = cat); }
                 );
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
            final attachment = Attachment(
              id: const Uuid().v4(), // Fix: Provide ID
              type: 'photo', // Fix: Provide Type
              category: _selectedCategory,
              note: _noteController.text,
              localPath: widget.imagePath,
              takenAt: DateTime.now(),
            );
            Navigator.pop(context, attachment);
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
