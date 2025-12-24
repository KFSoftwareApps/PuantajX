import 'package:flutter/material.dart';
import 'package:puantaj_x/core/init/supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/init/router.dart';
import 'core/theme/app_theme.dart';

import 'package:puantaj_x/core/init/database.dart';
import 'package:puantaj_x/core/init/providers.dart';
import 'package:puantaj_x/core/providers/global_providers.dart';
import 'package:puantaj_x/core/services/notification_service.dart';
import 'package:puantaj_x/core/services/sync_service.dart'; 
import 'package:isar/isar.dart';

import 'package:puantaj_x/core/subscription/subscription_providers.dart'; // Added for IAP
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await initializeDateFormatting('tr_TR', null);
  } catch (e) {
    debugPrint('DateFormatting init failed: $e');
  }

  final databaseService = DatabaseService();
  Isar? isar;
  try {
     isar = await databaseService.db;
  } catch (e) {
     debugPrint('Database init failed: $e');
  }
  
  final sharedPreferences = await SharedPreferences.getInstance();

  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } catch (e) {
     debugPrint('Notification init failed: $e');
  }

  // Supabase Init (Placeholder)
  try {
     await SupabaseService().init();
  } catch (e) {
     debugPrint('Supabase Init Failed (Expected if credentials missing): $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(databaseService),
        isarProvider.overrideWith((ref) => isar),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const PuantajXApp(),
    ),
  );
}

class PuantajXApp extends ConsumerWidget {
  const PuantajXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Initialize Auto-Sync (Idempotent)
    ref.read(syncServiceProvider).initializeAutoSync();
    
    // Initialize IAP Listener
    final iapListener = ref.read(iapListenerProvider);
    iapListener.startListening();
    // Check initial status on boot
    iapListener.syncSubscriptionStatus();


    return MaterialApp.router(
      title: 'PuantajX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
