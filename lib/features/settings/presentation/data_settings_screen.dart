import '../../../core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/share_stub.dart' if (dart.library.io) 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:isar/isar.dart';

import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/sync/data/models/outbox_item.dart';
import '../../../core/sync/data/repositories/sync_repository.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../../core/init/providers.dart'; // For isarProvider
import '../../../features/report/data/models/daily_report_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Storage Stats Provider
class StorageStatsNotifier extends StateNotifier<Map<String, String>> {
  final Ref ref;
  StorageStatsNotifier(this.ref) : super({'photos': 'Hesaplanıyor...', 'backups': 'Hesaplanıyor...'});

  Future<void> calculate() async {
    try {
      if (kIsWeb) { 
        state = {'photos': 'N/A', 'backups': 'N/A'};
        return;
      }

      // 1. Calculate Backups Size
      final dir = await getApplicationDocumentsDirectory();
      int backupBytes = 0;
      // Dynamic typing to avoid dart:io vs stub FileSystemEntity conflicts
      final List<dynamic> files = dir.listSync();
      for (var file in files) {
        if (file.path.endsWith('.isar')) {
           final fileLength = await (file as File).length();
           backupBytes += fileLength.toInt();
        }
      }

      // 2. Calculate Photos Size
      // Scan all reports for local paths
      int photoBytes = 0;
      final isar = await ref.read(isarProvider.future);
      if (isar != null) {
         final reports = await isar.dailyReports.where().findAll();
         for (var report in reports) {
            for (var att in report.attachments) {
               if (att.localPath != null) {
                  final f = File(att.localPath!);
                  if (f.existsSync()) {
                     photoBytes += await f.length();
                  }
               }
            }
         }
      }

      state = {
        'photos': _formatBytes(photoBytes),
        'backups': _formatBytes(backupBytes),
      };
    } catch (e) {
      debugPrint('Storage calc error: $e');
      state = {'photos': 'Hata', 'backups': 'Hata'};
    }
  }
  
  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (bytes > 0) ? (bytes.toString().length / 3).floor() : 0;
    // Just to be safe
    if (i >= suffixes.length) i = suffixes.length - 1; 
    
    // Manual log based calc approximation
    // log10(bytes)/log10(1024) is standard but let's stick to simple loop
    // Actually, simple division:
    double val = bytes.toDouble();
    int suffixIndex = 0;
    while (val >= 1024 && suffixIndex < suffixes.length - 1) {
      val /= 1024;
      suffixIndex++;
    }
    return '${val.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }
}

final storageStatsProvider = StateNotifierProvider<StorageStatsNotifier, Map<String, String>>((ref) {
  return StorageStatsNotifier(ref);
});

class DataSettingsScreen extends ConsumerWidget {
  const DataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final queueCountAsync = ref.watch(syncQueueProvider);
    final queueCount = queueCountAsync.valueOrNull ?? 0;
    final lastError = ref.watch(lastSyncErrorProvider);
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final syncSettings = ref.watch(syncSettingsProvider);
    
    // Load fresh stats safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _loadStorageStats(ref);
    });
    
    // Watch stats
    final storageStats = ref.watch(storageStatsProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Veri ve Senkronizasyon', showProjectChip: false, showSyncStatus: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. SYNC STATUS CARD AREA
          if (syncStatus == SyncStatus.error) ...[
             _ErrorCard(
               error: lastError ?? 'Bilinmeyen hata', 
               onRetry: () => _triggerSync(ref, isRetry: true)
             ),
             const Gap(16),
          ],
          
          _SyncStatusCard(
             status: syncStatus, 
             queueCount: queueCount,
             onSync: () => _triggerSync(ref),
          ),
          const Gap(24),

          // 2. DETAYLAR (Last Sync, Outbox)
          _SectionHeader(title: 'SENKRONİZASYON DETAYLARI'),
          _DetailRow(
            icon: Icons.access_time,
            label: 'Son Başarılı Senkron',
            value: lastSyncTime != null ? DateFormat('HH:mm:ss').format(lastSyncTime) : '-',
          ),
           InkWell(
             onTap: queueCount > 0 ? () => _showOutbox(context, ref) : null,
             borderRadius: BorderRadius.circular(8),
             child: _DetailRow(
               icon: Icons.outbox,
               label: 'Gönderilmeyi Bekleyen',
               value: '$queueCount işlem',
               isLink: queueCount > 0,
             ),
           ),
           
          const Gap(24),

          // 3. YEDEKLEME
          if (!kIsWeb) ...[
          _SectionHeader(title: 'YEDEKLEME'),
          _SettingsActionTile(
            icon: Icons.save_alt,
            title: 'Cihaza Yedek Al',
            subtitle: 'Veritabanını yerel olarak kaydet',
            onTap: () => _handleBackup(context, ref),
          ),
          _SettingsActionTile(
            icon: Icons.settings_backup_restore,
            title: 'Yedekten Geri Yükle',
            subtitle: 'Yerel yedek dosyasını seç',
            isDangerous: true,
            onTap: () => _handleRestore(context, ref),
          ),
          const Gap(24),
          ],

          // 4. ONARIM & BAKIM
          _SectionHeader(title: 'BAKIM'),
          _SettingsActionTile(
            icon: Icons.sync_problem, 
            title: 'Senkronizasyon Sorunlarını Tara',
            subtitle: 'Gönderilmeyen verileri bul ve kuyruğa ekle',
            onTap: () => _handleScanUnsynced(context, ref),
          ),
          _SettingsActionTile(
            icon: Icons.delete_sweep,
            title: 'Tüm Verileri Sil ve Çık',
            subtitle: 'Uygulamayı fabrika ayarlarına döndür',
            isDangerous: true,
            onTap: () => _handleResetApp(context, ref),
          ),
          const Gap(24),

          // 5. DEPOLAMA
          _SectionHeader(title: 'DEPOLAMA'),
          _StorageStatsRow(
             photosSize: storageStats['photos'] ?? 'Hesaplanıyor...',
             backupsSize: storageStats['backups'] ?? 'Hesaplanıyor...',
          ),
          const Gap(8),
          _SettingsActionTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Önbelleği Temizle',
            subtitle: 'Resim önbelleğini silerek yer aç',
             onTap: () => _handleClearCache(context),
          ),
          const Gap(8),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.wifi, color: Colors.grey),
            ),
            title: const Text('Sadece Wi-Fi ile Senkron', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Mobil veride fotoğraf yüklenmez.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            trailing: Switch(
              value: syncSettings.onlyWifi, 
              onChanged: (val) {
                 ref.read(syncSettingsProvider.notifier).setOnlyWifi(val);
              },
            ),
          ),
          
          if (syncStatus == SyncStatus.offline)
             Padding(
                padding: const EdgeInsets.only(top: 8, left: 56),
                child: Text('Cihaz çevrimdışı olduğunda senkronizasyon durdurulur.', style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
             ),
        ],
      ),
    );
  }

  Future<void> _loadStorageStats(WidgetRef ref) async {
     // Trigger calculation
     ref.read(storageStatsProvider.notifier).calculate();
  }

  Future<void> _triggerSync(WidgetRef ref, {bool isRetry = false}) async {
    final status = ref.read(syncStatusProvider);
    if (status == SyncStatus.syncing) return; // Already syncing

    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    ref.read(lastSyncErrorProvider.notifier).state = null;

    try {
      final repo = ref.read(syncRepositoryProvider);
      final lastSync = ref.read(lastSyncTimeProvider);

      // 1. Push Local Changes
      await repo.processOutbox();

      // 2. Pull Remote Changes
      await repo.pullChanges(lastSync);

      // 3. Sync Meta (Plan, Policies)
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.getCurrentUser();
      if (user != null) {
          await authRepo.refreshOrganizationFromSupabase(user.currentOrgId);
      }

      // 3. Update Sync State
      ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
      ref.read(lastSyncTimeProvider.notifier).state = DateTime.now();
      
      // Refresh global providers if needed (usually streams handle this)
    } catch (e) {
      debugPrint('Sync Error: $e');
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      ref.read(lastSyncErrorProvider.notifier).state = e.toString();
    }
  }

  Future<void> _handleBackup(BuildContext context, WidgetRef ref) async {
    if (kIsWeb) return; // Not supported
    try {
      final isar = await ref.read(isarProvider.future);
      if (isar == null) throw Exception('Veritabanı başlatılmamış');

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'puantajx_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.isar';
      final backupPath = '${dir.path}/$fileName';
      
      // 1. Isar veritabanını geçici dizine kopyala
      await isar.copyToFile(backupPath);
      
      String? savedPath;

      // 2. Android Downloads klasörüne kopyalamayı dene
      if (Platform.isAndroid) {
         try {
           final downloadDir = Directory('/storage/emulated/0/Download');
           if (await downloadDir.exists()) {
              final newPath = '${downloadDir.path}/$fileName';
              await File(backupPath).copy(newPath);
              savedPath = newPath;
           }
         } catch (e) {
           debugPrint('Downloads klasörüne kopyalanamadı: $e');
         }
      }

      if (context.mounted) {
         if (savedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Yedek eklendi: İndirilenler/$fileName'), 
              backgroundColor: Colors.green
            ));
         }

         // 3. Paylaşım penceresini aç
         await Share.shareXFiles([XFile(backupPath)], text: 'PuantajX Veritabanı Yedeği');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yedekleme Hatası: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleRestore(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ DİKKAT: Veri Kaybı Riski'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yedekten geri yükleme işlemi, cihazdaki MEVCUT TÜM VERİLERİ SİLER ve yedek dosyasındaki verileri yazar.'),
            Gap(16),
            Text('Bu işlem geri alınamaz.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await _performRestore(context, ref);
            },
            child: const Text('SİL VE YÜKLE'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _performRestore(BuildContext context, WidgetRef ref) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // TODO: Real restore logic involves closing the current Isar instance, 
        // replacing the file, and reopening it. 
        // Since Isar instance is managed globally, this usually requires an app restart mechanism.
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Geri yükleme için uygulamanın yeniden başlatılması gerekecek. (Bu özellik şimdilik devre dışı)'), 
          duration: Duration(seconds: 4)
        ));
        
        // Pseudo code for restore:
        // final isar = await ref.read(isarProvider.future);
        // await isar!.close();
        // await file.copy(isarPath);
        // Restart app...

      } 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Geri Yükleme Hatası: $e'), backgroundColor: Colors.red));
    }
  }
  
  Future<void> _handleScanUnsynced(BuildContext context, WidgetRef ref) async {
      try {
        final count = await ref.read(syncRepositoryProvider).queueUnsyncedData();
        if(context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('$count adet veri kuyruğa eklendi.'), 
             backgroundColor: Colors.green
           ));
        }
        ref.invalidate(syncQueueProvider); 
      } catch (e) {
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
  }

  Future<void> _handleResetApp(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tüm Verileri Sil?'),
        content: const Text('Bu işlem cihazdaki tüm verileri silecek ve çıkış yapacaktır. Onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
          TextButton(
             onPressed: () => Navigator.pop(c, true), 
             child: const Text('EVET, SİL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
       try {
         final isar = await ref.read(isarProvider.future);
         await isar?.writeTxn(() async => await isar.clear());
         await ref.read(authRepositoryProvider).logout();
         
         // Router should auto-redirect if watching auth state
       } catch (e) {
          debugPrint('Reset Error: $e');
       }
    }
  }

  void _handleClearCache(BuildContext context) {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resim önbelleği temizlendi.')));
  }

  void _showOutbox(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _OutboxSheet(ref: ref),
    );
  }
}

class _OutboxSheet extends ConsumerWidget {
  final WidgetRef ref;
  const _OutboxSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(outboxListProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: const Center(child: Text('Bekleyen İşlemler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ),
            Expanded(
              child: listAsync.when(
                data: (items) {
                  if (items.isEmpty) return const Center(child: Text('Bekleyen işlem yok.'));
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final desc = _getDesc(item);
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.upload, color: Colors.white, size: 16)),
                        title: Text(desc),
                        subtitle: Text(DateFormat('HH:mm:ss').format(item.createdAt)),
                        trailing: item.retryCount > 0 ? Text('${item.retryCount} deneme', style: const TextStyle(fontSize: 12, color: Colors.red)) : null,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getDesc(OutboxItem item) {
    if (item.entityType == 'REPORT') return 'Rapor Gönderimi';
    if (item.entityType == 'ATTACHMENT') return 'Dosya Yükleme';
    if (item.entityType == 'ATTENDANCE') return 'Puantaj Güncellemesi';
    return '${item.entityType} - ${item.operation}';
  }
}


class _SyncStatusCard extends StatelessWidget {
  final SyncStatus status;
  final int queueCount;
  final VoidCallback onSync;
  
  const _SyncStatusCard({required this.status, required this.queueCount, required this.onSync});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String text;
    String subtext;
    String btnText;
    bool btnEnabled = true;

    switch(status) {
      case SyncStatus.synced:
        color = Colors.green;
        icon = Icons.check_circle; // Solid check
        text = 'Senkronize';
        subtext = 'Tüm verileriniz güncel.';
        btnText = 'Şimdi Senkronla';
        break;
      case SyncStatus.syncing:
        color = Colors.blue;
        icon = Icons.sync;
        text = 'Senkronize Ediliyor';
        subtext = 'Veriler buluta yükleniyor ($queueCount)...';
        btnText = 'İşleniyor...';
        btnEnabled = false;
        break;
      case SyncStatus.offline:
        color = Colors.orange;
        icon = Icons.cloud_off;
        text = 'Çevrimdışı Mod';
        subtext = 'İnternet bağlantısı bekleniyor.';
        btnText = 'Bağlantı Yok';
        btnEnabled = false;
        break;
      case SyncStatus.error:
        color = Colors.red; 
        icon = Icons.warning_amber; 
        text = 'Hata Durumu';
        subtext = 'Hatayı yukarıda kontrol edin.';
        btnText = 'Tekrar Dene';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withAlpha(20), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 48),
          ),
          const Gap(16),
          Text(text, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const Gap(4),
          Text(subtext, style: TextStyle(color: color.withAlpha(200), fontSize: 14)),
          const Gap(24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: btnEnabled ? onSync : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(btnText),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const Gap(12),
              const Text('Senkronizasyon Hatası', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: onRetry, 
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tekrar Dene'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              )
            ],
          ),
          const Gap(8),
          const Text('Son işlem sırasında bir hata oluştu:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const Gap(4),
          Text(error, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
          const Gap(12),
          Text('Hata devam ederse internet bağlantınızı kontrol edin veya destek ile iletişime geçin.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _StorageStatsRow extends StatelessWidget {
  final String photosSize;
  final String backupsSize;
  const _StorageStatsRow({required this.photosSize, required this.backupsSize});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: _StatItem(label: 'Fotoğraflar', value: photosSize, color: Colors.blue)),
          const SizedBox(width: 16),
          Expanded(child: _StatItem(label: 'Yedekler', value: backupsSize, color: Colors.purple)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const Gap(4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLink;

  const _DetailRow({required this.icon, required this.label, required this.value, this.isLink = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const Gap(12),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isLink ? Colors.blue : Colors.indigo)),
          if (isLink) ...[
             const Gap(4),
             const Icon(Icons.chevron_right, size: 16, color: Colors.blue),
          ]
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDangerous;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
       contentPadding: const EdgeInsets.symmetric(horizontal: 0),
       leading: Container(
         padding: const EdgeInsets.all(8),
         decoration: BoxDecoration(color: isDangerous ? Colors.red.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
         child: Icon(icon, color: isDangerous ? Colors.red : Colors.indigo),
       ),
       title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
       subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
       trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
    );
  }
}
