import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/pay_adjustment_model.dart';
import '../../../../core/init/providers.dart';

class PayAdjustmentRepository {
  final Isar? isar;

  PayAdjustmentRepository(this.isar);

  Future<void> addAdjustment(PayAdjustment adjustment) async {
    final i = isar;
    if (i == null) return;
    await i.writeTxn(() async {
      adjustment.lastUpdatedAt = DateTime.now();
      await i.payAdjustments.put(adjustment);
    });
  }

  Future<void> deleteAdjustment(int id) async {
    final i = isar;
    if (i == null) return;
    await i.writeTxn(() async {
      await i.payAdjustments.delete(id);
    });
  }

  Future<List<PayAdjustment>> getAdjustments(int projectId, int workerId, DateTime start, DateTime end) async {
    final i = isar;
    if (i == null) return [];
    return await i.payAdjustments
        .filter()
        .projectIdEqualTo(projectId)
        .workerIdEqualTo(workerId)
        .dateBetween(start, end)
        .findAll();
  }
}

final payAdjustmentRepositoryProvider = Provider<PayAdjustmentRepository>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  return PayAdjustmentRepository(isar);
});

final workerAdjustmentsProvider = FutureProvider.family<List<PayAdjustment>, (int, int, DateTime, DateTime)>((ref, args) async {
  final repo = ref.watch(payAdjustmentRepositoryProvider);
  return repo.getAdjustments(args.$1, args.$2, args.$3, args.$4);
});
