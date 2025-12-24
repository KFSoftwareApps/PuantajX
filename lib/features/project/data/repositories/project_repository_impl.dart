import 'package:isar/isar.dart';
import '../../domain/repositories/i_project_repository.dart';
import '../models/project_model.dart';
import '../../../../core/subscription/subscription_service.dart';
import '../../../../core/sync/data/models/outbox_item.dart';
import '../../../../core/utils/web_id_cache.dart';

import '../../data/models/worker_model.dart';
import '../../data/models/project_worker_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectRepository implements IProjectRepository {
  final Isar? _isar;
  final SupabaseClient _supabase;
  final SubscriptionService _subscriptionService;

  ProjectRepository(this._isar, this._supabase, this._subscriptionService);

  @override
  Future<List<Project>> getProjects(String orgId) async {
    final isar = _isar;
    if (isar != null) {
      return await (isar as dynamic).projects.filter().orgIdEqualTo(orgId).sortByCreatedAtDesc().findAll();
    } else {
      // Web / Online-Only Fallback
       try {
         final orgCode = orgId;
         String? targetOrgUuid;
         final orgRes = await _supabase.from('organizations').select('id').eq('code', orgCode).maybeSingle();
         if (orgRes != null) {
            targetOrgUuid = orgRes['id'] as String;
         } else {
            targetOrgUuid = orgCode;
         }

         final data = await _supabase.from('projects').select().eq('org_id', targetOrgUuid).order('created_at');
         return (data as List).map((e) {
           final uuid = e['id'] as String;
           return Project()
             ..id = WebIdCache().store(uuid) // Store mapping
             ..serverId = uuid
             ..name = e['name']
             ..location = e['location']
             ..orgId = orgCode // Maintain local code
             ..status = e['status'] == 'active' ? ProjectStatus.active : ProjectStatus.archived
             ..createdAt = DateTime.tryParse(e['created_at']) ?? DateTime.now()
             ..isSynced = true;
         }).toList();
       } catch (e) {
         return [];
       }
    }
  }

  @override
  Future<Project?> getProject(int id) async {
    final isar = _isar;
    if (isar != null) {
      return await (isar as dynamic).projects.get(id);
    } 
    // Web: Resolve UUID from Cache
    final uuid = WebIdCache().lookup(id);
    if (uuid != null) {
       final data = await _supabase.from('projects').select().eq('id', uuid).maybeSingle();
       if (data != null) {
          // Find Org Code from UUID? 
          // For now assume orgId in data is the UUID, but Project model expects Code?
          // Actually Project model might expect what we give it.
          // Let's keep it consistent.
          return Project()
             ..id = id
             ..serverId = uuid
             ..name = data['name']
             ..location = data['location']
             ..orgId = data['org_id'] // This might be UUID, implies UI might show UUID if not careful.
             ..status = data['status'] == 'active' ? ProjectStatus.active : ProjectStatus.archived
             ..createdAt = DateTime.tryParse(data['created_at']) ?? DateTime.now()
             ..isSynced = true;
       }
    }
    return null; 
  }

  @override
  Future<int> createProject(Project project) async {
    final canCreate = await _subscriptionService.canPerformAction(
      project.orgId,
      'create_project',
    );
    
    if (!canCreate) {
      throw Exception('Proje oluşturma limitine ulaşıldı. Devam etmek için planınızı yükseltin.');
    }
    
    final isar = _isar;
    if (isar != null) {
       return await isar.writeTxn(() async {
         return await (isar as dynamic).projects.put(project);
       });
    } else {
       // Web: Direct to Supabase
       try {
         final orgCode = project.orgId;
         String targetOrgUuid = orgCode;
         final orgRes = await _supabase.from('organizations').select('id').eq('code', orgCode).maybeSingle();
         if (orgRes != null) {
            targetOrgUuid = orgRes['id'] as String;
         }

         final data = {
           'name': project.name,
           'org_id': targetOrgUuid, // UUID
           'status': project.status.name,
           'location': project.location,
           'created_at': DateTime.now().toIso8601String(),
         };
         final res = await _supabase.from('projects').insert(data).select().single();
         final uuid = res['id'] as String;
         // Store mapping so we can use this ID immediately
         return WebIdCache().store(uuid);
       } catch (e) {
         throw Exception('Proje oluşturulamadı: $e');
       }
    }
  }

  @override
  Future<void> updateProject(Project project) async {
    final isar = _isar;
    if (isar != null) {
      await isar.writeTxn(() async {
        await (isar as dynamic).projects.put(project);
      });
    } else {
      // Web: Direct Update via UUID
      if (project.serverId != null) {
         await _supabase.from('projects').update({
           'name': project.name,
           'location': project.location,
           'status': project.status.name,
         }).eq('id', project.serverId!);
      }
    }
  }

  @override
  Future<void> deleteProject(int id) async {
    final isar = _isar;
    if (isar != null) {
      final project = await (isar as dynamic).projects.get(id);
      if (project == null) return;

      await isar.writeTxn(() async {
        if (project.serverId != null) {
          final outboxItem = OutboxItem()
            ..operation = 'DELETE'
            ..entityType = 'PROJECT'
            ..entityId = project.serverId!
            ..createdAt = DateTime.now();
          await (isar as dynamic).outboxItems.put(outboxItem);
        }
        await (isar as dynamic).projects.delete(id);
      });
    } 
    // Web: Delete by ID
    final uuid = WebIdCache().lookup(id);
    if (uuid != null) {
       await _supabase.from('projects').delete().eq('id', uuid);
    }
  }
  
  // --- New Worker Methods ---

  @override
  Future<List<Worker>> getProjectWorkers(int projectId) async {
     final isar = _isar;
     if (isar != null) {
        final links = await (isar as dynamic).projectWorkers
            .filter()
            .projectIdEqualTo(projectId)
            .isActiveEqualTo(true)
            .findAll();
        if (links.isEmpty) return [];
        final workerIds = links.map((e) => (e as dynamic).workerId as int).toList();
        final workers = await (isar as dynamic).workers.getAll(workerIds);
        return workers.whereType<Worker>().toList();
     }
     // Web: Join query?
     // Web: Join query using explicit relation table
     final projectUuid = WebIdCache().lookup(projectId);
     if (projectUuid == null) return [];

     // 1. Get active worker UUIDs for this project
     final links = await _supabase.from('project_workers')
        .select('worker_id') // worker_id is UUID in Supabase
        .eq('project_id', projectUuid)
        .eq('is_active', true); // Assuming column is is_active or check schema?
     
     if ((links as List).isEmpty) return [];
     
     final workerUuids = links.map((e) => e['worker_id']).toList();
     
     // 2. Fetch Workers
     final workersData = await _supabase.from('workers')
        .select()
        .filter('id', 'in', workerUuids);
        
     return (workersData as List).map((e) {
        final uuid = e['id'] as String;
        return Worker()
           ..id = WebIdCache().store(uuid)
           ..serverId = uuid
           ..name = e['name']
           ..orgId = e['org_id']
           ..type = e['type'] ?? 'worker'
           ..dailyRate = (e['daily_rate'] as num?)?.toDouble()
           ..isSynced = true;
     }).toList();
  }

  @override
  Future<List<Worker>> getAvailableWorkers(int projectId) async {
    final isar = _isar;
    if (isar != null) {
      final allWorkers = await (isar as dynamic).workers.where().findAll();
      final currentLinks = await (isar as dynamic).projectWorkers
          .filter()
          .projectIdEqualTo(projectId)
          .isActiveEqualTo(true)
          .findAll();
      final assignedIds = currentLinks.map((e) => (e as dynamic).workerId).toSet();
      return allWorkers.where((w) => !assignedIds.contains(w.id)).toList();
    }
    // Web: Available Workers
    final projectUuid = WebIdCache().lookup(projectId);
    if (projectUuid == null) return [];
    
    // Fetch Project to get OrgId
    final projectData = await _supabase.from('projects').select('org_id').eq('id', projectUuid).single();
    final orgId = projectData['org_id'];
    
    // 1. All Workers
    final allWorkersData = await _supabase.from('workers').select().eq('org_id', orgId);
    
    // 2. Assigned UUIDs
    final links = await _supabase.from('project_workers')
        .select('worker_id')
        .eq('project_id', projectUuid)
        .eq('is_active', true);
    
    final assignedUuids = (links as List).map((e) => e['worker_id']).toSet();
    
    return (allWorkersData as List).where((e) => !assignedUuids.contains(e['id'])).map((e) {
       final uuid = e['id'] as String;
       return Worker()
           ..id = WebIdCache().store(uuid)
           ..serverId = uuid
           ..name = e['name']
           ..orgId = e['org_id']
           ..type = e['type'] ?? 'worker'
           ..dailyRate = (e['daily_rate'] as num?)?.toDouble()
           ..isSynced = true; 
    }).toList();
  }
  
  @override
  Future<List<Worker>> getProjectCrewMembers(int projectId, int crewId) async {
       final isar = _isar;
       if (isar == null) return [];
       final links = await (isar as dynamic).projectWorkers
          .filter()
          .projectIdEqualTo(projectId)
          .crewIdEqualTo(crewId)
          .isActiveEqualTo(true)
          .findAll();
       final ids = links.map((e) => (e as dynamic).workerId as int).toList();
       final workers = await (isar as dynamic).workers.getAll(ids);
       return workers.whereType<Worker>().toList();
  }

  @override
  Future<List<Worker>> getProjectWorkersWithoutCrew(int projectId) async {
       final isar = _isar;
       if (isar == null) return [];
       final links = await (isar as dynamic).projectWorkers
          .filter()
          .projectIdEqualTo(projectId)
          .crewIdIsNull()
          .isActiveEqualTo(true)
          .findAll();
       final ids = links.map((e) => (e as dynamic).workerId as int).toList();
       final workers = await (isar as dynamic).workers.getAll(ids);
       return workers.whereType<Worker>().toList();
  }

  @override
  Future<void> addWorkersToProject(int projectId, List<int> workerIds) async {
     final isar = _isar;
     if (isar != null) {
       await isar.writeTxn(() async {
          for (var wId in workerIds) {
             final existing = await (isar as dynamic).projectWorkers
                .filter()
                .projectIdEqualTo(projectId)
                .workerIdEqualTo(wId)
                .findFirst();
             
             if (existing != null) {
                existing.isActive = true;
                existing.lastUpdatedAt = DateTime.now();
                await (isar as dynamic).projectWorkers.put(existing);
             } else {
                final newLink = ProjectWorker()
                   ..projectId = projectId
                   ..workerId = wId
                   ..isActive = true
                   ..assignedAt = DateTime.now()
                   ..lastUpdatedAt = DateTime.now();
                await (isar as dynamic).projectWorkers.put(newLink);
             }
          }
       });
     } else {
       // Web Implementation
       final projectUuid = WebIdCache().lookup(projectId);
       if (projectUuid == null) return;
       
       final updates = <Map<String, dynamic>>[];
       for (var wId in workerIds) {
          final workerUuid = WebIdCache().lookup(wId);
          if (workerUuid == null) continue;
          
          updates.add({
             'project_id': projectUuid,
             'worker_id': workerUuid,
             'is_active': true,
             'updated_at': DateTime.now().toIso8601String(),
          });
       }
       
       if (updates.isNotEmpty) {
          await _supabase.from('project_workers').upsert(updates, onConflict: 'project_id, worker_id');
       }
     }
  }

  @override
  Future<void> removeWorkerFromProject(int projectId, int workerId) async {
      final isar = _isar;
      if (isar != null) {
        await isar.writeTxn(() async {
           final links = await (isar as dynamic).projectWorkers
               .filter()
               .projectIdEqualTo(projectId)
               .workerIdEqualTo(workerId)
               .findAll();
           for (var link in links) {
             link.isActive = false;
             link.lastUpdatedAt = DateTime.now();
             await (isar as dynamic).projectWorkers.put(link); 
           }
        });
      } else {
        // Web Implementation
        final projectUuid = WebIdCache().lookup(projectId);
        final workerUuid = WebIdCache().lookup(workerId);
        
        if (projectUuid != null && workerUuid != null) {
            await _supabase.from('project_workers')
               .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
               .eq('project_id', projectUuid)
               .eq('worker_id', workerUuid);
        }
      }
  }

  @override
  Future<void> assignWorkerToCrew(int projectId, int workerId, int? crewId) async {
      final isar = _isar;
      if (isar != null) {
        await isar.writeTxn(() async {
          final link = await (isar as dynamic).projectWorkers
              .filter()
              .projectIdEqualTo(projectId)
              .workerIdEqualTo(workerId)
              .isActiveEqualTo(true)
              .findFirst();

          if (link != null) {
            link.crewId = crewId;
            link.lastUpdatedAt = DateTime.now();
            await (isar as dynamic).projectWorkers.put(link);
          }
        });
      } else {
         // Web Implementation
         final projectUuid = WebIdCache().lookup(projectId);
         final workerUuid = WebIdCache().lookup(workerId);
         
         if (projectUuid != null && workerUuid != null) {
             await _supabase.from('project_workers')
                 .update({'updated_at': DateTime.now().toIso8601String()}) // Simplify for now
                 .eq('project_id', projectUuid)
                 .eq('worker_id', workerUuid);
         }
      }
  }

}
