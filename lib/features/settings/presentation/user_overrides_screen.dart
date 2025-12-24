import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/repositories/auth_repository.dart';
import '../../../core/widgets/custom_app_bar.dart';

class UserOverridesScreen extends ConsumerWidget {
  const UserOverridesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(organizationMembersProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Kullanıcı İstisnaları'),
      body: membersAsync.when(
        data: (members) {
           if (members.isEmpty) {
             return const Center(child: Text('Üye bulunamadı'));
           }

           return ListView.builder(
             padding: const EdgeInsets.all(16),
             itemCount: members.length,
             itemBuilder: (context, index) {
               final user = members[index];
               return Card(
                 child: ListTile(
                   leading: CircleAvatar(
                     backgroundColor: Colors.indigo.shade100,
                     child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                     ),
                   ),
                   title: Text(user.fullName.isNotEmpty ? user.fullName : user.email),
                   subtitle: Text(user.email),
                   trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                   onTap: () {
                     context.push('/settings/owner-panel/user-overrides/${user.id}');
                   },
                 ),
               );
             },
           );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}
