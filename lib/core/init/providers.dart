import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/init/database.dart';
import '../../core/init/supabase_service.dart';
import '../../core/sync/data/repositories/sync_repository.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final isarProvider = FutureProvider<Isar?>((ref) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.db;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService().client;
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  final supabase = ref.watch(supabaseClientProvider);
  
  if (isar != null) {
      return IsarSyncRepository(isar, supabase);
  } else {
      // Web / Fallback Mode
      return WebSyncRepository(supabase);
  }
});

