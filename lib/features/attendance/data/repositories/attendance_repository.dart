import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/init/providers.dart';
import '../../../../core/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_model.dart';
import '../../../../core/utils/web_id_cache.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'attendance_repository.g.dart';

abstract class IAttendanceRepository {
  Future<List<Attendance>> getAttendanceByProjectAndDate(int projectId, DateTime date);
  Future<void> saveAttendance(Attendance attendance);
  Future<void> saveBatchAttendance(List<Attendance> attendances);
}

class AttendanceRepository implements IAttendanceRepository {
  final Isar? _isar;
  final Ref _ref;

  AttendanceRepository(this._isar, this._ref);

  @override
  Future<List<Attendance>> getAttendanceByProjectAndDate(int projectId, DateTime date) async {
    final i = _isar;
    if (i == null) return [];
    return await (i as dynamic).attendances
        .filter()
        .projectIdEqualTo(projectId)
        .dateEqualTo(date)
        .findAll();
  }

  @override
  Future<void> saveAttendance(Attendance attendance) async {
    final i = _isar;
    if (i == null) return;
    await i.writeTxn(() async {
      await (i as dynamic).attendances.put(attendance);
    });
    // Auto Sync
    _ref.read(syncServiceProvider).triggerSync();
  }

  @override
  Future<void> saveBatchAttendance(List<Attendance> attendances) async {
    final i = _isar;
    if (i == null) return;
    await i.writeTxn(() async {
      await (i as dynamic).attendances.putAll(attendances);
    });
    // Auto Sync
    _ref.read(syncServiceProvider).triggerSync();
  }
}

class WebAttendanceRepository implements IAttendanceRepository {
  final SupabaseClient _supabase;
  WebAttendanceRepository(this._supabase);

  @override
  Future<List<Attendance>> getAttendanceByProjectAndDate(int projectId, DateTime date) async {
      final projectUuid = WebIdCache().lookup(projectId);
      if (projectUuid == null) return [];
      
      final dateStr = date.toIso8601String().split('T')[0];
      
      final data = await _supabase.from('attendances')
          .select()
          .eq('project_id', projectUuid)
          .eq('date', dateStr);
          
      return (data as List).map((e) {
         final uuid = e['id'] as String;
         final pUuid = e['project_id'] as String;
         final wUuid = e['worker_id'] as String;
         
         return Attendance()
            ..id = WebIdCache().store(uuid)
            ..serverId = uuid
            ..projectId = WebIdCache().store(pUuid)
            ..workerId = WebIdCache().store(wUuid)
            ..date = DateTime.parse(e['date'])
            ..hours = (e['hours'] as num?)?.toDouble() ?? 0
            ..overtimeHours = (e['overtime_hours'] as num?)?.toDouble() ?? 0
            ..status = AttendanceStatus.values.firstWhere((s) => s.name == e['status'], orElse: () => AttendanceStatus.present)
            ..dayType = DayType.values.firstWhere((d) => d.name == e['day_type'], orElse: () => DayType.normal)
            ..note = e['note']
            ..isSynced = true;
      }).toList();
  }

  @override
  Future<void> saveAttendance(Attendance attendance) async {
      await saveBatchAttendance([attendance]);
  }

  @override
  Future<void> saveBatchAttendance(List<Attendance> attendances) async {
       if (attendances.isEmpty) return;
       
       final updates = <Map<String, dynamic>>[];
       
       for (var a in attendances) {
          final pUuid = WebIdCache().lookup(a.projectId);
          final wUuid = WebIdCache().lookup(a.workerId);
          
          if (pUuid == null || wUuid == null) continue;
          
          final map = {
             'project_id': pUuid,
             'worker_id': wUuid,
             'date': a.date.toIso8601String().split('T')[0],
             'hours': a.hours,
             'overtime_hours': a.overtimeHours,
             'status': a.status.name,
             'day_type': a.dayType.name,
             'note': a.note,
             'updated_at': DateTime.now().toIso8601String(),
          };
          
          if (a.serverId != null) {
             map['id'] = a.serverId;
          }
          updates.add(map);
       }
       
       if (updates.isNotEmpty) {
          await _supabase.from('attendances').upsert(updates);
       }
  }
}

final attendanceRepositoryProvider = Provider<IAttendanceRepository>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  if (isar == null) {
      final supabase = ref.watch(supabaseClientProvider);
      return WebAttendanceRepository(supabase);
  }
  return AttendanceRepository(isar, ref);
});

@riverpod
class DailyAttendance extends _$DailyAttendance {
  @override
  Future<List<Attendance>> build(int projectId, DateTime date) async {
    final repository = ref.watch(attendanceRepositoryProvider);
    return repository.getAttendanceByProjectAndDate(projectId, date);
  }

  Future<void> updateAttendance(Attendance attendance) async {
      final repository = ref.read(attendanceRepositoryProvider);
      await repository.saveAttendance(attendance);
      ref.invalidateSelf();
  }
}
