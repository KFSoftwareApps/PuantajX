import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/global_providers.dart';
import '../services/sync_service.dart';
import '../../features/project/presentation/providers/project_providers.dart';
import '../../features/project/presentation/providers/active_project_provider.dart';
import '../../features/project/data/models/project_model.dart';

class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showSyncStatus;
  final bool showProjectChip;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showProjectChip = true,
    this.showSyncStatus = true,
    this.showBackButton = true,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProjectAsync = ref.watch(activeProjectProvider);
    final projects = ref.watch(projectsProvider).valueOrNull ?? [];
    final syncStatus = ref.watch(syncStatusProvider);

    final selectedProject = activeProjectAsync.valueOrNull;

    return AppBar(
      automaticallyImplyLeading: showBackButton,
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showProjectChip && projects.isNotEmpty) ...[
            const Gap(8),
            Flexible(
              child: _ProjectChip(
                selectedProject: selectedProject ?? (projects.isNotEmpty ? projects.first : null),
                projects: projects,
                onSelected: (id) {
                  ref.read(activeProjectProvider.notifier).set(id);
                },
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        const Gap(8),
        if (showSyncStatus) ...[
          _SyncStatusBadge(status: syncStatus),
          const Gap(16),
        ],
      ],
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}

class _ProjectChip extends StatelessWidget {
  final dynamic selectedProject;
  final List<dynamic> projects;
  final Function(int) onSelected;

  const _ProjectChip({
    required this.selectedProject,
    required this.projects,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showProjectSelector(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).primaryColor.withAlpha(77)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment, size: 14),
            const Gap(4),
            Flexible(
              child: Text(
                (selectedProject is Project ? selectedProject.name : selectedProject?.name) ?? 'Proje Seç',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  void _showProjectSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final p = projects[index];
            return ListTile(
              leading: const Icon(Icons.business),
              title: Text(p.name),
              subtitle: Text(p.location ?? ''),
              onTap: () {
                onSelected(p.id);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}

class _SyncStatusBadge extends ConsumerWidget {
  final SyncStatus status;
  const _SyncStatusBadge({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color color;
    IconData icon;
    String text;
    
    final queueCountAsync = ref.watch(syncQueueProvider);
    final queueCount = queueCountAsync.valueOrNull ?? 0;

    switch (status) {
      case SyncStatus.synced:
        color = Colors.green;
        icon = Icons.cloud_done;
        text = 'Senkronize';
        break;
      case SyncStatus.syncing:
        color = Colors.blue;
        icon = Icons.sync;
        text = 'Eşitleniyor...';
        break;
      case SyncStatus.offline:
        color = Colors.grey;
        icon = Icons.cloud_off;
        text = 'Çevrimdışı';
        break;
       case SyncStatus.error:
        color = Colors.red;
        icon = Icons.error_outline;
        text = 'Hata';
        break;
    }

    if (queueCount > 0 && status != SyncStatus.syncing) {
       text = '$queueCount öğe sırada';
       icon = Icons.cloud_upload;
       color = Colors.orange;
    }

    // Wrap everything in a gesture detector to allow manual sync
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Senkronizasyon başlatılıyor...'), duration: Duration(seconds: 1)),
        );
        ref.read(syncServiceProvider).syncAll();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == SyncStatus.syncing)
               const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
            else
               Icon(icon, color: color, size: 16),
            const Gap(6),
            Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
