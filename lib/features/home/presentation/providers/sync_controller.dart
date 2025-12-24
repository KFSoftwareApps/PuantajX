import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/sync_service.dart';

part 'sync_controller.g.dart';

@riverpod
class SyncController extends _$SyncController {
  Timer? _timer;

  @override
  FutureOr<void> build() {
    // Auto-sync every 5 minutes
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => syncNow());
    ref.onDispose(() => _timer?.cancel());
  }

  Future<void> syncNow() async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(syncServiceProvider);
      await service.syncAll();
    });
  }
}
