import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../../core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:path_provider/path_provider.dart'; // Added
import '../../../core/utils/share_stub.dart' if (dart.library.io) 'package:share_plus/share_plus.dart'; // Added
import 'package:puantaj_x/core/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../auth/data/repositories/auth_repository.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/types/app_types.dart';
import '../../../core/subscription/subscription_providers.dart';
import '../../../core/subscription/plan_config.dart';
import '../../../core/providers/global_providers.dart';
import '../../settings/presentation/legal_screens.dart';

// Added for Sync Logic
import '../../../core/services/sync_service.dart';
import '../../../core/init/providers.dart';
import 'package:isar/isar.dart';
import '../../project/data/models/project_model.dart';
import '../../project/data/models/worker_model.dart';
import '../../project/data/models/project_worker_model.dart';
import '../../report/data/models/daily_report_model.dart';
import '../../../core/sync/data/models/outbox_item.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';
  int _debugTapCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = GoRouterState.of(context);
    if (state.uri.queryParameters['openDelete'] == 'true') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => const DeleteAccountDialog(),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    }
  }

  void _handleVersionTap() {
    setState(() => _debugTapCount++);
    if (_debugTapCount >= 5) {
      _showDebugMenu();
      setState(() => _debugTapCount = 0);
    }
  }

  void _showDebugMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🛠️ Geliştirici Menüsü', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            const Text('Abonelik Planını Zorla', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const Gap(8),
            ListTile(
              title: const Text('Free (Ücretsiz)'),
              onTap: () => _updatePlan(SubscriptionPlan.free),
              leading: const Icon(Icons.star_outline),
            ),
            ListTile(
              title: const Text('Pro'),
              onTap: () => _updatePlan(SubscriptionPlan.pro),
              leading: const Icon(Icons.star, color: Colors.blue),
            ),
             ListTile(
              title: const Text('Business'),
              onTap: () => _updatePlan(SubscriptionPlan.business),
              leading: const Icon(Icons.star, color: Colors.purple),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _exportData() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Paylaş'),
              subtitle: const Text('WhatsApp, Mail vb. ile gönder'),
              onTap: () {
                Navigator.pop(ctx);
                _processExport(share: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Cihaza Kaydet'),
              subtitle: const Text('İndirilenler klasörüne kaydet'),
              onTap: () {
                Navigator.pop(ctx);
                _processExport(share: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processExport({required bool share}) async {
    try {
      final data = await ref.read(authControllerProvider.notifier).exportUserData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      
      final fileName = 'user_data_${DateTime.now().millisecondsSinceEpoch}.json';

      if (share) {
        // SHARE LOGIC
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsString(jsonStr);

        if (!mounted) return;
        
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'PuantajX Veri Dökümü',
          text: 'Kişisel verileriniz ektedir.',
        );
      } else {
        // DOWNLOAD LOGIC
        if (Platform.isAndroid) {
           final directory = Directory('/storage/emulated/0/Download');
           // Fallback to getDownloadsDirectory if hardcoded path fails (though this is standard for user visibility)
            // Fallback to getDownloadsDirectory if hardcoded path fails
            // But permission might be needed. path_provider getDownloadsDirectory is safer.
            final dynamic safeDir = await getDownloadsDirectory() ?? directory;
            
            // Use dynamic to bypass web build strict type checking for File/Directory stubs
            final dynamic finalDir = Directory((safeDir as dynamic).path);
            if (!finalDir.existsSync()) {
              try { 
                finalDir.createSync(recursive: true); 
              } catch(_) {}
            }
            final path = '${safeDir.path}/$fileName';
            final file = File(path);
           await file.writeAsString(jsonStr);
           
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                 content: Text('Dosya kaydedildi: Download/$fileName'), 
                 backgroundColor: Colors.green,
                 duration: const Duration(seconds: 4),
               ),
             );
           }
        } else {
           // iOS etc -> Fallback to Share as "Save to Files" is in share sheet
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('iOS için lütfen "Paylaş" menüsünden "Dosyalara Kaydet" seçeneğini kullanın.')),
             );
             _processExport(share: true);
           }
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _updatePlan(SubscriptionPlan plan) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;
    
    Navigator.pop(context);
    
    final service = ref.read(subscriptionServiceProvider);
    await service.setOrgPlan(user.currentOrgId, plan);
    
    ref.invalidate(currentPlanProvider);
    ref.invalidate(canPerformActionProvider);
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text('Plan güncellendi: ${plan.name.toUpperCase()}'),
         backgroundColor: Colors.green,
       ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authControllerProvider);
    final user = userAsync.valueOrNull;
    final planAsync = ref.watch(currentPlanProvider);
    final usageAsync = ref.watch(currentUsageProvider);

    if (user == null) {
      if (userAsync.isLoading) {
         return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return Scaffold(
        appBar: const CustomAppBar(title: 'Ayarlar', showProjectChip: false, showSyncStatus: false),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const Gap(16),
              const Text('Oturum bilgisi alınamadı.', style: TextStyle(fontSize: 16)),
              const Gap(24),
              ElevatedButton(
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Giriş Ekranına Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final role = user.role;
    final isGuest = role == AppRole.guest;

    // GUEST VIEW
    if (isGuest) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Hakkında', showProjectChip: false, showSyncStatus: false),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'Uygulama Hakkında',
              subtitle: 'v$_version',
            ),
             _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Gizlilik Politikası',
              onTap: () {},
            ),
            const Gap(32),
            _LogoutButton(ref: ref),
          ],
        ),
      );
    }

    // Role Checks
    final isOwner = role == AppRole.owner;
    final isAdmin = role == AppRole.admin;
    final isFinance = role == AppRole.finance;
    
    // Visibility Flags
    final showOrg = isOwner || isAdmin;
    final showSub = isOwner || isAdmin || isFinance;
    final showData = !isGuest;
    
    return Scaffold(
      appBar: const CustomAppBar(title: 'Ayarlar', showProjectChip: false, showSyncStatus: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. PROFIL KARTI
          _ProfileCard(user: user),
          const Gap(16),

          // 2. ORGANIZASYON KARTI (Owner/Admin)
          if (showOrg) ...[
            _OrganizationCard(isOwner: isOwner, isAdmin: isAdmin),
            const Gap(16),
          ],

          // 3. ABONELİK KARTI (Owner/Admin/Finance)
          if (showSub) ...[
            _SubscriptionCard(
              config: Plans.getConfig(planAsync.valueOrNull?.plan ?? SubscriptionPlan.free),
              usage: usageAsync.valueOrNull ?? {},
              isOwner: isOwner,
              onManage: () => context.go('/settings/subscription'),
            ),
            const Gap(16),
          ],

          // 4. VERİ & SENKRON KARTI
          if (showData) ...[
             _DataSyncCard(
               onTap: () => context.go('/settings/data-sync'),
             ),
             const Gap(16),
          ],

          // 5. UYGULAMA AYARLARI
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text('UYGULAMA', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          ),

          _SettingsTile(
            icon: Icons.language,
            title: 'Dil / Language',
            subtitle: ref.watch(localeProvider).languageCode == 'tr' ? 'Türkçe' : 'English',
            onTap: () => _showLanguageSelector(context, ref),
          ),
          _SettingsTile(
            icon: Icons.notifications_none,
            title: 'Bildirimler',
            subtitle: 'Hatırlatıcı ve uyarılar',
            onTap: () => _showNotificationSettings(context, ref),
          ),
          const Gap(16),

          // 6. DESTEK & YASAL (Footer)
          const Divider(),
          _SettingsTile(
            icon: Icons.support_agent,
            title: 'Destek & İletişim',
            onTap: () => context.go('/settings/about'),
          ),
          
          if (isFinance || isOwner || isAdmin)
             _SettingsTile(
                icon: Icons.table_chart_outlined,
                title: 'Rapor Export Ayarları',
                onTap: () => _showExportSettings(context, ref),
             ),

          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Yasal (Gizlilik & KVKK)',
            onTap: () => context.go('/settings/privacy'),
          ),

          _SettingsTile(
            icon: Icons.download_outlined,
            title: 'Verilerimi İndir',
            subtitle: 'Kişisel verilerinizi al',
            onTap: _exportData,
          ),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Center(
              child: GestureDetector(
                onTap: _handleVersionTap, 
                child: Text('v$_version', style: TextStyle(color: Colors.grey[400], fontSize: 12))
              )
            ),
          ),

          const Gap(16),
          _LogoutButton(ref: ref),
          
          if (!isGuest) ...[
             const Gap(16),
             Center(
               child: TextButton(
                 onPressed: () {
                   showDialog(
                     context: context,
                     builder: (context) => const DeleteAccountDialog(),
                   );
                 },
                 child: Text('Hesabımı Sil', style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
               ),
             ),
          ],
          
          const Gap(32),
        ],
      ),
    );
  }



  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(8),
          Container(
            width: 40, height: 4, 
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          ListTile(
            leading: const Text('🇹🇷', style: TextStyle(fontSize: 24)),
            title: const Text('Türkçe'),
            onTap: () {
              ref.read(localeProvider.notifier).state = const Locale('tr', 'TR');
              context.pop();
            },
          ),
          ListTile(
            leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
            title: const Text('English'),
            onTap: () {
              ref.read(localeProvider.notifier).state = const Locale('en', 'US');
              context.pop();
            },
          ),
          const Gap(20),
        ],
      ),
    );
  }

  void _showNotificationSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final settings = ref.watch(notificationSettingsProvider);
          final notifier = ref.read(notificationSettingsProvider.notifier);
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, 
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Bildirim Tercihleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(16),
                SwitchListTile(
                  title: const Text('Rapor Hatırlatıcıları'),
                  subtitle: const Text('Gün sonu rapor girmeyi hatırlat'),
                  value: settings.reportReminder,
                  onChanged: (val) async {
                    notifier.state = settings.copyWith(reportReminder: val);
                    final service = ref.read(notificationServiceProvider);
                    if (val) {
                      await service.requestPermissions();
                      await service.scheduleReportReminder();
                    } else {
                      await service.cancelReportReminder();
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Onay İstekleri'),
                  subtitle: const Text('Yeni rapor veya izin isteklerinde bildir'),
                  value: settings.approvalRequest,
                  onChanged: (val) async {
                     notifier.state = settings.copyWith(approvalRequest: val);
                     if (val) await ref.read(notificationServiceProvider).requestPermissions();
                  },
                ),
                SwitchListTile(
                  title: const Text('Senkronizasyon Hataları'),
                  subtitle: const Text('Veri gönderilemediğinde uyar'),
                  value: settings.syncError,
                  onChanged: (val) async {
                     notifier.state = settings.copyWith(syncError: val);
                     if (val) await ref.read(notificationServiceProvider).requestPermissions();
                  },
                ),
                const Gap(20),
              ],
            ),
          );
        }
      ),
    );
  }

  void _showExportSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(exportSettingsProvider);
            final notifier = ref.read(exportSettingsProvider.notifier);
            
            // SUBSCRIPTION & ROLE CHECKS
            final planAsync = ref.watch(currentPlanProvider);
            final plan = planAsync.valueOrNull?.plan ?? SubscriptionPlan.free;
            final isProOrBusiness = plan == SubscriptionPlan.pro || plan == SubscriptionPlan.business;
            final isBusiness = plan == SubscriptionPlan.business;

            // Helper to show auto-save feedback
            void update(Function() action) {
              action();
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ayarlar kaydedildi ✅', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.green,
                  duration: Duration(milliseconds: 800),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            void showUpsell(String feature) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$feature için Pro plana geçin! 🚀'),
                  action: SnackBarAction(label: 'İncele', onPressed: () => context.push('/settings/subscription')),
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: scrollController,
                children: [
                   Center(
                    child: Container(
                      width: 40, height: 4, 
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const Gap(16),
                  
                  // LIVE PREVIEW CARD
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              settings.format == 'excel' ? Icons.table_chart : Icons.picture_as_pdf,
                              color: settings.format == 'excel' ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const Gap(8),
                            const Text('ÖNİZLEME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                          ],
                        ),
                        const Divider(),
                        const Gap(4),
                        // Simulated File Header
                        if (settings.includeHeader) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.business, size: 14, color: Colors.blue),
                              ),
                              const Gap(8),
                              const Text('My Construction Co.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const Gap(8),
                        ],
                        // Simulated Content Text
                        Text(
                          'Günlük Puantaj Raporu - 08.12.2025',
                          style: TextStyle(
                            fontSize: 14,
                            decoration: settings.format == 'pdf' && settings.pdfOrientation == 'landscape' ? TextDecoration.none : TextDecoration.none, // Just a trigger for redraw
                          ),
                        ),
                        const Gap(4),
                         Wrap(
                          spacing: 6,
                          children: [
                            _PreviewTag(
                              label: settings.detailLevel == 'detailed' ? 'Detaylı' : 'Özet',
                              color: Colors.orange,
                            ),
                            if (settings.format == 'pdf')
                              _PreviewTag(
                                label: settings.pdfOrientation == 'portrait' ? 'Dikey' : 'Yatay',
                                color: Colors.blueGrey,
                              ),
                            if (settings.includePhotos)
                              const _PreviewTag(
                                label: 'Fotoğraflar',
                                color: Colors.purple,
                                icon: Icons.camera_alt,
                              ),
                             if (settings.includeCosts)
                              const _PreviewTag(
                                label: 'Maliyet',
                                color: Colors.green,
                                icon: Icons.attach_money,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Gap(24),
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Colors.blue),
                      const Gap(12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rapor Export Ayarları', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                           Text('Çıktı formatını ve içeriğini özelleştirin', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const Gap(24),
                  
                  // 1. FORMAT
                  const Text('Varsayılan Format', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Gap(12),
                  Row(
                    children: [
                      Expanded(
                        child: _SelectionCard(
                          title: 'Excel (.xlsx)',
                          icon: Icons.table_chart,
                          color: isProOrBusiness ? Colors.green : Colors.grey, // Grey out if locked
                          isSelected: settings.format == 'excel',
                          isLocked: !isProOrBusiness,
                          onTap: () {
                             if (!isProOrBusiness) {
                               showUpsell('Excel Export');
                             } else {
                               update(() => notifier.updateSettings(format: 'excel'));
                             }
                          },
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: _SelectionCard(
                          title: 'PDF (.pdf)',
                          icon: Icons.picture_as_pdf,
                          color: Colors.red,
                          isSelected: settings.format == 'pdf',
                          onTap: () => update(() => notifier.updateSettings(format: 'pdf')),
                        ),
                      ),
                    ],
                  ),
                  const Gap(24),

                  // 2. CONTENT SCOPE
                  const Text('İçerik Kapsamı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Gap(8),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Detaylı Rapor'),
                          subtitle: const Text('Tüm kalemleri ve notları içerir'),
                          value: 'detailed',
                          groupValue: settings.detailLevel,
                          onChanged: (val) => update(() => notifier.updateSettings(detailLevel: val)),
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          title: const Text('Özet Rapor'),
                          subtitle: const Text('Sadece toplamları gösterir'),
                          value: 'summary',
                          groupValue: settings.detailLevel,
                          onChanged: (val) => update(() => notifier.updateSettings(detailLevel: val)),
                        ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(children: [
                      const Text('Fotoğrafları Dahil Et'),
                      if (!isProOrBusiness) ...[const Gap(8), const Icon(Icons.lock, size: 14, color: Colors.orange)],
                    ]),
                    subtitle: const Text('PDF boyutunu artırabilir'),
                    secondary: const Icon(Icons.camera_alt_outlined),
                    value: isProOrBusiness ? settings.includePhotos : false, // Force false if not pro
                    onChanged: (val) {
                      if (!isProOrBusiness) {
                         showUpsell('Fotoğraflı Rapor');
                      } else {
                         update(() => notifier.updateSettings(includePhotos: val));
                      }
                    },
                  ),

                   const Gap(24),

                  // 3. PDF SETTINGS
                  if (settings.format == 'pdf') ...[
                    const Text('PDF Ayarları', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Gap(12),
                     Row(
                      children: [
                        Expanded(
                          child: _SelectionCard(
                            title: 'Dikey',
                            icon: Icons.crop_portrait,
                            color: Colors.blueGrey,
                            isSelected: settings.pdfOrientation == 'portrait',
                            onTap: () => update(() => notifier.updateSettings(pdfOrientation: 'portrait')),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: _SelectionCard(
                            title: 'Yatay',
                            icon: Icons.crop_landscape,
                            color: Colors.blueGrey,
                            isSelected: settings.pdfOrientation == 'landscape',
                            onTap: () => update(() => notifier.updateSettings(pdfOrientation: 'landscape')),
                          ),
                        ),
                      ],
                    ),
                    const Gap(24),
                  ],
                  
                  // 4. HEADER & EXTRAS
                  const Text('Görünüm & Ekstralar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                   SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Şirket Başlığı'),
                    subtitle: const Text('Raporun tepesinde organizasyon bilgisi'),
                    secondary: const Icon(Icons.branding_watermark_outlined),
                    value: settings.includeHeader,
                    onChanged: (val) => update(() => notifier.updateSettings(includeHeader: val)),
                  ),
                  
                  // Finance Gating (Only Check Roles)
                  // Note: In real app, check role permissions. Assuming isAdmin/isOwner available in closure or passed.
                  // For now, simpler implementation:
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(children: [
                      const Text('Maliyet Verileri'),
                       if (!isBusiness) ...[const Gap(8), const Icon(Icons.lock, size: 14, color: Colors.orange)],
                    ]),
                    subtitle: const Text('Birim fiyat ve tutarları göster'),
                    secondary: const Icon(Icons.attach_money),
                    value: isBusiness ? settings.includeCosts : false,
                    onChanged: (val) {
                       if (!isBusiness) {
                          showUpsell('Maliyet Raporları (Business)');
                       } else {
                          update(() => notifier.updateSettings(includeCosts: val));
                       }
                    },
                  ),

                  const Gap(48),
                ],
              ),
            );
          }
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.isLocked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: isSelected ? color : (isLocked ? Colors.grey : Colors.grey.shade600)),
                if (isLocked)
                  const Positioned(
                    right: -6, top: -6,
                    child: Icon(Icons.lock, size: 12, color: Colors.orange),
                  ),
              ],
            ),
            const Gap(8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : (isLocked ? Colors.grey : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ProfileCard extends StatelessWidget {
  final dynamic user;
  const _ProfileCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      // color: Use theme default
      // shape: Use theme default
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
              ),
            ),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(user.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.grey),
              onPressed: () => context.go('/settings/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  final bool isOwner;
  final bool isAdmin;
  
  const _OrganizationCard({super.key, required this.isOwner, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
       // color: Use theme default
       // shape: Use theme default
       child: Column(
         children: [
           ListTile(
             leading: const Icon(Icons.business, color: Colors.indigo),
             title: const Text('Organizasyon', style: TextStyle(fontWeight: FontWeight.bold)),
             subtitle: const Text('Ekip ve roller'),
             trailing: const Icon(Icons.chevron_right),
             onTap: () => context.go('/settings/members'),
           ),
           if (isOwner) ...[
             const Divider(height: 1, indent: 56),
             ListTile(
               leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
               title: const Text('Yönetici Paneli', style: TextStyle(fontWeight: FontWeight.bold)),
               subtitle: const Text('Politikalar ve yapılandırma'),
               trailing: const Icon(Icons.chevron_right),
               onTap: () => context.go('/settings/owner-panel'),
             ),
             const Divider(height: 1, indent: 56),
           ],
           ListTile(
               leading: const Icon(Icons.info_outline, color: Colors.indigoAccent),
               title: const Text('Organizasyon Bilgileri', style: TextStyle(fontWeight: FontWeight.bold)),
               subtitle: const Text('ID ve yapılandırma'),
               trailing: const Icon(Icons.chevron_right),
               onTap: () => context.go('/settings/organization-info'),
           ),
         ],
       ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final PlanConfig config;
  final Map<String, int> usage;
  final bool isOwner;
  final VoidCallback onManage;

  const _SubscriptionCard({
    super.key, 
    required this.config, 
    required this.usage, 
    required this.isOwner, 
    required this.onManage
  });

  @override
  Widget build(BuildContext context) {
    final color = config.accentColor;
    final isPro = config.priceMonthly > 0;

    return Card(
      elevation: 0,
      color: color.withAlpha(45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withAlpha(80), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.star, color: color),
                const Gap(12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mevcut Plan', style: TextStyle(fontSize: 12, color: color)),
                    Text(config.displayName.toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                  ],
                ),
                const Spacer(),
                if (isOwner)
                  TextButton(
                    onPressed: onManage,
                    style: TextButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(isPro ? 'Planı Yönet' : 'Yükselt'),
                  )
                else 
                  TextButton(onPressed: onManage, child: const Text('Planı Gör')),
              ],
            ),
            const Gap(16),
            // Counters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MiniCounter(
                  label: 'Projeler', 
                  value: usage['projects'] ?? 0, 
                  limit: config.projectLimit, 
                  color: color
                ),
                _MiniCounter(
                  label: 'Kullanıcı', 
                  value: usage['seats'] ?? 0, 
                  limit: config.seatLimit, 
                  color: color
                ),
                _MiniCounter(
                  label: 'Çalışan', 
                  value: usage['workers'] ?? 0, 
                  limit: config.workerLimit, 
                  color: color
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCounter extends StatelessWidget {
  final String label;
  final int value;
  final int limit;
  final Color color;
  const _MiniCounter({
    super.key, 
    required this.label, 
    required this.value, 
    required this.limit, 
    required this.color
  });

  @override
  Widget build(BuildContext context) {
    final limitStr = limit == 0 ? '∞' : '$limit';
    return Column(
      children: [
        Text('$value/$limitStr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: color.withAlpha(204))),
      ],
    );
  }
}

class _DataSyncCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _DataSyncCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final queueAsync = ref.watch(syncQueueProvider);
    final queueCount = queueAsync.valueOrNull ?? 0;
    final error = ref.watch(lastSyncErrorProvider);

    Color color;
    IconData icon;
    String statusText;
    String actionText;
    bool isActionEnabled = true;

    switch (status) {
      case SyncStatus.synced:
        color = Colors.green;
        icon = Icons.check_circle_outline;
        statusText = 'Senkronize';
        actionText = 'Şimdi Senkronla';
        break;
      case SyncStatus.syncing:
        color = Colors.blue;
        icon = Icons.sync;
        statusText = 'Senkronize ediliyor...';
        actionText = 'Bekleyin...';
        isActionEnabled = false;
        break;
      case SyncStatus.offline:
        color = Colors.orange;
        icon = Icons.cloud_off;
        statusText = 'Çevrimdışı';
        actionText = 'Bağlantı Yok';
        isActionEnabled = false;
        break;
      case SyncStatus.error:
        color = Colors.red;
        icon = Icons.error_outline;
        statusText = 'Hata';
        actionText = 'Yeniden Dene';
        break;
    }

    return Card(
      elevation: 0,
       // color: Use theme default
       // shape: Use theme default
         child: InkWell(
           onTap: () async {
                  final isar = ref.read(isarProvider).valueOrNull;
                  if (isar != null) {
                      final p = await isar.projects.filter().isSyncedEqualTo(false).count();
                      final w = await isar.workers.filter().isSyncedEqualTo(false).count();
                      final pw = await isar.projectWorkers.filter().isSyncedEqualTo(false).count();
                      final r = await isar.dailyReports.filter().isSyncedEqualTo(false).count();
                      final o = await isar.outboxItems.filter().isProcessedEqualTo(false).count();
                      
                      showDialog(context: context, builder: (c) => AlertDialog(
                         title: const Text('Senkronizasyon Detayı'),
                         content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text('Projeler: $p'),
                               Text('Personel: $w'),
                               Text('Atamalar (PW): $pw'),
                               Text('Raporlar: $r'),
                               Text('Kuyruk (Outbox): $o'),
                               const SizedBox(height: 10),
                               const Text('Hatasız görünüyorsa internet bağlantısını kontrol edin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                         ),
                         actions: [
                            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Kapat')),
                         ],
                      ));
                  }
           },
           borderRadius: BorderRadius.circular(16),
           child: Padding(
             padding: const EdgeInsets.all(12),
             child: Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
                   child: Icon(icon, color: color),
                 ),
                 const Gap(12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('Veri & Senkronizasyon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                       const Gap(2),
                       Text('Durum: $statusText', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                       Text('Bekleyen: $queueCount${error != null ? " • Hata: 1" : ""}', 
                         style: TextStyle(color: error != null ? Colors.red : Colors.grey.shade600, fontSize: 12)),
                     ],
                   ),
                 ),
                 ElevatedButton(
                   onPressed: isActionEnabled ? () {
                      ref.read(syncServiceProvider).syncAll();
                   } : null,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: color,
                   foregroundColor: Colors.white,
                   disabledBackgroundColor: Colors.grey.shade200,
                   disabledForegroundColor: Colors.grey,
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                   minimumSize: const Size(64, 32),
                   textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                 ),
                 child: Text(actionText),
               ),
             ],
           ),
         ),
       ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;
  final Widget? trailing;

  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
     this.subtitle,
     this.onTap,
     this.iconColor,
     this.textColor,
     this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // If explicit colors are not provided, rely on defaults which are handled by ListTileTheme in AppTheme
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor, size: 22), 
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: textColor)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final WidgetRef ref;
  const _LogoutButton({super.key, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await ref.read(authControllerProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red.shade100),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.logout, size: 20),
        label: const Text('Oturumu Kapat'),
      ),
    );
  }
}

class _PreviewTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _PreviewTag({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const Gap(4),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
