import '../../../core/utils/dart_io_web_stub.dart' if (dart.library.io) 'dart:io';
import '../../../core/widgets/platform_image.dart'; // Added
import 'package:flutter/foundation.dart'; // Added for kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../../../core/utils/input_formatters.dart';
import '../data/repositories/auth_repository.dart';


class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Şifre Değiştir'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'Mevcut Şifre',
                controller: _currentController,
                obscureText: true,
                validator: (v) => v == null || v.isEmpty ? 'Gerekli' : null,
              ),
              const Gap(16),
              CustomTextField(
                label: 'Yeni Şifre',
                controller: _newController,
                obscureText: true,
                validator: (v) => v == null || v.length < 6 ? 'En az 6 karakter' : null,
              ),
              const Gap(16),
              CustomTextField(
                label: 'Yeni Şifre (Tekrar)',
                controller: _confirmController,
                obscureText: true,
                validator: (v) {
                  if (v != _newController.text) return 'Şifreler eşleşmiyor';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading 
             ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
             : const Text('Değiştir'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
        _currentController.text,
        _newController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre başarıyla değiştirildi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  bool _isEditing = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  
  String? _initialName;
  String? _initialPhone;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController()..addListener(_checkForChanges);
    _phoneController = TextEditingController()..addListener(_checkForChanges);
    _emailController = TextEditingController();
    
    _loadUserData();
  }

  void _loadUserData() {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user != null) {
      _initialName = user.fullName;
      _initialPhone = user.phoneNumber;
      
      _nameController.text = user.fullName;
      
      // Apply format to loaded number
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          final digits = user.phoneNumber!.replaceAll(RegExp(r'\D'), '');
          // This rough formatter logic - safer to reuse formatter logic if possible, 
          // or just implement simple one-off here since we know the format
          if (digits.length == 10) {
              // 5XX XXX XX XX
              _phoneController.text = '${digits.substring(0,3)} ${digits.substring(3,6)} ${digits.substring(6,8)} ${digits.substring(8,10)}';
          } else {
              _phoneController.text = digits;
          }
      } else {
           _phoneController.text = '';
      }
      
      _emailController.text = user.email;
      _checkForChanges();
    }
  }

  void _checkForChanges() {
    if (!_isEditing) return;
    final nameChanged = _nameController.text.trim() != _initialName;
    final currentRawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    // Handle empty case
    final initialRaw = _initialPhone ?? '';
    final phoneChanged = (currentRawPhone.isEmpty ? null : currentRawPhone) != (initialRaw.isEmpty ? null : initialRaw);
    
    if (_hasChanges != (nameChanged || phoneChanged)) {
      setState(() {
        _hasChanges = nameChanged || phoneChanged;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    // Strip everything except digits for saving
    final rawPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    if (name.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad Soyad boş olamaz.')));
      return;
    }

    setState(() => _isLoading = true);
    
    // Check if phone is valid (10 digits for Turkey mobile usually)
    // If user deleted everything, rawPhone is empty.
    if (rawPhone.isNotEmpty && rawPhone.length != 10) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen geçerli 10 haneli bir telefon numarası giriniz (5XX...).')));
      }
      return;
    }

    try {
      await ref.read(authControllerProvider.notifier).updateProfile(
        fullName: name,
        phoneNumber: rawPhone.isNotEmpty ? rawPhone : null,
      );
      
      setState(() {
        _isEditing = false;
        _initialName = name;
        _initialPhone = rawPhone.isNotEmpty ? rawPhone : null;
        _hasChanges = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil güncellendi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleWillPop(bool didPop) async {
    if (didPop) return;
    if (_isEditing) {
       final shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Kaydedilmemiş Değişiklikler'),
          content: const Text('Yaptığınız değişiklikler kaybolacak. Çıkmak istiyor musunuz?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Çık', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (shouldPop == true && mounted) {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Profil'),
        body: const Center(child: Text('Kullanıcı oturumu bulunamadı.')),
      );
    }

    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, _) => _handleWillPop(didPop),
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Hesap Bilgileri',
          showProjectChip: false,
          showSyncStatus: false,
          actions: [
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => setState(() => _isEditing = true),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
               Center(
                 child: Stack(
                   children: [
                       CircleAvatar(
                         radius: 50,
                         backgroundColor: Theme.of(context).primaryColor.withAlpha(26),
                         child: user.avatarPath != null 
                             ? ClipOval(child: SizedBox(width: 100, height: 100, child: PlatformImageImpl.create(path: user.avatarPath!, fit: BoxFit.cover)))
                             : (user.avatarUrl != null 
                                 ? ClipOval(child: Image.network(user.avatarUrl!, width: 100, height: 100, fit: BoxFit.cover))
                                 : Text(
                                     user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                                     style: TextStyle(fontSize: 40, color: Theme.of(context).primaryColor),
                                   )),
                       ),
                       if (_isEditing)
                         Positioned(
                           bottom: 0,
                           right: 0,
                           child: CircleAvatar(
                             radius: 18,
                             backgroundColor: Colors.white,
                             child: IconButton(
                               icon: const Icon(Icons.camera_alt, size: 18, color: Colors.grey),
                               onPressed: () async {
                                 final picker = ImagePicker();
                                 final picked = await picker.pickImage(source: ImageSource.gallery);
                                 if (picked != null) {
                                    await ref.read(authControllerProvider.notifier).updateAvatar(picked.path);
                                    if (context.mounted) {
                                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil fotoğrafı güncellendi.')));
                                    }
                                 }
                               },
                             ),
                           ),
                         )
                   ],
                 ),
               ),
               const Gap(32),

               // Form Fields
               CustomTextField(
                 label: 'Ad Soyad',
                 readOnly: !_isEditing,
                 controller: _nameController,
                 hint: 'Adınız Soyadınız',
                 prefixIcon: Icons.person_outline,
               ),
               const Gap(16),
               CustomTextField(
                 label: 'E-Posta',
                 readOnly: true,
                 controller: _emailController,
                 prefixIcon: Icons.email_outlined,
                 suffixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
               ),
               if (_isEditing)
                 Padding(
                   padding: const EdgeInsets.only(top: 4, left: 4),
                   child: Row(
                     children: [
                       Icon(Icons.info_outline, size: 12, color: Colors.grey[600]),
                       const Gap(4),
                       Text('E-posta değiştirilemez', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                     ],
                   ),
                 ),
               const Gap(16),
               CustomTextField(
                 label: 'Telefon',
                 hint: '5XX XXX XX XX',
                 readOnly: !_isEditing,
                 keyboardType: TextInputType.phone,
                 controller: _phoneController,
                 prefixIcon: Icons.phone_outlined,
                 prefixText: '+90 ',
                 inputFormatters: [
                   TRPhoneFormatter(),
                 ],
               ),
               
               const Gap(40),
               
               if (!_isEditing) ...[
                   if (user.authProvider == 'email' || user.authProvider == null)
                    CustomButton(
                      text: 'Şifre Değiştir',
                      type: CustomButtonType.outline,
                      onPressed: () => showDialog(
                        context: context,
                        builder: (c) => const _ChangePasswordDialog(),
                      ),
                    )
                 else
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: Colors.grey.shade100,
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.grey.shade300),
                     ),
                     child: Row(
                       children: [
                         Icon(
                           user.authProvider == 'google' ? Icons.g_mobiledata : Icons.apple,
                           size: 24,
                           color: Colors.grey[700],
                         ),
                         const Gap(8),
                         Expanded(
                           child: Text(
                             'Bu hesap ${user.authProvider!.toUpperCase()} ile yönetiliyor.',
                             style: TextStyle(color: Colors.grey[700], fontSize: 13),
                           ),
                         ),
                       ],
                     ),
                   ),
                   
                   const Gap(24),
                   
                   InkWell(
                      onTap: () => context.go('/settings?openDelete=true'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(10), 
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Icon(Icons.delete_forever, color: Colors.red.shade400, size: 20),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hesabı Sil', 
                                    style: TextStyle(
                                      color: Colors.red.shade700, 
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'Hesabın ve verilerin silinir', 
                                    style: TextStyle(
                                      color: Colors.red.shade300, 
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.red.shade200, size: 20),
                          ],
                        ),
                      ),
                    ),
               ],
            ],
          ),
        ),
        bottomNavigationBar: _isEditing ? 
           SafeArea(
             child: Container(
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: Colors.white,
                 boxShadow: [
                   BoxShadow(
                     color: Colors.black.withAlpha(13),
                     blurRadius: 10,
                     offset: const Offset(0, -5),
                   ),
                 ],
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Expanded(
                     child: CustomButton(
                       text: 'Vazgeç',
                       type: CustomButtonType.outline,
                       onPressed: () {
                         _loadUserData(); 
                         setState(() {
                             _isEditing = false;
                             _hasChanges = false;
                         });
                       },
                     ),
                   ),
                   const Gap(16),
                   Expanded(
                     child: CustomButton(
                       text: 'Kaydet',
                       isLoading: _isLoading,
                       onPressed: _hasChanges ? _saveProfile : null,
                     ),
                   ),
                 ],
               ),
             ),
           ) : null,
      ),
    );
  }
}
