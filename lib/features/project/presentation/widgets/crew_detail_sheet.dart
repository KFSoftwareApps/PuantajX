import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../providers/project_providers.dart';
import '../../data/models/worker_model.dart'; // Direct import due to provider returning Worker

class CrewDetailSheet extends ConsumerWidget {
  final int projectId;
  final Worker crew;

  const CrewDetailSheet({super.key, required this.projectId, required this.crew});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch ALL project workers and filter locally for simplicity
    // Optimally we would have a provider filtering by crewId
    final workersAsync = ref.watch(projectWorkersProvider(projectId));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group, color: Colors.orange, size: 32),
                  ),
                  const Gap(16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crew.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (crew.description != null)
                          Text(crew.description!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(),
            
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ekip Üyeleri',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddMemberSheet(context),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Üye Ekle'),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: workersAsync.when(
                data: (allWorkers) {
                  // Filter for members of this crew
                  // Note: projectWorkersProvider returns actual Worker objects. 
                  // But Worker objects don't have 'crewId' on them directly if we didn't add it to WorkerModel.
                  // Wait, I added crewId to ProjectWorkerModel (the link).
                  // But projectWorkersProvider returns List<Worker>.
                  // Worker object does NOT have crewId. logic in project_providers.dart lines 85-89 fetches Workers.
                  // PROBLEM: The UI needs to know the crewId to filter!
                  // I need to update projectWorkersProvider to return a wrapper or map, 
                  // OR I update WorkerModel to include transient crewId?
                  // OR I change projectWorkersProvider to return List<ProjectWorkerWithDetails>.
                  
                  // Quick workaround: Since I cannot easily change the return type of projectWorkersProvider without breaking other screens,
                  // I should fetch the LINKS as well or create a new provider `projectCrewMembersProvider(projectId, crewId)`.
                  
                  return Consumer(
                    builder: (context, ref, child) {
                      final membersAsync = ref.watch(projectCrewMembersProvider(projectId: projectId, crewId: crew.id));
                      
                      return membersAsync.when(
                        data: (members) {
                           if (members.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.group_outlined, size: 48, color: Colors.grey.shade300),
                                  const Gap(16),
                                  const Text('Bu ekipte henüz kimse yok.'),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final worker = members[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(worker.name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                ),
                                title: Text(worker.name),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => _removeMember(context, ref, worker.id),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e,s) => Center(child: Text('Hata: $e')),
                      );
                    }
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddMemberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AddCrewMemberSheet(projectId: projectId, crewId: crew.id),
    );
  }

  Future<void> _removeMember(BuildContext context, WidgetRef ref, int workerId) async {
    // Set crewId to null
    await ref.read(projectWorkersProvider(projectId).notifier).assignCrew(workerId, null);
    // Provider invalidation will auto-update UI
  }
}

class _AddCrewMemberSheet extends ConsumerWidget {
  final int projectId;
  final int crewId;

  const _AddCrewMemberSheet({required this.projectId, required this.crewId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need workers who are NOT in a crew (or generally available).
    // I need a provider for "Workers without crew".
    // I can reuse projectWorkersProvider and filtered logic requires access to LINKS.
    
    // I'll create a new provider `projectWorkersWithoutCrewProvider(projectId)` for this.
    final availableAsync = ref.watch(projectWorkersWithoutCrewProvider(projectId));

    return DraggableScrollableSheet(
       initialChildSize: 0.7,
       minChildSize: 0.4,
       maxChildSize: 0.9,
       expand: false,
       builder: (context, scrollController) {
         return Column(
           children: [
             Padding(
               padding: const EdgeInsets.all(16),
               child: Text('Ekibe Üye Ekle', style: Theme.of(context).textTheme.titleLarge),
             ),
             const Divider(),
             Expanded(
               child: availableAsync.when(
                 data: (workers) {
                   // Filter out 'crew' type workers, we don't nest crews
                   final candidates = workers.where((w) => w.type != 'crew').toList();
                   
                   if (candidates.isEmpty) {
                      return const Center(child: Text('Eklenebilecek boşta çalışan yok.'));
                   }

                   return ListView.builder(
                     controller: scrollController,
                     itemCount: candidates.length,
                     itemBuilder: (context, index) {
                       final worker = candidates[index];
                       return ListTile(
                         leading: const Icon(Icons.person_add_alt),
                         title: Text(worker.name),
                         onTap: () async {
                           await ref.read(projectWorkersProvider(projectId).notifier).assignCrew(worker.id, crewId);
                           if (context.mounted) Navigator.pop(context);
                         },
                       );
                     },
                   );
                 },
                 loading: () => const Center(child: CircularProgressIndicator()),
                 error: (e, s) => Center(child: Text('Hata: $e')),
               ),
             ),
           ],
         );
       },
    );
  }
}

// Placeholder for new providers I need to add to project_providers.dart
// I will not define them here to avoid compilation errors, I will add them to the providers file next.
// But I need to import them here.
// I will temporarily treat them as existing or add them IMMEDIATELY after this file creation.
// Since I can't modify two files at once, I will assume they exist or I'll add them to project_providers.dart now.
