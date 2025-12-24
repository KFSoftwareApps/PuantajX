import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../../../core/init/providers.dart'; // Correct relative path
import '../data/models/organization_model.dart';
import '../data/models/user_model.dart'; // Added: Critical for isar.users getter
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../data/repositories/auth_repository.dart';

class SetupOrganizationScreen extends ConsumerStatefulWidget {
  const SetupOrganizationScreen({super.key});

  @override
  ConsumerState<SetupOrganizationScreen> createState() => _SetupOrganizationScreenState();
}

class _SetupOrganizationScreenState extends ConsumerState<SetupOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final code = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Kullanıcı bulunamadı');

      // 0. Try RPC to Update Organization (Rename/Rekey)
      bool rpcSuccess = false;
      try {
        await Supabase.instance.client.rpc('update_own_organization', params: {
          'new_name': name,
          'new_code': code,
        });
        rpcSuccess = true;
      } catch (rpcError) {
         debugPrint('RPC Update Failed (Using Fallback): $rpcError');
         // We will handle the DB update via upsert below if this failed.
      }

      // 1. Update User Metadata (Source of Truth for RLS)
      // We do this REGARDLESS of RPC result to ensure Client Session matches the (intended) DB state.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'org_name': name, 'org_code': code}),
      );

      // 2. Refresh Session (Critical for RLS)
      // This grants us the "ticket" to access/create rows with 'code'
      await Supabase.instance.client.auth.refreshSession();
      
      // 3. Fallback DB Upsert
      // If RPC failed (e.g. function missing or no default org found), we MUST ensure the org exists.
      // Now that we have the Refreshed Session (with new code), RLS will allow this Upsert.
      if (!rpcSuccess) {
         final now = DateTime.now();
         await Supabase.instance.client.from('organizations').upsert({
            'code': code,
            'name': name,
            'plan': 'Free',
            'updated_at': now.toIso8601String(), 
         }, onConflict: 'code');
      }
      
      // 4. Update Local Database (Isar)
      final now = DateTime.now();

      // 4. Update Local Database (Isar)
      try {
         final isar = await ref.read(isarProvider.future);
         
         if (isar != null) {
           await isar.writeTxn(() async {
             // A. Update Organization Table
             await isar.organizations.clear(); 
             
             final newOrg = Organization()
               ..serverId = (await Supabase.instance.client.from('organizations').select('id').eq('code', code).single())['id']
               ..code = code
               ..name = name
               ..plan = 'Free'
               ..createdAt = now
               ..lastUpdatedAt = now
               ..isSynced = true;
               
             await isar.organizations.put(newOrg);
  
             // B. Update User Table (Critical for UI consistency)
             final users = await isar.users.where().findAll();
             for (var u in users) {
               u.currentOrgId = code; 
               await isar.users.put(u);
             }
           });
         }

         
         // Force Provider Refresh to propagate changes to UI
         // Invalidating authController will make it re-fetch User from Isar (now updated)
         ref.invalidate(authControllerProvider); // Assuming this provider exists and reads from Isar
         
      } catch (e) {
         debugPrint('Local DB Update Failed: $e');
      }
      
      // 5. Navigate
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Organizasyon Kurulumu', showBackButton: false),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.business_rounded, size: 64, color: Colors.blueGrey),
              const Gap(24),
              Text(
                'Hoş Geldiniz!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const Gap(8),
              Text(
                'Devam etmek için lütfen organizasyonunuzun (şirket veya ekip) adını girin.\nBu isim daha sonra değiştirilemez.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const Gap(32),
              CustomTextField(
                controller: _nameController,
                label: 'Organizasyon Adı',
                hint: 'Örn: Demir İnşaat',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lütfen bir isim girin';
                  }
                  if (value.trim().length < 3) {
                    return 'En az 3 karakter olmalı';
                  }
                  return null;
                },
              ),
              const Gap(24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kurulumu Tamamla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
