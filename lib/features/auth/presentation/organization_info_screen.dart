
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/share_stub.dart' if (dart.library.io) 'package:share_plus/share_plus.dart'; // Assuming share_plus is available, if not I will use Clipboard or skip
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/authz/roles.dart'; // Needed for AppRole
import '../data/repositories/auth_repository.dart';
import '../data/models/organization_model.dart';
import '../data/models/user_model.dart'; // For AppRole
import '../../../core/subscription/subscription_providers.dart'; // For Plan Name source
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationInfoScreen extends ConsumerStatefulWidget {
  const OrganizationInfoScreen({super.key});

  @override
  ConsumerState<OrganizationInfoScreen> createState() => _OrganizationInfoScreenState();
}

class _OrganizationInfoScreenState extends ConsumerState<OrganizationInfoScreen> {
  Organization? _org;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;

    final repo = ref.read(authRepositoryProvider);
    var org = await repo.getOrganization(user.currentOrgId);
    
    // Self-Healing: If local org is missing, try to fetch from server
    if (org == null) {
       await repo.refreshOrganizationFromSupabase(user.currentOrgId);
       org = await repo.getOrganization(user.currentOrgId);
    }
    
    if (mounted) {
      setState(() {
        _org = org;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOwner = user.role == AppRole.owner;
    final isAdmin = user.role == AppRole.admin;
    final isFinance = user.role == AppRole.finance;
    
    // RBAC: Who sees full ID and Metadata?
    final canSeeSensitive = isOwner || isAdmin || isFinance; 

    // Plan Name source check
    final planAsync = ref.watch(currentPlanProvider);
    final planName = planAsync.valueOrNull?.displayName ?? (_org?.plan ?? 'Free').toUpperCase();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Organizasyon Bilgileri', showProjectChip: false, showSyncStatus: false),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PHASE 1 & 4: Organization ID (Authorized Only)
              if (canSeeSensitive) ...[
                _buildSectionHeader('Organizasyon Kimliği'),
                _buildInfoCard(
                  context,
                  child: CustomTextField(
                    label: 'Organizasyon ID',
                    // Use _org.code as source of truth, fallback to user.currentOrgId only if null
                    controller: TextEditingController(text: _org?.code ?? user.currentOrgId),
                    readOnly: true,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _org?.code ?? user.currentOrgId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Organizasyon ID kopyalandı.'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconButton(
                           icon: const Icon(Icons.share, size: 20, color: Colors.grey),
                           onPressed: () {
                               Share.share('Organizasyon ID: ${_org?.code ?? user.currentOrgId}\nOrganizasyon Adı: ${_org?.name}');
                           },
                        )
                      ],
                    ),
                  ),
                  footer: 'Bu kodu teknik destek ekibiyle paylaşmanız gerekebilir.',
                ),
                const Gap(24),
              ],

              // PHASE 2: Basic Info (Read Only)
              _buildSectionHeader('Temel Bilgiler'),
              Card(
                elevation: 0,
                // color: Use Theme default
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        'Organizasyon Adı', 
                        _org?.name ?? (user.role != null ? (Supabase.instance.client.auth.currentUser?.userMetadata?['org_name'] ?? 'Bilinmeyen Org') : 'Yükleniyor...'),
                        onEdit: null, // Editing is disabled as per new flow
                      ),
                      const Divider(),
                      _buildDetailRow('Mevcut Plan', planName, isHighlight: true),
                      if (canSeeSensitive) ...[
                        const Divider(),
                        _buildDetailRow('Para Birimi', '₺ (TRY)'), // Hardcoded for now based on brief
                        const Divider(),
                        _buildDetailRow('Saat Dilimi', 'Europe/Istanbul'),
                        if (_org?.createdAt != null) ...[
                           const Divider(),
                           _buildDetailRow('Kurulum Tarihi', DateFormat('dd MMM yyyy').format(_org!.createdAt!)),
                        ]
                      ]
                    ],
                  ),
                ),
              ),
              const Gap(24),
              
              // PHASE 3: Billing Info (Finance/Owner/Admin Only)
              if (canSeeSensitive) ...[
                 _buildSectionHeader('Fatura & İletişim'),
                 Card(
                  elevation: 0,
                  // color: Use Theme default
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, color: Colors.grey),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_org?.billingEmail ?? 'E-posta girilmemiş', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text(
                                    (_org?.billingEmailVerified ?? false) ? 'Doğrulandı' : 'Doğrulanmadı',
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: (_org?.billingEmailVerified ?? false) ? Colors.green : Colors.orange,
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ],
                              ),
                            ),
                            if (isOwner)
                              TextButton(
                                onPressed: () => context.go('/settings/owner-panel'),
                                child: const Text('Yönet'),
                              )
                          ],
                        ),
                      ],
                    ),
                  ),
                 ),
                 const Gap(24),
              ],

              // PHASE 5: Implementation/Support (Footer)
              Center(
                 child: TextButton.icon(
                   icon: const Icon(Icons.support_agent, size: 18),
                   label: const Text('Destek ile İletişim'),
                   style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                   onPressed: () {
                      // Navigate to support or open chat (Placeholder)
                      context.go('/settings/about'); 
                   },
                 ),
              )
            ],
          ),
        ),
    );
  }

  Future<void> _showEditNameDialog() async {
    final ctrl = TextEditingController(text: _org?.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Organizasyon Adını Düzenle'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Yeni Ad', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              
              Navigator.pop(context);
              
              setState(() => _isLoading = true);
              try {
                final user = ref.read(authControllerProvider).valueOrNull!;
                final newCode = newName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                await ref.read(authRepositoryProvider).updateOrgName(user.currentOrgId, newName, newCode);
                await _loadData(); // Refresh info
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Organizasyon adı güncellendi ✅')));
                }
              } catch (e) {
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Kaydet'),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5)),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required Widget child, String? footer}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        child,
        if (footer != null) ...[
           const Gap(8),
           Padding(
             padding: const EdgeInsets.only(left: 4),
             child: Text(footer, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
           )
        ]
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Row(
            children: [
              Text(
                value, 
                style: TextStyle(
                  color: isHighlight ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
                )
              ),
              if (onEdit != null) ...[
                const Gap(8),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                     padding: const EdgeInsets.all(4.0),
                     child: Icon(Icons.edit, size: 16, color: Theme.of(context).primaryColor),
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
