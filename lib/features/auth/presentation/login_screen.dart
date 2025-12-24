import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../data/repositories/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString().replaceAll('Exception: ', ''))),
        );
      }
      // Removed auto-navigation to allow custom logic per button
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 80, color: Colors.blue),
                  const Gap(24),
                  Text(
                    'Giriş Yap',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Gap(8),
                  Text(
                    'PuantajX\'e hoşgeldiniz.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                  const Gap(32),
                  CustomTextField(
                    label: 'E-Posta',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const Gap(16),
                  CustomTextField(
                    label: 'Şifre',
                    controller: _passwordController,
                    obscureText: true,
                  ),
                  const Gap(24),
                  CustomButton(
                    text: 'Giriş Yap',
                    isLoading: isLoading,
                    onPressed: () async {
                       await ref.read(authControllerProvider.notifier).login(
                             _emailController.text,
                             _passwordController.text,
                           );
                       
                       // Check success manually
                       final state = ref.read(authControllerProvider);
                       if (state.hasValue && state.value != null && mounted) {
                          context.go('/dashboard');
                       }
                    },
                  ),
                  const Gap(16),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : () async {
                       await ref.read(authControllerProvider.notifier).signInWithGoogle();
                       
                       // Check if login was successful
                       final state = ref.read(authControllerProvider);
                       if (state.hasValue && state.value != null && mounted) {
                          // Check for password
                          final repo = ref.read(authRepositoryProvider);
                          final hasPass = await repo.hasPassword();
                          
                          if (!hasPass && mounted) {
                             final shouldSet = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => AlertDialog(
                                  title: const Text('Şifre Belirle 🔐'),
                                  content: const Text(
                                    'Google ile giriş yaptınız.\nİsterseniz e-posta adresiniz ve belirleyeceğiniz şifre ile de giriş yapabilmek için şimdi şifre oluşturabilirsiniz.'
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false), // Atla
                                      child: const Text('Daha Sonra'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context, true), // Belirle
                                      child: const Text('Şifre Oluştur'),
                                    ),
                                  ],
                                ),
                             );

                             if (shouldSet == true && mounted) {
                                final passCtrl = TextEditingController();
                                await showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Yeni Şifre'),
                                    content: TextField(
                                      controller: passCtrl,
                                      obscureText: true,
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Şifreniz',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.lock_outline),
                                        helperText: 'En az 6 karakter',
                                      ),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () async {
                                           if (passCtrl.text.trim().length < 6) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre en az 6 karakter olmalı')));
                                              return;
                                           }
                                           Navigator.pop(context); // Dialog kapa
                                           try {
                                              await repo.setPassword(passCtrl.text.trim());
                                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifreniz başarıyla oluşturuldu ✅')));
                                           } catch (e) {
                                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                                           }
                                        },
                                        child: const Text('Kaydet'),
                                      )
                                    ],
                                  ),
                                );
                             }
                          }
                          // Navigate to Dashboard
                          if (mounted) context.go('/dashboard');
                       }
                    },
                    icon: const Icon(Icons.public), 
                    label: const Text('Google ile Giriş Yap'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const Gap(16),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    child: const Text('Hesabın yok mu? Kayıt Ol'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
