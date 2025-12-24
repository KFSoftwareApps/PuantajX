import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';


import '../../../project/presentation/providers/project_providers.dart';
import '../payment_summary_screen.dart';

class LockingWizardDialog extends ConsumerStatefulWidget {
  final int projectId;

  const LockingWizardDialog({super.key, required this.projectId});

  @override
  ConsumerState<LockingWizardDialog> createState() => _LockingWizardDialogState();
}

class _LockingWizardDialogState extends ConsumerState<LockingWizardDialog> {
  DateTime _selectedDate = DateTime.now();
  int _step = 1;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Gap(24),
            if (_step == 1) _buildStep1() else _buildStep2(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          _step == 1 ? Icons.calendar_today : Icons.lock_outline,
          color: Theme.of(context).primaryColor,
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dönemi Kilitle',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                _step == 1 ? 'Adım 1/2: Tarih Seçimi' : 'Adım 2/2: Onay',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        if (_step == 2)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isLoading ? null : () => setState(() => _step = 1),
            tooltip: 'Tarihi Değiştir',
          )
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hangi tarihe kadar olan kayıtları kilitlemek istiyorsunuz?'),
        const Gap(16),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _selectedDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd.MM.yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        const Gap(24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = 2),
            child: const Text('Devam Et'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final range = DateRange(
        start: DateTime(_selectedDate.year, _selectedDate.month, 1), end: _selectedDate);
    final summaryAsync = ref.watch(paymentSummaryProvider((widget.projectId, range)));

    return summaryAsync.when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      )),
      error: (e, s) => Text('Hata: $e', style: const TextStyle(color: Colors.red)),
      data: (items) {
        final totalAmount = items.fold<double>(0, (sum, item) => sum + item.totalAmount);
        final workerCount = items.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  Gap(12),
                  Expanded(
                    child: Text(
                      'Dikkat: Kilitleme işlemi sadece katılım verilerini dondurur. Çalışan maaş ayarlarını değiştirmek geçmiş hesaplamaları etkileyebilir.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
            const Text('Özet:', style: TextStyle(fontWeight: FontWeight.bold)),
             const Gap(8),
            _buildSummaryRow('Kilitlenecek Tarih:', DateFormat('dd.MM.yyyy').format(_selectedDate)),
            _buildSummaryRow('Çalışan Sayısı:', '$workerCount Kişi'),
            _buildSummaryRow('Toplam Tutar:', '${totalAmount.toStringAsFixed(2)} TL', isBold: true),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isLoading ? null : _confirmLock,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('KİLİTLE'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _confirmLock() async {
    setState(() => _isLoading = true);
    try {
      final project = await ref.read(projectRepositoryProvider).getProject(widget.projectId);
      if (project != null) {
        project.financeLockDate = _selectedDate;
        await ref.read(projectRepositoryProvider).updateProject(project);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dönem ${DateFormat('dd.MM.yyyy').format(_selectedDate)} tarihine kadar kilitlendi.')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
