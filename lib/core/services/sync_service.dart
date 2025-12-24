import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter/services.dart'; // For NetworkAssetBundle (Web Blob support)
import '../init/providers.dart';
import '../api/api_service.dart';
import '../../features/project/data/models/project_model.dart';
import '../../features/project/data/models/worker_model.dart';
import '../../features/project/data/models/project_worker_model.dart';
import '../../features/report/data/models/daily_report_model.dart';
import '../../features/attendance/data/models/attendance_model.dart';
import '../sync/data/models/outbox_item.dart';
import 'package:puantaj_x/core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import 'dart:async'; // For Timer
import '../providers/global_providers.dart';
import '../services/notification_service.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/project/presentation/providers/project_providers.dart';
import '../../features/report/presentation/providers/report_providers.dart';

class SyncService {
  final Isar? isar;
  final IApiService api;
  final Ref ref;

  SyncService(this.isar, this.api, this.ref);

  Future<void> syncAll() async {
    final i = isar;
    if (i == null) {
      debugPrint('Sync: Isar is null, skipping sync.');
      return;
    }
    // Re-entrancy Check
    if (ref.read(syncStatusProvider) == SyncStatus.syncing) {
        debugPrint('Sync: Already syncing, skipping trigger.');
        return;
    }

    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;
    ref.read(lastSyncErrorProvider.notifier).state = null; // Clear previous error

    // --- AUTO-REPAIR METADATA (START) ---
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final metadata = user.userMetadata;
        final hasCode = metadata?['org_code'] != null;
        final orgName = metadata?['org_name'] as String?;
        
        if (!hasCode && orgName != null) {
           debugPrint('Auto-Repair: Injecting missing org_code into metadata for "$orgName"...');
           final code = orgName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
           
           await Supabase.instance.client.auth.updateUser(
             UserAttributes(data: {'org_code': code}),
           );
           await Supabase.instance.client.auth.refreshSession();
           debugPrint('Auto-Repair: Success. New Code: $code');
        }
      }
    } catch (e) {
      debugPrint('Auto-Repair Failed (Non-critical): $e');
    }

    // --- AUTO-FIX DATA OWNERSHIP (START) ---
    try {
       final user = Supabase.instance.client.auth.currentUser;
       if (user != null) {
          final orgName = user.userMetadata?['org_name'] as String?;
          final orgCode = user.userMetadata?['org_code'] as String?;
          
          if (orgName != null) {
             final currentOrgCode = orgCode ?? orgName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
             
             await i.writeTxn(() async {
                final wrongProjects = await (i as dynamic).projects.filter().not().orgIdEqualTo(currentOrgCode).findAll();
                for (var p in wrongProjects) {
                   p.orgId = currentOrgCode;
                   p.isSynced = false; 
                   await (i as dynamic).projects.put(p);
                }
                
                final wrongWorkers = await (i as dynamic).workers.filter().not().orgIdEqualTo(currentOrgCode).findAll();
                for (var w in wrongWorkers) {
                   w.orgId = currentOrgCode;
                   w.isSynced = false;
                   await (i as dynamic).workers.put(w);
                }

                final wrongReports = await (i as dynamic).dailyReports.filter().not().orgIdEqualTo(currentOrgCode).findAll();
                for (var r in wrongReports) {
                   r.orgId = currentOrgCode;
                   r.isSynced = false;
                   await (i as dynamic).dailyReports.put(r);
                }
             });
          }
       }
    } catch (e) {
       debugPrint('Auto-Fix Ownership Failed: $e');
    }

    debugPrint('Sync started...');
    bool hasError = false;

    try {
      hasError |= await processOutbox(); 
      hasError |= await syncProjects();
      hasError |= await syncWorkers();
      hasError |= await syncProjectWorkers();
      hasError |= await syncAttendances(); 
      hasError |= await syncDailyReports();
      
      debugPrint('Sync completed. Has Error: $hasError');
      
      if (hasError) {
         ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      } else {
         ref.read(syncStatusProvider.notifier).state = SyncStatus.synced;
      }
    } catch (e) {
      debugPrint('Sync Critical Error: $e');
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      ref.read(lastSyncErrorProvider.notifier).state = e.toString();
      
      final settings = ref.read(notificationSettingsProvider);
      if (settings.syncError) {
        ref.read(notificationServiceProvider).showSyncError(e.toString());
      }
    }
  }

  String _getSessionOrgCode() {
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    var code = metadata?['org_code'] as String?;
    final name = metadata?['org_name'] as String?;
    
    if (code == null && name != null) {
      code = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    }
    return code ?? 'DEFAULT';
  }

  Future<bool> syncProjects() async {
    final i = isar;
    if (i == null) return false;
    bool errorOccurred = false;
    final sessionOrgCode = _getSessionOrgCode();

    final unsynced = await (i as dynamic).projects.filter().isSyncedEqualTo(false).findAll();
    for (final item in unsynced) {
      try {
        final data = {
          'name': item.name,
          'status': item.status.name,
          'created_at': item.createdAt?.toIso8601String(),
          'project_code': item.projectCode,
          'location': item.location,
          'serverId': item.serverId,
          'org_id': sessionOrgCode,
        };
        
        final response = await api.push('projects', data);

        await i.writeTxn(() async {
          item.isSynced = true;
          item.orgId = sessionOrgCode;
          if (item.serverId == null && response['id'] != null) {
             item.serverId = response['id'].toString();
          }
          item.lastUpdatedAt = DateTime.now();
          await (i as dynamic).projects.put(item);
        });
      } catch (e) {
        debugPrint('Error pushing project: $e');
        errorOccurred = true;
      }
    }

    try {
      final remoteData = await api.pull('projects', null); 
      if (remoteData.isEmpty) {
         final localCount = await (i as dynamic).projects.count();
         if (localCount > 0) {
            await i.writeTxn(() async {
               final all = await (i as dynamic).projects.where().findAll();
               for (var p in all) {
                 p.isSynced = false;
                 p.orgId = sessionOrgCode;
                 await (i as dynamic).projects.put(p);
               }
            });
            return errorOccurred;
         }
      }

      await i.writeTxn(() async {
        for (final remote in remoteData) {
           final serverId = remote['id'].toString();
           var local = await (i as dynamic).projects.filter().serverIdEqualTo(serverId).findFirst();
           if (local == null) {
              local = Project()
                ..serverId = serverId
                ..name = remote['name'] ?? 'Adsız Proje'
                ..status = ProjectStatus.values.firstWhere((e) => e.name == remote['status'], orElse: () => ProjectStatus.active)
                ..orgId = remote['org_id'] ?? 'DEFAULT'
                ..createdAt = DateTime.tryParse(remote['created_at'] ?? '') ?? DateTime.now()
                ..lastUpdatedAt = DateTime.now()
                ..isSynced = true;
              await (i as dynamic).projects.put(local);
           }
        }
      });
    } catch (e) {
      errorOccurred = true;
    }
    return errorOccurred;
  }

  Future<bool> syncWorkers() async {
    final i = isar;
    if (i == null) return false;
    bool errorOccurred = false;
    final sessionOrgCode = _getSessionOrgCode();

    final unsynced = await (i as dynamic).workers.filter().isSyncedEqualTo(false).findAll();
    for (final item in unsynced) {
      try {
        final data = {
          'name': item.name,
          'active': item.active,
          'serverId': item.serverId,
          'org_id': sessionOrgCode,
          'pay_type': item.payType.name,
          'daily_rate': item.dailyRate,
          'hourly_rate': item.hourlyRate,
          'currency': item.currency,
          'phone': item.phone,
          'iban': item.iban,
        };
        final response = await api.push('workers', data);
        await i.writeTxn(() async {
          item.isSynced = true;
          item.orgId = sessionOrgCode;
          if (item.serverId == null && response['id'] != null) {
            item.serverId = response['id'].toString();
          }
          item.lastUpdatedAt = DateTime.now();
          await (i as dynamic).workers.put(item);
        });
      } catch (e) {
        errorOccurred = true;
      }
    }

    try {
      final remoteData = await api.pull('workers', null);
      if (remoteData.isEmpty) {
         final localCount = await (i as dynamic).workers.count();
         if (localCount > 0) {
            await i.writeTxn(() async {
               final all = await (i as dynamic).workers.where().findAll();
               for (var w in all) {
                 w.isSynced = false;
                 w.orgId = sessionOrgCode;
                 await (i as dynamic).workers.put(w);
               }
            });
            return errorOccurred;
         }
      }

      await i.writeTxn(() async {
        for (final remote in remoteData) {
          final serverId = remote['id'].toString();
          var local = await (i as dynamic).workers.filter().serverIdEqualTo(serverId).findFirst();
          if (local == null) {
            local = Worker()
              ..serverId = serverId
              ..name = remote['name'] ?? 'İsimsiz'
              ..active = remote['active'] ?? true
              ..payType = PayType.values.firstWhere((e) => e.name == remote['pay_type'], orElse: () => PayType.monthly)
              ..dailyRate = (remote['daily_rate'] as num?)?.toDouble()
              ..hourlyRate = (remote['hourly_rate'] as num?)?.toDouble()
              ..currency = remote['currency'] ?? 'TRY'
              ..orgId = remote['org_id'] ?? 'DEFAULT'
              ..isSynced = true
              ..createdAt = DateTime.tryParse(remote['created_at'] ?? '') ?? DateTime.now()
              ..lastUpdatedAt = DateTime.now();
            await (i as dynamic).workers.put(local);
          }
        }
      });
    } catch (e) {
      errorOccurred = true; 
    }
    return errorOccurred;
  }

  Future<bool> syncDailyReports() async {
    final i = isar;
    if (i == null) return false;
    bool errorOccurred = false;
    final sessionOrgCode = _getSessionOrgCode();

    final unsynced = await (i as dynamic).dailyReports.filter().isSyncedEqualTo(false).findAll();
    for (final item in unsynced) {
      try {
        final project = await (i as dynamic).projects.get(item.projectId);
        final data = {
          'project_id': project?.serverId, 
          'date': item.date.toIso8601String(),
          'weather': item.weather,
          'shift': item.shift,
          'general_note': item.generalNote,
          'status': item.status.name,
          'org_id': sessionOrgCode,
          'items': item.items.map((e) => {
             'category': e.category,
             'description': e.description,
             'quantity': e.quantity,
             'unit': e.unit,
          }).toList(),
          'attachments': item.attachments.map((e) => {
             'id': e.id,
             'type': e.type,
             'remote_url': e.remoteUrl,
             'category': e.category,
             'note': e.note,
          }).toList(),
        };

        final response = await api.push('daily_reports', data);
        await i.writeTxn(() async {
          item.isSynced = true;
          item.orgId = sessionOrgCode;
          if (item.serverId == null && response['id'] != null) {
            item.serverId = response['id'].toString();
          }
          item.lastUpdatedAt = DateTime.now();
          await (i as dynamic).dailyReports.put(item);
        });
      } catch (e) {
        errorOccurred = true;
      }
    }

    try {
      final remoteData = await api.pull('daily_reports', null); 
      if (remoteData.isEmpty) {
         final localCount = await (i as dynamic).dailyReports.count();
         if (localCount > 0) {
            await i.writeTxn(() async {
               final all = await (i as dynamic).dailyReports.where().findAll();
               for (var r in all) {
                 r.isSynced = false;
                 r.orgId = sessionOrgCode;
                 await (i as dynamic).dailyReports.put(r);
               }
            });
            return errorOccurred;
         }
      }

      await i.writeTxn(() async {
        for (final remote in remoteData) {
           final serverId = remote['id'].toString();
           final projectServerId = remote['project_id'].toString();
           final project = await (i as dynamic).projects.filter().serverIdEqualTo(projectServerId).findFirst();
           if (project != null) {
               var local = await (i as dynamic).dailyReports.filter().serverIdEqualTo(serverId).findFirst();
               if (local == null) {
                  local = DailyReport()
                    ..serverId = serverId
                    ..projectId = project.id
                    ..date = DateTime.tryParse(remote['date'] ?? '') ?? DateTime.now()
                    ..weather = remote['weather']
                    ..shift = remote['shift']
                    ..generalNote = remote['general_note']
                    ..status = ReportStatus.values.firstWhere((e) => e.name == remote['status'], orElse: () => ReportStatus.draft)
                    ..orgId = remote['org_id'] ?? 'DEFAULT'
                    ..items = (remote['items'] as List?)?.map((e) => ReportItem()
                        ..category = e['category']
                        ..description = e['description']
                        ..quantity = (e['quantity'] as num?)?.toDouble()
                        ..unit = e['unit']
                    ).toList() ?? []
                    ..attachments = (remote['attachments'] as List?)?.map((e) => Attachment(
                        id: e['id'],
                        type: e['type'],
                        remoteUrl: e['remote_url'],
                        category: e['category'],
                        note: e['note'],
                    )).toList() ?? []
                    ..isSynced = true
                    ..lastUpdatedAt = DateTime.now();
                  await (i as dynamic).dailyReports.put(local);
               }
           }
        }
      });
    } catch (e) {
      errorOccurred = true;
    }
    return errorOccurred;
  }

  Future<bool> syncProjectWorkers() async {
    final i = isar;
    if (i == null) return false;
    bool errorOccurred = false;
    final unsynced = await (i as dynamic).projectWorkers.filter().isSyncedEqualTo(false).findAll();
    for (final item in unsynced) {
      try {
        final project = await (i as dynamic).projects.get(item.projectId);
        final worker = await (i as dynamic).workers.get(item.workerId);
        String? crewServerId;
        if (item.crewId != null) {
          final crew = await (i as dynamic).workers.get(item.crewId!);
          crewServerId = crew?.serverId;
        }

        if (project?.serverId == null || worker?.serverId == null) continue;

        final sessionOrgCode = _getSessionOrgCode();
        final data = {
          'project_id': project!.serverId,
          'worker_id': worker!.serverId,
          'crew_id': crewServerId,
          'is_active': item.isActive,
          'assigned_at': item.assignedAt.toIso8601String(),
          'serverId': item.serverId,
          'org_id': sessionOrgCode,
        };
        
        final response = await api.push('project_workers', data);
        await i.writeTxn(() async {
          item.isSynced = true;
          if (item.serverId == null && response['id'] != null) {
             item.serverId = response['id'].toString();
          }
          item.lastUpdatedAt = DateTime.now();
          await (i as dynamic).projectWorkers.put(item);
        });
      } catch (e) {
        errorOccurred = true;
      }
    }
    try {
      final remoteData = await api.pull('project_workers', null);
      await i.writeTxn(() async {
        for (final remote in remoteData) {
           final serverId = remote['id'].toString();
           final projectServerId = remote['project_id'];
           final workerServerId = remote['worker_id'];
           final project = await (i as dynamic).projects.filter().serverIdEqualTo(projectServerId).findFirst();
           final worker = await (i as dynamic).workers.filter().serverIdEqualTo(workerServerId).findFirst();

           if (project != null && worker != null) {
               var local = await (i as dynamic).projectWorkers.filter().serverIdEqualTo(serverId).findFirst();
               if (local == null) {
                 local = ProjectWorker()
                   ..serverId = serverId
                   ..projectId = project.id
                   ..workerId = worker.id
                   ..isActive = remote['is_active'] ?? true
                   ..assignedAt = DateTime.tryParse(remote['assigned_at'] ?? '') ?? DateTime.now()
                   ..isSynced = true
                   ..lastUpdatedAt = DateTime.now();
                 await (i as dynamic).projectWorkers.put(local);
               }
           }
        }
      });
    } catch (e) {
      errorOccurred = true;
    }
    return errorOccurred;
  }

  Future<bool> processOutbox() async {
    final i = isar;
    if (i == null) return false;
    bool errorOccurred = false;
    final items = await (i as dynamic).outboxItems.filter().isProcessedEqualTo(false).sortByCreatedAt().findAll();
    
    for (final item in items) {
       try {
         if (item.operation == 'UPLOAD' && item.entityType == 'ATTACHMENT_PHOTO') {
            await _processPhotoUpload(item);
         } else if (item.operation == 'DELETE') {
            await _processDelete(item);
         }
         await i.writeTxn(() async {
           await (i as dynamic).outboxItems.delete(item.id);
         });
       } catch (e) {
          errorOccurred = true;
       }
    }
    return errorOccurred;
  }

  Future<void> _processDelete(OutboxItem item) async {
     final collection = _getCollectionName(item.entityType);
     if (collection == null) return;
     await api.delete(collection, item.entityId);
  }

  String? _getCollectionName(String type) {
     switch (type) {
       case 'REPORT': return 'daily_reports';
       case 'PROJECT': return 'projects';
       case 'WORKER': return 'workers';
       case 'ATTENDANCE': return 'attendances';
       default: return null;
     }
  }

  Future<void> _processPhotoUpload(OutboxItem item) async {
     final i = isar;
     if (i == null || item.localFilePath == null) return;
     final fileName = '${DateTime.now().millisecondsSinceEpoch}_${item.localFilePath!.split('/').last}';
     final path = 'uploads/$fileName';

     if (kIsWeb) {
        try {
           final ByteData data = await NetworkAssetBundle(Uri.parse(item.localFilePath!)).load(item.localFilePath!);
           final bytes = data.buffer.asUint8List();
           await Supabase.instance.client.storage.from('report_files').uploadBinary(path, bytes);
        } catch (e) { return; }
     } else {
        final dynamic file = File(item.localFilePath!);
        if (!await file.exists()) return;
        await Supabase.instance.client.storage.from('report_files').upload(path, file);
     }

     final publicUrl = Supabase.instance.client.storage.from('report_files').getPublicUrl(path);
     if (item.entityId.isEmpty) return;
     final reportId = int.tryParse(item.entityId);
     if (reportId == null) return;

     final report = await (i as dynamic).dailyReports.get(reportId);
     if (report != null) {
        bool changed = false;
        final newAttachments = List<Attachment>.from(report.attachments);
        for (var idx = 0; idx < newAttachments.length; idx++) {
           if (newAttachments[idx].localPath == item.localFilePath) {
              newAttachments[idx].remoteUrl = publicUrl;
              changed = true;
           }
        }
        if (changed) {
          await i.writeTxn(() async {
            report.attachments = newAttachments;
            await (i as dynamic).dailyReports.put(report);
          });
        }
     }
  }
  
  Future<void> triggerSync() async {
    final results = await Connectivity().checkConnectivity();
    final isConnected = results.any((r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth);
    if (isConnected) {
       syncAll();
    }
  }

  bool _isAutoSyncInitialized = false;

  void initializeAutoSync() {
    if (_isAutoSyncInitialized) return;
    _isAutoSyncInitialized = true;
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
       final isConnected = results.any((r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth);
       if (isConnected) {
         if (!kIsWeb) syncAll();
         _subscribeToRealtime();
       }
    });

    // On Web, subscribe immediately if connected (Connectivity might not emit initially)
    if (kIsWeb) {
      _subscribeToRealtime();
    }
  }

  RealtimeChannel? _subscription;
  Timer? _debounceTimer;

  void _subscribeToRealtime() {
    if (_subscription != null) return;
    try {
      debugPrint('Realtime: Subscribing to public changes...');
      _subscription = Supabase.instance.client
          .channel('public:db_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            callback: (payload) {
               debugPrint('Realtime Change Detected: ${payload.table}');
               
               if (kIsWeb) {
                 // On Web, we invalidate providers directly
                 _invalidateProvidersForTable(payload);
               } else {
                 // For Mobile, we trigger a sync
                 _debounceSync();
               }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime Subscription Error: $e');
    }
  }

  void _invalidateProvidersForTable(PostgresChangePayload payload) {
    final table = payload.table;
    final record = payload.newRecord;
    
    switch (table) {
      case 'projects':
        ref.invalidate(projectsProvider);
        break;
      case 'workers':
        ref.invalidate(availableWorkersProvider);
        break;
      case 'project_workers':
        if (record['project_id'] != null) {
          final pId = WebIdCache().store(record['project_id'].toString());
          ref.invalidate(availableWorkersProvider(pId));
          ref.invalidate(projectWorkersProvider(pId));
        } else {
          ref.invalidate(projectsProvider); // Shotgun approach if ID unknown
        }
        break;
      case 'daily_reports':
        if (record['project_id'] != null) {
          final pId = WebIdCache().store(record['project_id'].toString());
          ref.invalidate(projectReportsProvider(pId));
        } else {
           ref.invalidate(projectsProvider);
        }
        break;
      case 'organization_members':
        ref.invalidate(organizationMembersProvider);
        break;
      case 'attendances':
        if (record['project_id'] != null) {
           final pId = WebIdCache().store(record['project_id'].toString());
           // Invalidate attendance related providers if you have them,
           // or reports if they depend on attendance.
           ref.invalidate(projectReportsProvider(pId));
        }
        break;
    }
  }

  void _debounceSync() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
       triggerSync();
    });
  }

  Future<bool> syncAttendances() async {
    final i = isar;
    if (i == null) return false;
    bool errorOccurred = false;
    final sessionOrgCode = _getSessionOrgCode();

    final unsynced = await (i as dynamic).attendances.filter().isSyncedEqualTo(false).findAll();
    for (final item in unsynced) {
      try {
        final project = await (i as dynamic).projects.get(item.projectId);
        final worker = await (i as dynamic).workers.get(item.workerId);
        if (project?.serverId == null || worker?.serverId == null) continue;

        final data = {
          'project_id': project!.serverId,
          'worker_id': worker!.serverId,
          'date': item.date.toIso8601String().split('T')[0],
          'hours': item.hours,
          'overtime_hours': item.overtimeHours,
          'status': item.status.name,
          'day_type': item.dayType.name,
          'workflow_status': item.workflowStatus.name,
          'note': item.note,
          'org_id': sessionOrgCode,
          'serverId': item.serverId,
        };

        final response = await api.push('attendances', data);
        if (response != null && response['id'] != null) {
          await i.writeTxn(() async {
            item
              ..serverId = response['id']
              ..isSynced = true
              ..lastUpdatedAt = DateTime.now();
            await (i as dynamic).attendances.put(item);
          });
        }
      } catch (e) {
        errorOccurred = true;
      }
    }

    try {
      final lastSync = await (i as dynamic).attendances.where().sortByLastUpdatedAtDesc().findFirst();
      final remoteData = await api.pull('attendances', lastSync?.lastUpdatedAt);
      if (remoteData.isNotEmpty) {
        await i.writeTxn(() async {
          for (final remote in remoteData) {
              final remoteId = remote['id'];
              final projectIdStr = remote['project_id'];
              final workerIdStr = remote['worker_id'];
              if (projectIdStr == null || workerIdStr == null) continue;
              final localProject = await (i as dynamic).projects.filter().serverIdEqualTo(projectIdStr).findFirst();
              final localWorker = await (i as dynamic).workers.filter().serverIdEqualTo(workerIdStr).findFirst();
              if (localProject == null || localWorker == null) continue;

              var local = await (i as dynamic).attendances.filter().serverIdEqualTo(remoteId).findFirst();
              if (local == null) local = Attendance()..serverId = remoteId;
              
              local
                ..projectId = localProject.id
                ..workerId = localWorker.id
                ..date = DateTime.tryParse(remote['date'] ?? '') ?? DateTime.now()
                ..hours = (remote['hours'] as num?)?.toDouble() ?? 0
                ..overtimeHours = (remote['overtime_hours'] as num?)?.toDouble() ?? 0
                ..status = AttendanceStatus.values.firstWhere((e) => e.name == remote['status'], orElse: () => AttendanceStatus.present)
                ..dayType = DayType.values.firstWhere((e) => e.name == remote['day_type'], orElse: () => DayType.normal)
                ..workflowStatus = WorkflowStatus.values.firstWhere((e) => e.name == remote['workflow_status'], orElse: () => WorkflowStatus.draft)
                ..note = remote['note']
                ..approvedBy = remote['approved_by']
                ..approvedAt = DateTime.tryParse(remote['approved_at'] ?? '')
                ..isSynced = true
                ..lastUpdatedAt = DateTime.now();
              await (i as dynamic).attendances.put(local);
          }
        });
      }
    } catch (e) {
       errorOccurred = true;
    }
    return errorOccurred;
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final isar = ref.watch(isarProvider).valueOrNull;
  final api = ref.watch(apiServiceProvider);
  return SyncService(isar, api, ref);
});
