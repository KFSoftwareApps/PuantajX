import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../data/repositories/share_token_repository.dart';
import '../../../core/init/providers.dart';
import '../../../core/subscription/subscription_providers.dart';
import '../../../core/subscription/plan_config.dart';
import '../../../core/widgets/locked_feature_placeholder.dart';

// Provider for share token repository
final shareTokenRepositoryProvider = Provider<ShareTokenRepository>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  if (isar == null) throw UnimplementedError('Isar not initialized');
  return ShareTokenRepository(isar);
});

class ShareReportDialog extends ConsumerStatefulWidget {
  final int reportId;

  const ShareReportDialog({super.key, required this.reportId});

  @override
  ConsumerState<ShareReportDialog> createState() => _ShareReportDialogState();
}

class _ShareReportDialogState extends ConsumerState<ShareReportDialog> {
  int _expiryDays = 7;
  bool _canViewPhotos = true;
  bool _canViewText = true;
  String? _generatedLink;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    // Check Entitlement
    final hasGuestSharing = ref.watch(hasEntitlementProvider(Entitlement.guestSharing)).value ?? false;

    if (!hasGuestSharing) {
      return AlertDialog(
        content: const SizedBox(
          width: 300,
          child: LockedFeaturePlaceholder(
            featureKey: 'guest_sharing',
            title: 'Misafir Paylaşımı',
            description: 'Projelerinizi dış paydaşlarlarla (müşteri, denetçi) paylaşmak için Business pakete geçin.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Raporu Paylaş'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Harici kişilerle (müşteri/denetçi) güvenli paylaşım'),
            const Gap(16),
            const Text('Geçerlilik Süresi:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Gap(8),
            DropdownButtonFormField<int>(
              value: _expiryDays,
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 Gün')),
                DropdownMenuItem(value: 7, child: Text('1 Hafta')),
                DropdownMenuItem(value: 30, child: Text('1 Ay')),
                DropdownMenuItem(value: 90, child: Text('3 Ay')),
              ],
              onChanged: (value) => setState(() => _expiryDays = value!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const Gap(16),
            const Text('İzinler:', style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              title: const Text('Fotoğrafları Görebilir'),
              value: _canViewPhotos,
              onChanged: (value) => setState(() => _canViewPhotos = value!),
              dense: true,
            ),
            CheckboxListTile(
              title: const Text('Metin İçeriği Görebilir'),
              value: _canViewText,
              onChanged: (value) => setState(() => _canViewText = value!),
              dense: true,
            ),
            if (_generatedLink != null) ...[
              const Gap(16),
              const Text('Paylaşım Linki:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Gap(8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _generatedLink!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _generatedLink!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link kopyalandı')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        if (_generatedLink == null)
          ElevatedButton(
            onPressed: _isGenerating ? null : _generateLink,
            child: _isGenerating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Link Oluştur'),
          ),
      ],
    );
  }

  Future<void> _generateLink() async {
    setState(() => _isGenerating = true);

    try {
      final repo = ref.read(shareTokenRepositoryProvider);
      final token = await repo.createShareToken(
        reportId: widget.reportId,
        expiryDays: _expiryDays,
        canViewPhotos: _canViewPhotos,
        canViewText: _canViewText,
      );

      // In production, this would be your actual domain
      final link = 'https://puantajx.app/shared/${token.token}';

      setState(() {
        _generatedLink = link;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }
}
