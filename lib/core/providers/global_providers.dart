import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../init/providers.dart';
import 'package:isar/isar.dart'; // Existing
import '../sync/data/models/outbox_item.dart'; // Existing

import 'package:async/async.dart';

// Enum for Sync Status
enum SyncStatus { synced, syncing, offline, error }

// Tracks the current application Sync Status
// Tracks the current application Sync Status
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.synced);

final syncQueueProvider = StreamProvider<int>((ref) async* {
  final isar = await ref.watch(isarProvider.future);
  if (isar == null) {
      yield 0;
      return;
  }
  
  // Watch streams for all syncable entities
  (isar as dynamic).projects.filter().isSyncedEqualTo(false).watch(fireImmediately: true).map((events) => events.length);
  (isar as dynamic).workers.filter().isSyncedEqualTo(false).watch(fireImmediately: true).map((events) => events.length);
  (isar as dynamic).projectWorkers.filter().isSyncedEqualTo(false).watch(fireImmediately: true).map((events) => events.length);
  (isar as dynamic).dailyReports.filter().isSyncedEqualTo(false).watch(fireImmediately: true).map((events) => events.length);
  (isar as dynamic).outboxItems.filter().isProcessedEqualTo(false).watch(fireImmediately: true).map((events) => events.length);

  // Combine latest 
  // Since we don't have CombineLatestStream handy (it's in rxdart), we can use a workaround or assume rxdart is present.
  // Most Flutter projects have rxdart or similar. If not, StreamGroup.merge emits whenever ANY changes, but we need the SUM of most recent values.
  // Standard StreamGroup.merge just interleaves.
  
  // Alternative: Use a manual stream controller to sum them up.
  // But simpler for this context: Just watch 'Any Change' in the DB? Too broad.
  
  // Let's try 'StreamRx.combineLatest' assuming rxdart.
  // If not available, I will use a custom merger class.
  // PuantajX seems to be a robust app, likely has rxdart or functional listener.
  // Checking imports... NO rxdart seen.
  
  // Fallback: simple StreamGenerator that yields 0 initially, then listens to all.
  // But we need the values.
  
  // Let's stick to a simpler implementation that might be heavier (watchLazy) and then query all counts.
  
  final port = StreamGroup.merge<void>([
     ((isar as dynamic).projects as IsarCollection).watchLazy(fireImmediately: true),
     ((isar as dynamic).workers as IsarCollection).watchLazy(fireImmediately: true),
     ((isar as dynamic).projectWorkers as IsarCollection).watchLazy(fireImmediately: true),
     ((isar as dynamic).dailyReports as IsarCollection).watchLazy(fireImmediately: true),
     ((isar as dynamic).outboxItems as IsarCollection).watchLazy(fireImmediately: true),
  ]);

  yield* port.asyncMap((_) async {
     final p = await (isar as dynamic).projects.filter().isSyncedEqualTo(false).count();
     final w = await (isar as dynamic).workers.filter().isSyncedEqualTo(false).count();
     final pw = await (isar as dynamic).projectWorkers.filter().isSyncedEqualTo(false).count();
     final r = await (isar as dynamic).dailyReports.filter().isSyncedEqualTo(false).count();
     final o = await (isar as dynamic).outboxItems.filter().isProcessedEqualTo(false).count();
     return p + w + pw + r + o;
  });
});

final outboxListProvider = StreamProvider<List<OutboxItem>>((ref) async* {
  final isar = await ref.watch(isarProvider.future);
  if (isar == null) {
      yield [];
      return;
  }
  yield* (isar as dynamic).outboxItems.filter().isProcessedEqualTo(false).sortByCreatedAtDesc().watch(fireImmediately: true);
});

// Tracks if there are pending items (unsynced count)
// Tracks if there are pending items (unsynced count)
final pendingItemsProvider = StateProvider<int>((ref) => 0);

final lastSyncErrorProvider = StateProvider<String?>((ref) => null);

final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => DateTime.now());

// --- APP SETTINGS PROVIDERS ---

// Theme Mode
// Theme Mode Notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved == 'light') state = ThemeMode.light;
    else if (saved == 'dark') state = ThemeMode.dark;
    else state = ThemeMode.light; // Force light as default
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) await prefs.setString('theme_mode', 'light');
    else if (mode == ThemeMode.dark) await prefs.setString('theme_mode', 'dark');
    else await prefs.remove('theme_mode');
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// Locale (Language)
final localeProvider = StateProvider<Locale>((ref) => const Locale('tr', 'TR'));

// Notifications
class NotificationSettings {
  final bool reportReminder;
  final bool approvalRequest;
  final bool syncError;

  NotificationSettings({this.reportReminder = true, this.approvalRequest = true, this.syncError = true});

  NotificationSettings copyWith({bool? reportReminder, bool? approvalRequest, bool? syncError}) {
    return NotificationSettings(
      reportReminder: reportReminder ?? this.reportReminder,
      approvalRequest: approvalRequest ?? this.approvalRequest,
      syncError: syncError ?? this.syncError,
    );
  }
}

final notificationSettingsProvider = StateProvider<NotificationSettings>((ref) => NotificationSettings());

// Sync Settings
class SyncSettings {
  final bool onlyWifi;

  SyncSettings({this.onlyWifi = true});

  SyncSettings copyWith({bool? onlyWifi}) {
    return SyncSettings(
      onlyWifi: onlyWifi ?? this.onlyWifi,
    );
  }
}

// Sync Settings Notifier for Persistence
class SyncSettingsNotifier extends StateNotifier<SyncSettings> {
  SyncSettingsNotifier() : super(SyncSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final onlyWifi = prefs.getBool('sync_only_wifi') ?? true;
    state = SyncSettings(onlyWifi: onlyWifi);
  }

  Future<void> setOnlyWifi(bool value) async {
    state = state.copyWith(onlyWifi: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_only_wifi', value);
  }
}

final syncSettingsProvider = StateNotifierProvider<SyncSettingsNotifier, SyncSettings>((ref) {
  return SyncSettingsNotifier();
});

// Report Export Settings
class ExportSettings {
  final String format; // 'excel' or 'pdf'
  final bool includeHeader;
  final bool includePhotos;
  final String pdfOrientation; // 'portrait' or 'landscape'
  final String pdfPageSize; // 'A4'
  final String detailLevel; // 'summary' or 'detailed'
  final bool includeCosts;
  final String language; // 'tr' or 'en'

  ExportSettings({
    this.format = 'excel',
    this.includeHeader = true,
    this.includePhotos = true,
    this.pdfOrientation = 'portrait',
    this.pdfPageSize = 'A4',
    this.detailLevel = 'detailed',
    this.includeCosts = false,
    this.language = 'tr',
  });

  ExportSettings copyWith({
    String? format,
    bool? includeHeader,
    bool? includePhotos,
    String? pdfOrientation,
    String? pdfPageSize,
    String? detailLevel,
    bool? includeCosts,
    String? language,
  }) {
    return ExportSettings(
      format: format ?? this.format,
      includeHeader: includeHeader ?? this.includeHeader,
      includePhotos: includePhotos ?? this.includePhotos,
      pdfOrientation: pdfOrientation ?? this.pdfOrientation,
      pdfPageSize: pdfPageSize ?? this.pdfPageSize,
      detailLevel: detailLevel ?? this.detailLevel,
      includeCosts: includeCosts ?? this.includeCosts,
      language: language ?? this.language,
    );
  }
}

class ExportSettingsNotifier extends StateNotifier<ExportSettings> {
  ExportSettingsNotifier() : super(ExportSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ExportSettings(
      format: prefs.getString('export_format') ?? 'excel',
      includeHeader: prefs.getBool('export_include_header') ?? true,
      includePhotos: prefs.getBool('export_include_photos') ?? true,
      pdfOrientation: prefs.getString('export_pdf_orientation') ?? 'portrait',
      pdfPageSize: prefs.getString('export_pdf_page_size') ?? 'A4',
      detailLevel: prefs.getString('export_detail_level') ?? 'detailed',
      includeCosts: prefs.getBool('export_include_costs') ?? false,
      language: prefs.getString('export_language') ?? 'tr',
    );
  }

  Future<void> updateSettings({
    String? format,
    bool? includeHeader,
    bool? includePhotos,
    String? pdfOrientation,
    String? pdfPageSize,
    String? detailLevel,
    bool? includeCosts,
    String? language,
  }) async {
    state = state.copyWith(
      format: format,
      includeHeader: includeHeader,
      includePhotos: includePhotos,
      pdfOrientation: pdfOrientation,
      pdfPageSize: pdfPageSize,
      detailLevel: detailLevel,
      includeCosts: includeCosts,
      language: language,
    );
    
    final prefs = await SharedPreferences.getInstance();
    if (format != null) await prefs.setString('export_format', format);
    if (includeHeader != null) await prefs.setBool('export_include_header', includeHeader);
    if (includePhotos != null) await prefs.setBool('export_include_photos', includePhotos);
    if (pdfOrientation != null) await prefs.setString('export_pdf_orientation', pdfOrientation);
    if (pdfPageSize != null) await prefs.setString('export_pdf_page_size', pdfPageSize);
    if (detailLevel != null) await prefs.setString('export_detail_level', detailLevel);
    if (includeCosts != null) await prefs.setBool('export_include_costs', includeCosts);
    if (language != null) await prefs.setString('export_language', language);
  }
}

final exportSettingsProvider = StateNotifierProvider<ExportSettingsNotifier, ExportSettings>((ref) {
  return ExportSettingsNotifier();
});
