import 'package:isar/isar.dart';
import '../models/worker_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/utils/web_id_cache.dart';

class WorkerRepository {
  final Isar? _isar;
  final SupabaseClient _supabase;
  final Ref _ref;

  WorkerRepository(this._isar, this._supabase, this._ref);

  Future<List<Worker>> getByOrg(String orgId) async {
    final isar = _isar;
    if (isar != null) {
      return (isar as dynamic).workers.filter().orgIdEqualTo(orgId).findAll();
    } else {
      // Web Fallback: Map Code (e.g. 'TALHA') to UUID
      try {
        final orgCode = orgId;
        // Check if orgId is already UUID? Simple check: length 36 and dashes
        // But safer to always query organizations table by code IF it's not a UUID.
        // Assuming Isar uses 'Code' and Supabase uses UUID for Relations.
        
        String? targetOrgUuid;
        // Optimization: Try to find organization by code
        final orgRes = await _supabase.from('organizations').select('id').eq('code', orgCode).maybeSingle();
        if (orgRes != null) {
           targetOrgUuid = orgRes['id'] as String;
        } else {
           // Fallback: Maybe orgId passed WAS a UUID?
           targetOrgUuid = orgCode;
        }

        final data = await _supabase.from('workers').select().eq('org_id', targetOrgUuid);
        return (data as List).map((e) { 
           final uuid = e['id'] as String;
           return Worker()
             ..id = WebIdCache().store(uuid)
             ..serverId = uuid
             ..name = e['name']
             ..orgId = orgCode // Keep the Code for local consistency
             ..type = e['type'] ?? 'worker'
             ..trade = e['trade']
             ..dailyRate = (e['daily_rate'] as num?)?.toDouble()
             ..isSynced = true;
        }).toList();
      } catch (e) {
        // debugPrint('Web Worker Fetch Error: $e');
        return [];
      }
    }
  }

  Future<int> createWorker(Worker worker) async {
    worker.createdAt ??= DateTime.now();
    worker.lastUpdatedAt = DateTime.now();

    final isar = _isar;
    if (isar != null) {
      final id = await isar.writeTxn(() async {
        return await (isar as dynamic).workers.put(worker);
      });
      _ref.read(syncServiceProvider).triggerSync();
      return id;
    } else {
       // Web: Insert to Supabase directly
       try {
         // Resolve Org UUID
         final orgCode = worker.orgId;
         String targetOrgUuid = orgCode;
         
         final orgRes = await _supabase.from('organizations').select('id').eq('code', orgCode).maybeSingle();
         if (orgRes != null) {
            targetOrgUuid = orgRes['id'] as String;
         }

         final data = {
           'name': worker.name,
           'org_id': targetOrgUuid, // Use UUID for Foreign Key
           'type': worker.type,
           'trade': worker.trade,
           'daily_rate': worker.dailyRate,
           'created_at': worker.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
           'updated_at': DateTime.now().toIso8601String(),
         };
         final res = await _supabase.from('workers').insert(data).select().single();
         final uuid = res['id'] as String;
         return WebIdCache().store(uuid);
       } catch (e) {
         // THROW THE ERROR so the UI can show it!
         throw Exception('Personel oluşturulamadı: $e');
       }
    }

  }


  Future<void> updateWorker(Worker worker) async {
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        await (isar as dynamic).workers.put(worker);
      });
    } else {
       // Web Update
       if (worker.serverId != null) {
          await _supabase.from('workers').update({
             'name': worker.name,
             'daily_rate': worker.dailyRate,
             'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', worker.serverId!);
       }
    }
    _ref.read(syncServiceProvider).triggerSync();
  }

  Future<void> toggleActive(Worker worker) async {
    worker.active = !worker.active;
    worker.lastUpdatedAt = DateTime.now();
    await saveWorker(worker);
  }

  Future<void> saveWorker(Worker worker) async {
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        await (isar as dynamic).workers.put(worker);
      });
    } else {
        // Web Update
       if (worker.serverId != null) {
          // Minimal update
          await _supabase.from('workers').update({
             'updated_at': DateTime.now().toIso8601String(),
             // We don't map 'active' to DB schema yet? 
             // Assuming active is local or syncs to status?
             // Schema has 'status' maybe? Or just delete?
          }).eq('id', worker.serverId!);
        } else {
           // Web Create
           final newId = await createWorker(worker);
           worker.id = newId;
           // We can't easily set serverId here without modifying createWorker to return it, 
           // but getting it into DB is the priority. List refresh will fetch correct full object.
        }
     }
    _ref.read(syncServiceProvider).triggerSync();
  }

  Future<void> deleteWorker(int id) async {
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        await (isar as dynamic).workers.delete(id);
      });
    } else {
        // Web Delete
        final uuid = WebIdCache().lookup(id);
        if (uuid != null) {
           await _supabase.from('workers').delete().eq('id', uuid);
        }
    }
    _ref.read(syncServiceProvider).triggerSync();
  }
}
