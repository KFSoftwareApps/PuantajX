import 'package:flutter/material.dart';
import 'package:puantaj_x/core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/outbox_item.dart';
import '../../../../features/project/data/models/project_model.dart';
import '../../../../features/project/data/models/worker_model.dart';
import '../../../../features/report/data/models/daily_report_model.dart';
import '../../../../features/auth/data/models/user_model.dart';

// Abstract Interface
abstract class SyncRepository {
  Future<void> processOutbox();
  Future<void> pullChanges(DateTime? lastSync);
  Future<int> queueUnsyncedData();
}

class IsarSyncRepository implements SyncRepository {
  final Isar _isar;
  final SupabaseClient _supabase;

  IsarSyncRepository(this._isar, this._supabase);

  // 1. PUSH QUEUE
  Future<void> processOutbox() async {
    // Get pending items
    final items = await _isar.outboxItems.where().sortByCreatedAt().findAll();
    
    for (final item in items) {
      bool success = false;
      try {
        switch (item.entityType) {
          case 'PROJECT':
            success = await _pushProject(item);
            break;
          case 'WORKER':
            success = await _pushWorker(item);
            break;
          case 'REPORT':
            success = await _pushReport(item);
            break;
          case 'ATTACHMENT_PHOTO':
            success = await _pushAttachment(item);
            break;
          default:
            print('Unknown entity type: ${item.entityType}');
            break;
        }

        if (success) {
          await _isar.writeTxn(() async {
            await _isar.outboxItems.delete(item.id);
          });
        } else {
           // Retry count logic? For now simpler.
        }
      } catch (e) {
        print('Sync error for ${item.id}: $e');
        // Optionally increase retry count
        await _isar.writeTxn(() async {
           item.retryCount += 1;
           await _isar.outboxItems.put(item);
        });
      }
    }
  }

  // Implementation helpers
  Future<bool> _pushProject(OutboxItem item) async {
    final project = await _isar.projects.get(int.parse(item.entityId));
    if (project == null) return true; // Deleted?

    if (item.operation == 'DELETE') {
       if (project.serverId != null) {
          await _supabase.from('projects').delete().eq('id', project.serverId!);
       }
       return true;
    }

    final data = {
      'name': project.name,
      'org_id': project.orgId,
      'status': project.status.name,
      'location': project.location,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (project.serverId == null) {
      final res = await _supabase.from('projects').insert(data).select().single();
      await _isar.writeTxn(() async {
        project.serverId = res['id'];
        project.isSynced = true;
        await _isar.projects.put(project);
      });
    } else {
      await _supabase.from('projects').update(data).eq('id', project.serverId!);
    }
    return true;
  }

  Future<bool> _pushWorker(OutboxItem item) async {
    final worker = await _isar.workers.get(int.parse(item.entityId));
    if (worker == null) return true;

    final data = {
      'name': worker.name,
      'org_id': worker.orgId,
      'type': worker.type,
      'daily_rate': worker.dailyRate,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    if (worker.serverId == null) {
      final res = await _supabase.from('workers').insert(data).select().single();
       await _isar.writeTxn(() async {
        worker.serverId = res['id'];
        worker.isSynced = true;
        await _isar.workers.put(worker);
      });
    } else {
      await _supabase.from('workers').update(data).eq('id', worker.serverId!);
    }
    return true;
  }

  Future<bool> _pushReport(OutboxItem item) async {
    final report = await _isar.dailyReports.get(int.parse(item.entityId));
    if (report == null) return true; // Synced successfully (if deleted locally and we processed delete)

    if (item.operation == 'DELETE') {
       if (report.serverId != null) {
          await _supabase.from('daily_reports').delete().eq('id', report.serverId!);
       }
       return true;
    }

    // Dependency Check: Project
    final project = await _isar.projects.get(report.projectId);
    if (project == null || project.serverId == null) {
      // Cannot sync report if project is not synced
      return false; // Retry later
    }

    final data = {
      'project_id': project.serverId,
      'date': report.date.toIso8601String().split('T')[0], // YYYY-MM-DD
      'status': report.status.name,
      'general_note': report.generalNote,
      'weather': report.weather,
      'shift': report.shift,
      'updated_at': DateTime.now().toIso8601String(),
    };

    String? reportUuid;

    if (report.serverId == null) {
      final res = await _supabase.from('daily_reports').insert(data).select().single();
      reportUuid = res['id'];
      
      await _isar.writeTxn(() async {
        report.serverId = reportUuid;
        report.isSynced = true;
        await _isar.dailyReports.put(report);
      });
    } else {
      reportUuid = report.serverId;
      await _supabase.from('daily_reports').update(data).eq('id', report.serverId!);
    }
    
    // Sync Items (Replace strategy)
    if (reportUuid != null) {
       await _supabase.from('report_items').delete().eq('report_id', reportUuid);
       
       if (report.items.isNotEmpty) {
         final itemsData = report.items.map((i) => {
           'report_id': reportUuid,
           'category': i.category,
           'description': i.description,
           'quantity': i.quantity,
           'unit': i.unit,
         }).toList();
         
         await _supabase.from('report_items').insert(itemsData);
       }
    }

    return true;
  }

  Future<bool> _pushAttachment(OutboxItem item) async {
    final reportId = int.tryParse(item.entityId);
    if (reportId == null) return true; // Invalid ID

    final report = await _isar.dailyReports.get(reportId);
    if (report == null) return true; // Deleted

    if (item.operation == 'DELETE') {
       // Handle delete (optional for now)
       return true; 
    }
    
    // Dependency: Report must be synced first to have a UUID
    if (report.serverId == null) return false;

    final dynamic file = File(item.localFilePath!);
    if (!file.existsSync()) {
       // File lost? Skip or keep failing?
       // If file is missing locally, we can't upload. Mark done to avoid infinite loop.
       return true;
    }

    try {
       final fileName = item.localFilePath!.split('/').last;
       final storagePath = '${report.serverId}/$fileName';
       
       // 1. Upload to Supabase Storage
       // upsert: true overwrits if exists
       await _supabase.storage.from('reports').upload(
         storagePath, 
         file,
         fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
       );

       // 2. Get Public URL
       final publicUrl = _supabase.storage.from('reports').getPublicUrl(storagePath);
       
       // 3. Update Local DB
       await _isar.writeTxn(() async {
          // Find attachment by local path
          // Note: attachments is a List<Attachment> (embedded)
          // We need to update the list item.
          final index = report.attachments.indexWhere((a) => a.localPath == item.localFilePath);
          if (index != -1) {
             final att = report.attachments[index];
             att.remoteUrl = publicUrl;
             // We modify the embedded object directly? 
             // Isar requires putting the parent object.
             // We might need to replace the item in the list.
             // But Wait, `att` is reference? No, Isar embedded objects are value types usually or handled specifically.
             // Safer to create copy or modify properties if mutable.
             // Attachment class seems mutable (Step 11322).
             
             // Update the list
             // report.attachments[index] = att; // If valid
             report.attachments = [...report.attachments]; // Trigger Isar detection
             await _isar.dailyReports.put(report);
          }
       });

       // 4. Sync Metadata to 'attachments' table
       final attachmentData = {
         'report_id': report.serverId,
         'file_path': storagePath,
         'local_path': item.localFilePath, // Optional
         'type': 'photo',
         'category': 'site', // Default or fetch from Att
         'created_at': DateTime.now().toIso8601String(),
         // 'remote_url': publicUrl // Not stored in DB usually, constructed from path. But schema?
         // Schema 'attachments' (Step 11325) has: report_id, file_path, type, category, note, taken_at
       };
       
       // We should try to find which attachment it corresponds to to fill category/note.
       final att = report.attachments.firstWhere((a) => a.localPath == item.localFilePath, orElse: () => Attachment());
       if (att.localPath != null) {
          attachmentData['category'] = att.category;
          attachmentData['note'] = att.note;
          attachmentData['taken_at'] = att.takenAt?.toIso8601String();
       }

       await _supabase.from('attachments').insert(attachmentData);

       return true;

    } catch (e) {
       print('Upload Error: $e');
       return false;
    }
  }

  Future<bool> _pushAvatar(OutboxItem item) async {
    final userId = int.tryParse(item.entityId);
    if (userId == null) return true;

    final user = await _isar.users.get(userId);
    if (user == null || user.avatarPath == null) return true;

    if (user.serverId == null) return false; // User not synced?

    final dynamic file = File(item.localFilePath!);
    if (!file.existsSync()) return true;

    try {
       final ext = item.localFilePath!.split('.').last;
       final path = '${user.serverId}/avatar.$ext';
       
       // Upload
       await _supabase.storage.from('avatars').upload(
         path, 
         file,
         fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
       );

       final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);

       // Update Local
       await _isar.writeTxn(() async {
          user.avatarUrl = publicUrl;
          await _isar.users.put(user);
       });

       // Update Auth Metadata (if self)
       if (_supabase.auth.currentUser?.id == user.serverId) {
          await _supabase.auth.updateUser(
             UserAttributes(data: {'avatar_url': publicUrl})
          );
       }
       
       return true;
    } catch(e) {
       print('Avatar Upload Error: $e');
       return false;
    }
  }
  Future<void> pullChanges(DateTime? lastSync) async {
    final lastSyncStr = lastSync?.toIso8601String() ?? '1970-01-01T00:00:00.000Z';
    
    await _syncProjects(lastSyncStr);
    await _syncWorkers(lastSyncStr);
    await _syncReports(lastSyncStr);
  }

  Future<void> _syncProjects(String lastSyncStr) async {
    try {
      final List<dynamic> rows = await _supabase
          .from('projects')
          .select()
          .gt('updated_at', lastSyncStr);

      if (rows.isEmpty) return;

      await _isar.writeTxn(() async {
        for (final row in rows) {
          final serverId = row['id'] as String;
          // Find logic by serverId
          Project? project = await _isar.projects.filter().serverIdEqualTo(serverId).findFirst();
          if (project == null) {
             project = Project()..serverId = serverId..createdAt = DateTime.now();
          }

          project
            ..name = row['name']
            ..orgId = row['org_id']
            ..status = row['status'] == 'active' ? ProjectStatus.active : ProjectStatus.archived
            ..location = row['location']
            ..lastUpdatedAt = DateTime.tryParse(row['updated_at'])
            ..isSynced = true;
          
          await _isar.projects.put(project);
        }
      });
    } catch (e) {
      print('Pull Projects Error: $e');
    }
  }

  Future<void> _syncWorkers(String lastSyncStr) async {
    try {
      final List<dynamic> rows = await _supabase
          .from('workers')
          .select()
          .gt('updated_at', lastSyncStr);

      if (rows.isEmpty) return;

      await _isar.writeTxn(() async {
        for (final row in rows) {
          final serverId = row['id'] as String;
          Worker? worker = await _isar.workers.filter().serverIdEqualTo(serverId).findFirst();
          if (worker == null) {
             worker = Worker()..serverId = serverId..createdAt = DateTime.now();
          }
          
          final dRate = row['daily_rate'];

          worker
            ..name = row['name']
            ..orgId = row['org_id']
            ..type = row['type'] ?? 'worker'
            ..dailyRate = dRate is int ? dRate.toDouble() : dRate
            ..lastUpdatedAt = DateTime.tryParse(row['updated_at'])
            ..isSynced = true;

          await _isar.workers.put(worker);
        }
      });
    } catch (e) {
      print('Pull Workers Error: $e');
    }
  }
  Future<void> _syncReports(String lastSyncStr) async {
    try {
      final List<dynamic> rows = await _supabase
          .from('daily_reports')
          .select('*, report_items(*), attachments(*)')
          .gt('updated_at', lastSyncStr);

      if (rows.isEmpty) return;

      await _isar.writeTxn(() async {
        for (final row in rows) {
          final serverId = row['id'] as String;
          DailyReport? report = await _isar.dailyReports.filter().serverIdEqualTo(serverId).findFirst();
          
          if (report == null) {
             report = DailyReport()..serverId = serverId;
          }

          // Map fields
          report
            ..date = DateTime.parse(row['date'])
            ..generalNote = row['general_note']
            ..weather = row['weather']
            ..shift = row['shift']
            ..status = ReportStatus.values.firstWhere((e) => e.name == row['status'], orElse: () => ReportStatus.draft)
            ..lastUpdatedAt = DateTime.tryParse(row['updated_at'] ?? '')
            ..isSynced = true;
          
          // Map Project ID (Local)
          // We need to find local Project ID by remote project_id
          final remoteProjId = row['project_id'];
          if (remoteProjId != null) {
             final proj = await _isar.projects.filter().serverIdEqualTo(remoteProjId).findFirst();
             if (proj != null) {
                report.projectId = proj.id;
             }
          }

          // Map Items
          if (row['report_items'] != null) {
             final itemsList = row['report_items'] as List;
             report.items = itemsList.map((i) => ReportItem()
               ..category = i['category']
               ..description = i['description']
               ..quantity = (i['quantity'] as num?)?.toDouble()
               ..unit = i['unit']
             ).toList();
          }

          // Map Attachments
          if (row['attachments'] != null) {
             final attList = row['attachments'] as List;
             report.attachments = attList.map((a) {
                final filePath = a['file_path'] as String;
                final publicUrl = _supabase.storage.from('reports').getPublicUrl(filePath);
                
                return Attachment(
                  id: a['id'],
                  type: a['type'],
                  category: a['category'],
                  note: a['note'],
                  remoteUrl: publicUrl,
                  takenAt: DateTime.tryParse(a['taken_at'] ?? ''),
                ); 
             }).toList();
          }

          await _isar.dailyReports.put(report);
        }
      });
    } catch (e) {
      print('Pull Reports Error: $e');
    }
  }
  Future<int> queueUnsyncedData() async {
    int count = 0;
    await _isar.writeTxn(() async {
       // Projects
       final projects = await _isar.projects.filter().serverIdIsNull().findAll();
       for (final p in projects) {
          await _isar.outboxItems.put(OutboxItem()
             ..entityId = p.id.toString()
             ..entityType = 'PROJECT'
             ..operation = 'CREATE'
             ..createdAt = DateTime.now()
          );
          count++;
       }
       
       // Workers
       final workers = await _isar.workers.filter().serverIdIsNull().findAll();
       for (final w in workers) {
          await _isar.outboxItems.put(OutboxItem()
             ..entityId = w.id.toString()
             ..entityType = 'WORKER'
             ..operation = 'CREATE'
             ..createdAt = DateTime.now()
          );
          count++;
       }

       // Reports
       final reports = await _isar.dailyReports.filter().serverIdIsNull().findAll();
       for (final r in reports) {
          await _isar.outboxItems.put(OutboxItem()
             ..entityId = r.id.toString()
             ..entityType = 'REPORT'
             ..operation = 'CREATE'
             ..createdAt = DateTime.now()
          );
          count++;
       }
       
       // Attachments (Check all reports, even synced ones, for unsynced attachments)
       final allReports = await _isar.dailyReports.where().findAll();
       for (final r in allReports) {
          for (final att in r.attachments) {
             if (att.remoteUrl == null && att.localPath != null) {
                 await _isar.outboxItems.put(OutboxItem()
                   ..entityId = r.id.toString()
                   ..entityType = 'ATTACHMENT_PHOTO'
                   ..operation = 'UPLOAD'
                   ..localFilePath = att.localPath
                   ..createdAt = DateTime.now()
                 );
                 count++;
             }
          }
       }
       
       // Avatars
       final users = await _isar.users.where().findAll();
       for (final u in users) {
          if (u.avatarUrl == null && u.avatarPath != null) {
             await _isar.outboxItems.put(OutboxItem()
               ..entityId = u.id.toString()
               ..entityType = 'ATTACHMENT_AVATAR'
               ..operation = 'UPLOAD'
               ..localFilePath = u.avatarPath
               ..createdAt = DateTime.now()
             );
             count++;
          }
       }
    });
    return count;
  }
}

// Web / Mock Implementation
class WebSyncRepository implements SyncRepository {
  final SupabaseClient _supabase;
  WebSyncRepository(this._supabase);

  @override
  Future<void> processOutbox() async {
    debugPrint('WebSyncRepository: No local DB to process outbox (Mock Mode).');
  }

  @override
  Future<void> pullChanges(DateTime? lastSync) async {
    debugPrint('WebSyncRepository: No local DB to pull changes into (Mock Mode).');
  }

  @override
  Future<int> queueUnsyncedData() async {
    return 0;
  }
}
