import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puantaj_x/features/auth/data/models/user_model.dart';
import 'package:puantaj_x/features/auth/data/repositories/auth_repository.dart';

// Dışarıdan kullanılsın diye export ediyoruz (eski importlar kırılmasın diye)
export 'package:puantaj_x/features/auth/data/repositories/auth_repository.dart'
    show currentPermissionsProvider;

// Active project provider asıl yerinden export (stub değil)
export 'package:puantaj_x/features/project/presentation/providers/active_project_provider.dart'
    show activeProjectProvider;

// Simple state notifier for selected project ID
class SelectedProjectIdNotifier extends StateNotifier<int?> {
  SelectedProjectIdNotifier() : super(null);

  void set(int? id) => state = id;
  void clear() => state = null;
}

// Provider for selected project ID
final selectedProjectIdProvider =
    StateNotifierProvider<SelectedProjectIdNotifier, int?>((ref) {
  return SelectedProjectIdNotifier();
});

// ✅ Gerçek org member listesi (stub değil)


// Eğer bir yerde “rapor listesi” bekleniyorsa compile etsin diye stub bıraktım.
// Sonra gerçek repo bağlarsın.
final projectReportsProvider =
    FutureProvider.family.autoDispose<List<dynamic>, int>((ref, projectId) async {
  return <dynamic>[];
});

// Bazı ekranlar DateTimeRange bekliyor (WorkerPaymentDetail vs). Kalsın.
final paymentSummaryFiltersProvider = Provider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, 1),
    end: now,
  );
});
