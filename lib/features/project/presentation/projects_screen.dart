import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/subscription/subscription_service.dart';
import '../../../core/subscription/subscription_providers.dart'; // Added for provider
import '../../payment/presentation/paywall_screen.dart';
import '../data/models/project_model.dart';
import 'providers/project_providers.dart';
import 'widgets/project_card.dart';
import '../../../core/authz/permissions.dart';
import '../../../core/widgets/permission_guard.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/sync_service.dart'; // Added for syncServiceProvider

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> with SingleTickerProviderStateMixin {
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
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projeler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Genel Ekip Yönetimi',
            onPressed: () => context.go('/projects/workers'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Aktif Projeler', icon: Icon(Icons.business)),
            Tab(text: 'Arşiv', icon: Icon(Icons.archive)),
          ],
        ),
      ),
      floatingActionButton: PermissionGuard(
        permission: AppPermission.projectCreate,
        child: FloatingActionButton.extended(
          onPressed: () => _handleCreateProject(context, ref),
          label: const Text('Proje Ekle'),
          icon: const Icon(Icons.add),
        ),
      ),
      body: projectsAsync.when(
        data: (allProjects) {
          final activeProjects = allProjects.where((p) => p.status == ProjectStatus.active).toList();
          final archivedProjects = allProjects.where((p) => p.status == ProjectStatus.archived).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // Active Projects Tab
              _buildProjectsList(activeProjects, isArchive: false),
              // Archive Tab
              _buildProjectsList(archivedProjects, isArchive: true),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Widget _buildProjectsList(List<Project> projects, {required bool isArchive}) {
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isArchive ? Icons.archive_outlined : Icons.business_outlined,
                size: 64,
                color: Colors.blueGrey,
              ),
            ),
            const Gap(24),
            Text(
              isArchive
                  ? 'Arşivlenmiş proje yok.'
                  : 'Henüz aktif proje yok.\nİlk projeni oluşturarak başla.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Sort: Active project first
    final activeProjectId = ref.read(selectedProjectIdProvider);
    final sortedProjects = [...projects];
    if (!isArchive) {
      sortedProjects.sort((a, b) {
        if (a.id == activeProjectId) return -1;
        if (b.id == activeProjectId) return 1;
        return 0;
      });
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(syncServiceProvider).triggerSync();
        // Determine manual delay or wait for sync? triggerSync is async but fires and forgets mostly.
        // We can wait a bit to let UI update via stream.
        await Future.delayed(const Duration(seconds: 1)); 
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedProjects.length,
        itemBuilder: (context, index) {
          final project = sortedProjects[index];
          return ProjectCard(
            key: ValueKey(project.id),
            project: project,
            onTap: () => context.go('/projects/${project.id}'),
            onEdit: (p) => _showEditProjectDialog(context, ref, p),
            onDelete: (p) => _confirmDelete(context, ref, p),
          );
        },
      ),
    );
  }


  void _showEditProjectDialog(BuildContext context, WidgetRef ref, Project project) {
    // Re-use create dialog logic but populate fields
    final nameController = TextEditingController(text: project.name);
    final locationController = TextEditingController(text: project.location);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Projeyi Düzenle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Gap(16),
              CustomTextField(
                label: 'Proje Adı',
                controller: nameController,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Proje adı zorunludur' : null,
              ),
              const Gap(12),
              CustomTextField(
                label: 'Konum / Şantiye (Opsiyonel)',
                controller: locationController,
              ),
              const Gap(12),
              
              // Archive Toggle
              StatefulBuilder(builder: (context, setState) {
                 final isArchived = project.status == ProjectStatus.archived;
                 return SwitchListTile(
                    title: const Text('Projeyi Arşivle'),
                    subtitle: const Text('Bu proje tamamlandıysa işaretleyin.'),
                    value: isArchived,
                    onChanged: (val) {
                       setState(() {
                         project.status = val ? ProjectStatus.archived : ProjectStatus.active;
                       });
                    },
                 );
              }),

              const Gap(24),
              CustomButton(
                text: 'Güncelle',
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    project.name = nameController.text.trim();
                    project.location = locationController.text.trim();
                    
                    await ref.read(projectsProvider.notifier).updateProject(project);
                    
                    if (context.mounted) {
                       Navigator.pop(context);
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proje güncellendi')));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreateProject(BuildContext context, WidgetRef ref) async {
    final canCreate = await ref.read(subscriptionServiceProvider).canCreateProject();
    
    if (!canCreate) {
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
      }
      return;
    }

    if (context.mounted) _showAddProjectDialog(context, ref);
  }

  void _showAddProjectDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Yeni Proje Ekle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Gap(16),
              CustomTextField(
                label: 'Proje Adı',
                controller: nameController,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Proje adı zorunludur' : null,
              ),
              const Gap(12),
              CustomTextField(
                label: 'Konum / Şantiye (Opsiyonel)',
                controller: locationController,
              ),
              const Gap(24),
              CustomButton(
                text: 'Oluştur',
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await ref.read(projectsProvider.notifier).addProject(
                            nameController.text,
                            locationController.text,
                          );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projeyi Sil'),
        content: Text('${project.name} projesini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              ref.read(projectsProvider.notifier).deleteProject(project.id);
              Navigator.pop(context);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
