import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../auth/data/models/security_models.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/init/providers.dart';
import '../../../core/authz/permissions.dart'; // Added
import 'package:isar/isar.dart';


final auditLogsProvider = FutureProvider.autoDispose<List<AuditLog>>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) throw Exception('User not logged in');

  final isar = await ref.watch(isarProvider.future);
  if (isar == null) return [];

  return await isar.auditLogs
      .filter()
      .orgIdEqualTo(user.currentOrgId)
      .sortByTimestampDesc()
      .limit(100)
      .findAll();

});

class AuditLogViewerScreen extends ConsumerWidget {
  const AuditLogViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    
    // Permission Check
    if (currentUser == null || !getEffectivePermissions(role: currentUser.role).contains(AppPermission.auditLogView)) {
       return const Scaffold(
         appBar: CustomAppBar(title: 'Denetim Kayıtları'),
         body: Center(child: Text('Bu sayfayı görüntüleme yetkiniz yok 🔒', style: TextStyle(fontSize: 16))),
       );
    }
    
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Denetim Kayıtları'),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_edu, size: 64, color: Colors.grey),
                  Gap(16),
                  Text('Henüz kayıt yok', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _AuditLogCard(log: log);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  final AuditLog log;

  const _AuditLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getActionColor(log.action),
          child: Icon(_getActionIcon(log.action), color: Colors.white, size: 20),
        ),
        title: Text(
          _getActionTitle(log.action),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(4),
            Text('Kullanıcı: ${log.userId}'),
            if (log.resourceId != null) Text('Kaynak: ${log.resourceId}'),
            if (log.details != null) Text('Detay: ${log.details}'),
            const Gap(4),
            Text(
              DateFormat('dd.MM.yyyy HH:mm').format(log.timestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('delete') || action.contains('remove')) return Colors.red;
    if (action.contains('create') || action.contains('add')) return Colors.green;
    if (action.contains('update') || action.contains('edit')) return Colors.blue;
    if (action.contains('approve') || action.contains('lock')) return Colors.orange;
    return Colors.grey;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('delete') || action.contains('remove')) return Icons.delete;
    if (action.contains('create') || action.contains('add')) return Icons.add;
    if (action.contains('update') || action.contains('edit')) return Icons.edit;
    if (action.contains('approve')) return Icons.check_circle;
    if (action.contains('lock')) return Icons.lock;
    if (action.contains('unlock')) return Icons.lock_open;
    return Icons.info;
  }

  String _getActionTitle(String action) {
    final titles = {
      'policy_update': 'Politika Güncellendi',
      'role_template_update': 'Rol Şablonu Güncellendi',
      'user_override_grant': 'Kullanıcıya İzin Verildi',
      'user_override_deny': 'Kullanıcıdan İzin Kaldırıldı',
      'project_create': 'Proje Oluşturuldu',
      'project_delete': 'Proje Silindi',
      'timesheet_approve': 'Puantaj Onaylandı',
      'timesheet_lock': 'Puantaj Kilitlendi',
      'report_approve': 'Rapor Onaylandı',
      'report_lock': 'Rapor Kilitlendi',
      'share_token_create': 'Paylaşım Linki Oluşturuldu',
    };
    return titles[action] ?? action;
  }
}
