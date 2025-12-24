import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/security_models.dart';
import '../data/models/user_model.dart';
import '../../../core/widgets/locked_feature_placeholder.dart';
import '../../../core/subscription/plan_config.dart';
import '../../../core/subscription/subscription_providers.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  late Future<List<AuditLog>> _logsFuture;
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user != null) {
      _logsFuture = ref.read(authRepositoryProvider).getAuditLogs(user.currentOrgId);
    } else {
      _logsFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAuditEntitlement = ref.watch(hasEntitlementProvider(Entitlement.auditLog)).value ?? false;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Denetim Kayıtları', showProjectChip: false, showSyncStatus: false),
      body: !hasAuditEntitlement
          ? const LockedFeaturePlaceholder(
              featureKey: 'audit_log',
              title: 'Denetim Kayıtları (Audit Log)',
              description: 'Kim, ne zaman, neyi değiştirdi? İşlemleri geriye dönük takip edin.\n\nBu özellik Business pakete dahildir.',
            )
          : FutureBuilder<List<AuditLog>>(
              future: _logsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                   return Center(child: Text('Hata: ${snapshot.error}'));
                }

                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                   return Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
                         const Gap(16),
                         const Text('Henüz kayıt bulunmuyor.', style: TextStyle(color: Colors.grey)),
                       ],
                     ),
                   );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _getActionColor(log.action),
                        radius: 16,
                        child: Icon(_getActionIcon(log.action), color: Colors.white, size: 16),
                      ),
                      title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                        '${log.details ?? '-'} \n${DateFormat('dd MMM yyyy HH:mm').format(log.timestamp)}', 
                        style: const TextStyle(fontSize: 11),
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
            ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('DELETE')) return Colors.red;
    if (action.contains('CREATE')) return Colors.green;
    if (action.contains('UPDATE')) return Colors.blue;
    if (action.contains('LOCK')) return Colors.orange;
    return Colors.grey;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('DELETE')) return Icons.delete_outline;
    if (action.contains('CREATE')) return Icons.add;
    if (action.contains('UPDATE')) return Icons.edit;
    if (action.contains('LOCK')) return Icons.lock_outline;
    return Icons.info_outline;
  }
}
