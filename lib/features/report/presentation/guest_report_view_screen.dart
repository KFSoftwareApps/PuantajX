import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../data/repositories/share_token_repository.dart';
import '../data/repositories/report_repository.dart';
import '../data/models/daily_report_model.dart';
import '../../../core/init/providers.dart';
import '../../../core/widgets/custom_app_bar.dart';

// Provider for share token repository
final guestShareTokenRepositoryProvider = Provider<ShareTokenRepository>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  if (isar == null) throw UnimplementedError('Isar not initialized');
  return ShareTokenRepository(isar);
});

// Provider for guest report
final guestReportProvider = FutureProvider.family<DailyReport?, String>((ref, token) async {
  final tokenRepo = ref.read(guestShareTokenRepositoryProvider);
  final shareToken = await tokenRepo.getTokenByString(token);
  
  if (shareToken == null) return null;
  if (!await tokenRepo.isTokenValid(token)) return null;
  
  final reportRepo = ref.read(reportRepositoryProvider);
  return await reportRepo.getReportById(shareToken.reportId);
});


class GuestReportViewScreen extends ConsumerWidget {
  final String token;

  const GuestReportViewScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(guestReportProvider(token));

    return Scaffold(
      appBar: const CustomAppBar(title: 'Paylaşılan Rapor'),
      body: reportAsync.when(
        data: (report) {
          if (report == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  Gap(16),
                  Text('Geçersiz veya süresi dolmuş link', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return _buildGuestView(context, ref, report);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Widget _buildGuestView(BuildContext context, WidgetRef ref, DailyReport report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Warning banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.visibility, color: Colors.orange.shade700),
              const Gap(12),
              const Expanded(
                child: Text(
                  'Misafir Görünümü - Ücret ve saat bilgileri gizlenmiştir',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const Gap(24),
        
        // Report header
        Text(
          'Günlük Rapor',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Gap(8),
        Text(
          DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(report.date),
          style: TextStyle(color: Colors.grey[600]),
        ),
        const Gap(24),
        
        // Weather & Shift
        if (report.weather != null || report.shift != null) ...[
          _buildInfoCard(
            'Hava & Vardiya',
            [
              if (report.weather != null) 'Hava: ${report.weather}',
              if (report.shift != null) 'Vardiya: ${report.shift}',
            ],
          ),
          const Gap(16),
        ],
        
        // General note
        if (report.generalNote != null && report.generalNote!.isNotEmpty) ...[
          _buildInfoCard('Genel Notlar', [report.generalNote!]),
          const Gap(16),
        ],
        
        // Crew description
        if (report.crewDescription != null && report.crewDescription!.isNotEmpty) ...[
          _buildInfoCard('Ekip Bilgisi', [report.crewDescription!]),
          const Gap(16),
        ],
        
        // Resource description
        if (report.resourceDescription != null && report.resourceDescription!.isNotEmpty) ...[
          _buildInfoCard('Kaynak Bilgisi', [report.resourceDescription!]),
          const Gap(16),
        ],
        
        // Report items
        if (report.items.isNotEmpty) ...[
          const Text('Yapılan İşler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Gap(8),
          ...report.items.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(item.description ?? 'Açıklama yok'),
              subtitle: item.category != null ? Text(item.category!) : null,
              trailing: item.quantity != null && item.unit != null
                  ? Text('${item.quantity} ${item.unit}')
                  : null,
            ),
          )),
          const Gap(16),
        ],
        
        // Attachments (if allowed)
        FutureBuilder<bool>(
          future: _canViewPhotos(ref),
          builder: (context, snapshot) {
            if (snapshot.data == true && report.attachments.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ekler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Gap(8),
                  Text('${report.attachments.length} fotoğraf', style: TextStyle(color: Colors.grey[600])),
                  const Gap(8),
                  // In production, display actual photos
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: Text('Fotoğraf görüntüleme özelliği yakında...')),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Gap(8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(item),
            )),
          ],
        ),
      ),
    );
  }

  Future<bool> _canViewPhotos(WidgetRef ref) async {
    final tokenRepo = ref.read(guestShareTokenRepositoryProvider);
    final shareToken = await tokenRepo.getTokenByString(token);
    return shareToken?.canViewPhotos ?? false;
  }
}
