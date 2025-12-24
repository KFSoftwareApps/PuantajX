import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../providers/project_providers.dart';
import '../../data/models/worker_model.dart';
import '../../../../core/widgets/custom_text_field.dart';

class AssignWorkerSheet extends ConsumerStatefulWidget {
  final int projectId;

  const AssignWorkerSheet({super.key, required this.projectId});

  @override
  ConsumerState<AssignWorkerSheet> createState() => _AssignWorkerSheetState();
}

class _AssignWorkerSheetState extends ConsumerState<AssignWorkerSheet> {
  final Set<int> _selectedIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final availableWorkersAsync = ref.watch(availableWorkersProvider(widget.projectId));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ekibe Çalışan Ekle', style: Theme.of(context).textTheme.titleLarge),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              const Divider(),
              
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CustomTextField(
                  label: 'İsimle Ara',
                  prefixIcon: Icons.search,
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
              const Gap(12),

              // List
              Expanded(
                child: availableWorkersAsync.when(
                  data: (workers) {
                    final filtered = workers.where((w) => w.name.toLowerCase().contains(_searchQuery)).toList();

                    if (filtered.isEmpty) {
                      if (_searchQuery.isNotEmpty) {
                         return const Center(child: Text('Aramanızla eşleşen çalışan bulunamadı.'));
                      }
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_off_outlined, size: 48, color: Colors.grey),
                            const Gap(16),
                            const Text(
                              'Eklenebilecek çalışan bulunamadı.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Gap(8),
                            Text(
                              'Ana ekip listesindeki tüm çalışanlar\nbu projeye zaten eklenmiş veya liste boş.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const Gap(16),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                context.go('/projects/workers');
                              },
                              icon: const Icon(Icons.people),
                              label: const Text('Genel Ekip Yönetimi listesine git'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final worker = filtered[index];
                        final isSelected = _selectedIds.contains(worker.id);
                        return ListTile(
                          leading: CircleAvatar(child: Text(worker.name[0])),
                          title: Text(worker.name),
                          subtitle: Text(worker.trade ?? 'Çalışan'),
                          trailing: isSelected 
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.circle_outlined, color: Colors.grey),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(worker.id);
                              } else {
                                _selectedIds.add(worker.id);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Hata: $e')),
                ),
              ),
              
              const Divider(),

              // Action
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _selectedIds.isEmpty ? null : _save,
                  child: Text('Seçilenleri Ekle (${_selectedIds.length})'),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    try {
      await ref.read(projectWorkersProvider(widget.projectId).notifier).assignWorkers(_selectedIds.toList());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }
}
