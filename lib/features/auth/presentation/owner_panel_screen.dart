import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'audit_log_screen.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/organization_model.dart'; 
import '../../../core/subscription/subscription_providers.dart';
import '../../../core/subscription/plan_config.dart';
import '../../../core/widgets/locked_feature_placeholder.dart';


class OwnerPanelScreen extends ConsumerStatefulWidget {
  const OwnerPanelScreen({super.key});

  @override
  ConsumerState<OwnerPanelScreen> createState() => _OwnerPanelScreenState();
}

class _OwnerPanelScreenState extends ConsumerState<OwnerPanelScreen> {
  final _billingEmailCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSendingVerification = false;


  // Policies
  bool _financeCanViewPhotos = true;
  bool _supervisorCanManageWorkers = false;
  
  // Phase 3: Additional Policies
  bool _exportsRequireApproval = false;
  bool _lockedPeriodUnlockOnlyOwner = true;
  bool _guestSharingEnabled = true;

  // Billing (Phase 2)
  String? _currentBillingEmail;
  bool _isBillingVerified = false;
  bool _notifyBilling = true;
  bool _notifyLimits = true;
  bool _notifyMonthlySummary = true;
  
  // State Tracking
  bool _hasChanges = false;
  Map<String, dynamic> _initialValues = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _billingEmailCtrl.addListener(_onFieldChanged);
  }
  
  @override
  void dispose() {
    _billingEmailCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _checkForChanges();
  }

  Future<void> _loadData() async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;

    final repo = ref.read(authRepositoryProvider);
    
    // 1. Sync RevenueCat status to Supabase/Isar
    await ref.read(subscriptionServiceProvider).checkAndSyncSubscription();
    
    // 2. Refresh from Supabase (now updated)
    await repo.refreshOrganizationFromSupabase(user.currentOrgId);

    final policy = await repo.getOrgPolicy(user.currentOrgId);
    final org = await repo.getOrganization(user.currentOrgId);
    
    if (mounted) {
      setState(() {
        _financeCanViewPhotos = policy.financeCanViewPhotos;
        _supervisorCanManageWorkers = policy.supervisorCanManageProjectWorkers;
        _exportsRequireApproval = policy.exportsRequireApproval;
        _lockedPeriodUnlockOnlyOwner = policy.lockedPeriodUnlockOnlyOwner;
        _guestSharingEnabled = policy.guestSharingEnabled;
        
        if (org != null) {
          _billingEmailCtrl.text = org.billingEmail ?? '';
          _currentBillingEmail = org.billingEmail;
          _isBillingVerified = org.billingEmailVerified;
          _notifyBilling = org.notifyBillingUpdates;
          _notifyLimits = org.notifyLimitWarnings;
          _notifyMonthlySummary = org.notifyMonthlySummary;
        }
        
        // Capture Initial State
        _initialValues = {
          'finance': _financeCanViewPhotos,
          'supervisor': _supervisorCanManageWorkers,
          'exports': _exportsRequireApproval,
          'locked': _lockedPeriodUnlockOnlyOwner,
          'guest': _guestSharingEnabled,
          'email': _billingEmailCtrl.text,
          'n_billing': _notifyBilling,
          'n_limits': _notifyLimits,
          'n_summary': _notifyMonthlySummary,
        };
        _hasChanges = false;
      });
    }
  }

  void _checkForChanges() {
    final newHasChanges = 
      _financeCanViewPhotos != _initialValues['finance'] ||
      _supervisorCanManageWorkers != _initialValues['supervisor'] ||
      _exportsRequireApproval != _initialValues['exports'] ||
      _lockedPeriodUnlockOnlyOwner != _initialValues['locked'] ||
      _guestSharingEnabled != _initialValues['guest'] ||
      _billingEmailCtrl.text != _initialValues['email'] ||
      _notifyBilling != _initialValues['n_billing'] ||
      _notifyLimits != _initialValues['n_limits'] ||
      _notifyMonthlySummary != _initialValues['n_summary'];

    if (newHasChanges != _hasChanges) {
      setState(() => _hasChanges = newHasChanges);
    }
  }

  // Helper to update state and check changes
  void _updateState(VoidCallback fn) {
    setState(() {
      fn();
      _checkForChanges();
    });
  }

  Future<void> _saveAll() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authControllerProvider).valueOrNull;
      if (user == null) return;

      final repo = ref.read(authRepositoryProvider);
      
      // Save Policy
      final policy = await repo.getOrgPolicy(user.currentOrgId);
      policy.financeCanViewPhotos = _financeCanViewPhotos;
      policy.supervisorCanManageProjectWorkers = _supervisorCanManageWorkers;
      policy.exportsRequireApproval = _exportsRequireApproval;
      policy.lockedPeriodUnlockOnlyOwner = _lockedPeriodUnlockOnlyOwner;
      policy.guestSharingEnabled = _guestSharingEnabled;
      
      await repo.updateOrgPolicy(policy);

      // Save Billing
      await repo.updateOrgBilling(
        orgId: user.currentOrgId,
        email: _billingEmailCtrl.text.isEmpty ? null : _billingEmailCtrl.text,
        notifyBilling: _notifyBilling,
        notifyLimits: _notifyLimits,
        notifySummary: _notifyMonthlySummary,
      );

      // Refresh Data & Reset Initial State
      await _loadData(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Row(children: const [
               Icon(Icons.check_circle, color: Colors.white, size: 20),
               Gap(8),
               Text('Değişiklikler kaydedildi')
             ]),
             behavior: SnackBarBehavior.floating,
             backgroundColor: Colors.green[700],
           )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendVerification() async {
    setState(() => _isSendingVerification = true);
    try {
      final user = ref.read(authControllerProvider).valueOrNull;
      if (user == null) return;
      await ref.read(authRepositoryProvider).sendBillingVerificationEmail(user.currentOrgId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doğrulama e-postası gönderildi')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isSendingVerification = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailChanged = _billingEmailCtrl.text != (_currentBillingEmail ?? '');
    final showVerifyAction = !emailChanged && _currentBillingEmail != null && !_isBillingVerified;
    
    // Check Entitlements
    // Using FutureProvider .valueOrNull or .value
    final approvalAccessAsync = ref.watch(hasEntitlementProvider(Entitlement.approvalFlow));
    final guestAccessAsync = ref.watch(hasEntitlementProvider(Entitlement.guestSharing));
    final auditAccessAsync = ref.watch(hasEntitlementProvider(Entitlement.auditLog));
    
    final hasApprovalAccess = approvalAccessAsync.value ?? false;
    final hasGuestAccess = guestAccessAsync.value ?? false;
    final hasAuditAccess = auditAccessAsync.value ?? false;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Kaydedilmemiş Değişiklikler'),
            content: const Text('Yaptığınız değişiklikler kaybolacak. Çıkmak istiyor musunuz?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
              TextButton(
                onPressed: () => Navigator.pop(context, true), 
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Çık'),
              ),
            ],
          ),
        );
        
        if (shouldExit == true) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: const CustomAppBar(title: 'Organizasyon Politikaları', showProjectChip: false, showSyncStatus: false),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor.withAlpha(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Organizasyon Politikaları', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                    const Gap(4),
                    Text('Bu ayarlar organizasyondaki tüm projeleri ve kullanıcıları etkiler.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
                  ],
                ),
              ),
              const Divider(height: 1),
  
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     // --- Billing Section ---
                     _buildSectionHeader('Fatura E-posta'),
                     const Text('Plan/limit bildirimleri ve finans özetleri bu adrese gönderilir.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                     const Gap(8),
                     Row(
                      children: [
                         Expanded(child: CustomTextField(
                           label: 'Fatura E-posta', 
                           controller: _billingEmailCtrl, 
                           prefixIcon: Icons.email_outlined, 
                           hint: 'ornek@firma.com',
                           enabled: !_isBillingVerified,
                         )),
                         if (showVerifyAction) ...[
                           const Gap(8),
                           Padding(padding: const EdgeInsets.only(top: 24), child: _isSendingVerification ? const CircularProgressIndicator() : TextButton(onPressed: _sendVerification, child: const Text('Doğrula')))
                         ]
                      ],
                     ),
                     // Verification Status Chips
                     if (_currentBillingEmail != null && !_isBillingVerified)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(Icons.info_outline, size: 14, color: Colors.orange), const Gap(4), Text('Doğrulanmadı', style: TextStyle(color: Colors.orange[800], fontSize: 12))])),
                     if (_currentBillingEmail != null && _isBillingVerified)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(Icons.check_circle, size: 14, color: Colors.green), const Gap(4), Text('Doğrulandı', style: TextStyle(color: Colors.green[700], fontSize: 12))])),
                     
                     const Gap(16),
                     const Text('E-posta Bildirimleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                     const Gap(4),
                     const Text('Bu bildirimler seçtiğiniz fatura e-postasına gönderilir.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                     
                     _buildCheckbox('Plan ve ödeme bildirimleri', _notifyBilling, (v) => _notifyBilling = v),
                     _buildCheckbox('Limit uyarıları', _notifyLimits, (v) => _notifyLimits = v),
                      // Note: Monthly summary might be entitlement gated too? Keeping it simple for now or using entitlement
                     _buildCheckbox('Aylık özet rapor', _notifyMonthlySummary, (v) => _notifyMonthlySummary = v),
  
                     const Gap(24),
  
                     // --- Policy Section ---
                     _buildSectionHeader('Gelişmiş İzin Politikaları'),
  
                     // A) Privacy & Content
                     _buildCategoryHeader('Gizlilik & İçerik', null),
                     _buildSwitch('Finans Fotoğrafları Görebilir', 'Finans rolü raporlardaki ekleri görüntüler.', _financeCanViewPhotos, (v) => _financeCanViewPhotos = v),
  
                     // B) Field Permissions
                     _buildCategoryHeader('Saha Yetkileri', null),
                     _buildSwitch('Supervisor İşçi Yönetebilir', 'Saha sorumluları projeye işçi ekleyip çıkarabilir.', _supervisorCanManageWorkers, (v) => _supervisorCanManageWorkers = v),
  
                     // C) Approval & Lock (Business)
                     _buildCategoryHeader('Onay & Kilit', 'Business'),
                     hasApprovalAccess 
                      ? Column(children: [
                          _buildSwitch('Dışa Aktarım İçin Onay Zorunlu', 'Excel/PDF dışa aktarımları için rapor onaylı olmalıdır.', _exportsRequireApproval, (v) => _exportsRequireApproval = v),
                          _buildSwitch('Dönem Kilidi Açma Sadece Owner', 'Kilitlenen dönemi sadece Owner açabilir.', _lockedPeriodUnlockOnlyOwner, (v) => _lockedPeriodUnlockOnlyOwner = v),
                        ])
                      : const LockedFeaturePlaceholder(
                          featureKey: 'approval_flow',
                          title: 'Gelişmiş Onay ve Kilit',
                          description: 'Onay zorunluluğu ve dönem kilidi kuralları Business planda yönetilir.',
                        ),
  
                     // D) Sharing (Business)
                     _buildCategoryHeader('Paylaşım', 'Business'),
                     hasGuestAccess
                      ? _buildSwitch('Misafir Paylaşımı Açık', 'Müşteri/denetçi için misafir linki paylaşımı.', _guestSharingEnabled, (v) => _guestSharingEnabled = v)
                      : const LockedFeaturePlaceholder(
                          featureKey: 'guest_sharing',
                          title: 'Misafir Paylaşımı',
                          description: 'Projelerinizi dış paydaşlarla güvenle paylaşın.',
                        ),
  
                     const Gap(32),
                     SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || !_hasChanges) ? null : _saveAll,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _hasChanges ? Theme.of(context).primaryColor : Colors.grey[300],
                          foregroundColor: _hasChanges ? Colors.white : Colors.grey[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                          : const Text('Değişiklikleri Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                     ),
  
                      const Gap(16),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.history, color: Colors.grey),
                        title: const Text('Denetim Kayıtları (Audit Log)'),
                        subtitle: const Text('Kim neyi ne zaman değiştirdi'),
                        trailing: hasAuditAccess ? const Icon(Icons.chevron_right) : const Icon(Icons.lock, color: Colors.grey, size: 20),
                        onTap: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogScreen()));
                        },
                      ),
                      const Gap(40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper Widgets
  Widget _buildSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      value: value,
      onChanged: (v) => _updateState(() => onChanged(v)),
      activeColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildCheckbox(String title, bool value, Function(bool) onChanged, {bool enabled = true, bool isLocked = false}) {
    return CheckboxListTile(
      title: Row(children: [
        Text(title, style: const TextStyle(fontSize: 13)),
        if (isLocked) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.lock, size: 14, color: Colors.grey))
      ]),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: enabled ? (v) => _updateState(() => onChanged(v ?? true)) : null,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800], letterSpacing: 0.5)),
    );
  }

  Widget _buildCategoryHeader(String title, String? planTag) {
     return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700])),
          if (planTag != null) ...[
            const Gap(8),
             Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(4)), child: Text(planTag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo)))
          ]
        ],
      )
    );
  }
}
