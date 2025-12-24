import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'providers/project_providers.dart';
import 'widgets/assign_worker_sheet.dart';
import 'widgets/crew_detail_sheet.dart';
import '../../workers/presentation/widgets/worker_form_sheet.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/authz/permissions.dart';
import '../../../../core/widgets/permission_guard.dart';
import '../../../../features/auth/data/repositories/auth_repository.dart';

class ProjectTeamScreen extends ConsumerStatefulWidget {
  final int projectId;

  const ProjectTeamScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectTeamScreen> createState() => _ProjectTeamScreenState();
}

class _ProjectTeamScreenState extends ConsumerState<ProjectTeamScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workersAsync = ref.watch(projectWorkersProvider(widget.projectId));
    final projectAsync = ref.watch(projectByIdProvider(widget.projectId));
    final projectName = projectAsync.valueOrNull?.name ?? 'Proje';

    return Scaffold(
      appBar: CustomAppBar(
        title: '$projectName Ekibi',
        showProjectChip: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Personel'),
            Tab(text: 'Ekipler'),
          ],
        ),
      ),
      floatingActionButton: PermissionGuard(
        permission: AppPermission.projectUpdate,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddOptions(context),
          label: const Text('Ekle'),
          icon: const Icon(Icons.add),
        ),
      ),
      body: workersAsync.when(
        data: (allWorkers) {
          final workers = allWorkers.where((w) => w.type != 'crew').toList();
          final crews = allWorkers.where((w) => w.type == 'crew').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              PermissionGuard(
                permission: AppPermission.workerRead,
                fallback: const Center(child: Text('Personel listesini görüntüleme yetkiniz yok.')),
                child: _WorkerList(workers: workers, projectId: widget.projectId)
              ),
              PermissionGuard(
                permission: AppPermission.workerRead,
                 fallback: const Center(child: Text('Ekip listesini görüntüleme yetkiniz yok.')),
                child: _CrewList(crews: crews, projectId: widget.projectId)
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Mevcut Personel Ekle'),
              subtitle: const Text('Havuzdan projeye dahil et'),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => AssignWorkerSheet(projectId: widget.projectId),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('Yeni Personel Oluştur'),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => WorkerFormSheet(
                    initialProjectId: widget.projectId,
                    initialType: 'worker',
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Yeni Ekip Oluştur'),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => WorkerFormSheet(
                    initialProjectId: widget.projectId,
                    initialType: 'crew',
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerList extends ConsumerWidget {
  final List<dynamic> workers; 
  final int projectId;

  const _WorkerList({required this.workers, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
            const Gap(16),
            const Text('Bu projede personel bulunmuyor.'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: workers.length,
      itemBuilder: (context, index) {
        final worker = workers[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.person, color: Colors.blue),
            ),
            title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (worker.trade != null && worker.trade!.isNotEmpty)
                  Text(worker.trade!, style: TextStyle(color: Colors.grey[700])),
                 PermissionGuard(
                    permission: AppPermission.financeView,
                    child: worker.dailyRate != null
                        ? Text(
                            'Günlük: ${worker.dailyRate} ${worker.currency}',
                            style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                          )
                        : const SizedBox.shrink(),
                 ),
              ],
            ),
            onTap: () {
               // Security Check: Update permission required to edit
               final canEdit = ref.read(currentPermissionsProvider).valueOrNull?.contains(AppPermission.workerUpdate) ?? false;
               if (!canEdit) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Düzenleme yetkiniz yok (Sadece Görüntüleme).')));
                 return;
               }

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => WorkerFormSheet(
                  workerId: worker.id,
                  initialProjectId: projectId,
                ),
              );
            },
            trailing: PermissionGuard(
              permission: AppPermission.projectUpdate,
              child: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _confirmRemove(context, ref, projectId, worker.id, worker.name),
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, int projectId, int workerId, String name) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projeden Çıkar'),
        content: Text('$name isimli çalışanın bu proje ile ilişkisini kesmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(projectWorkersProvider(projectId).notifier).removeWorker(workerId);
            },
            child: const Text('Çıkar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CrewList extends ConsumerWidget {
  final List<dynamic> crews;
  final int projectId;

  const _CrewList({required this.crews, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (crews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_off_outlined, size: 64, color: Colors.grey),
            const Gap(16),
            const Text('Henüz ekip oluşturulmamış.'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: crews.length,
      itemBuilder: (context, index) {
        final crew = crews[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: const Icon(Icons.group, color: Colors.orange),
            ),
            title: Text(crew.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${crew.description ?? "Açıklama yok"}'),
            onTap: () {
               showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => CrewDetailSheet(projectId: projectId, crew: crew),
                );
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PermissionGuard(
                  permission: AppPermission.projectUpdate,
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (context) => WorkerFormSheet(
                          workerId: crew.id,
                          initialProjectId: projectId,
                        ),
                      );
                    },
                  ),
                ),
                PermissionGuard(
                  permission: AppPermission.projectUpdate,
                  child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmRemove(context, ref, projectId, crew.id, crew.name),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
   void _confirmRemove(BuildContext context, WidgetRef ref, int projectId, int workerId, String name) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ekibi Sil'),
        content: Text('$name ekibini silmek istiyor musunuz? (Bağlı çalışanlar silinmez, sadece ekip tanımı kalkar.)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(projectWorkersProvider(projectId).notifier).removeWorker(workerId); 
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
