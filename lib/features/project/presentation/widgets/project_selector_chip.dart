import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../../project/data/models/project_model.dart';

class ProjectSelectorChip extends StatelessWidget {
  final dynamic selectedProject;
  final List<dynamic> projects;
  final Function(int) onSelected;

  const ProjectSelectorChip({
    super.key,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.03),
               blurRadius: 4,
               offset: const Offset(0, 2),
             ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment, size: 14, color: Theme.of(context).primaryColor),
            const Gap(6),
            Flexible(
              child: Text(
                // Handle selectedProject being dynamic/Project/null
                (selectedProject is Project ? selectedProject.name : selectedProject?.name) ?? 'Proje Seç',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Gap(4),
            Icon(Icons.arrow_drop_down, size: 16, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }

  void _showProjectSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Text(
                 'Şantiye Seç',
                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               ),
               const Gap(16),
               if (projects.isEmpty)
                   const Center(child: Text('Hiç proje yok.'))
               else 
                 ListView.separated(
                  shrinkWrap: true,
                  itemCount: projects.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = projects[index];
                    final isSelected = (selectedProject is Project ? selectedProject.id : selectedProject?.id) == p.id;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.business, color: isSelected ? Colors.blue : Colors.grey),
                      ),
                      title: Text(
                        p.name, 
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.blue.shade900 : Colors.black87,
                        ),
                      ),
                      subtitle: p.location != null && p.location!.isNotEmpty ? Text(p.location!) : null,
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                      onTap: () {
                        onSelected(p.id);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
                const Gap(24),
            ],
          ),
        );
      },
    );
  }
}
