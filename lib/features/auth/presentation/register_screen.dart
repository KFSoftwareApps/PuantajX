import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../data/repositories/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _orgController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError) {
        final err = next.error.toString();
        
        // 1. Check for specific ignored errors first
        if (err.contains('Hatalı e-posta') || err.contains('Invalid login')) {
          // Ignore confusing login errors on register screen
          return;
        }

        // 2. Check for Email Verification
        if (err.contains('Lütfen e-posta')) {
           showDialog(
             context: context,
             barrierDismissible: false,
             builder: (c) => AlertDialog(
               title: const Text('✉️ E-Posta Doğrulama'),
               content: Text(err.replaceAll('Exception: ', '')),
               actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(c); // Close dialog
                      context.go('/login'); // Go to login
                    }, 
                    child: const Text('Tamam')
                  )
               ],
             ),
           );
        } else {
           // 3. Show other actual errors
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(err.replaceAll('Exception: ', ''))),
           );
        }
      }
      if (next.value != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        context.go('/dashboard');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                label: 'Ad Soyad',
                controller: _nameController,
              ),
              const Gap(16),
              CustomTextField(
                label: 'Firma / Organizasyon Adı',
                controller: _orgController,
                hint: 'Örn: Demir İnşaat',
                validator: (val) => val == null || val.isEmpty ? 'Lütfen firma / organizasyon adını giriniz' : null,
              ),
              const Gap(16),
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
              const Gap(16),

              // Legal Consent Checkboxes
              _LegalCheckbox(
                value: _termsAccepted,
                onChanged: (val) => setState(() => _termsAccepted = val ?? false),
                text: 'Kullanım Koşulları',
                linkText: 'nı okudum ve kabul ediyorum.',
                onLinkTap: () => context.push('/terms-of-service'),
              ),
              _LegalCheckbox(
                value: _privacyAccepted,
                onChanged: (val) => setState(() => _privacyAccepted = val ?? false),
                text: 'Gizlilik Politikası',
                linkText: 'nı okudum ve kabul ediyorum.',
                onLinkTap: () => context.push('/privacy-policy'),
              ),
              const Gap(24),

              CustomButton(
                text: 'Hesap Oluştur',
                isLoading: isLoading,
                onPressed: (_termsAccepted && _privacyAccepted) 
                  ? () {
                      if (_formKey.currentState!.validate()) {
                         ref.read(authControllerProvider.notifier).register(
                           _emailController.text,
                           _passwordController.text,
                           _nameController.text,
                           _orgController.text,
                         );
                      }
                    }
                  : null, // Disable if not accepted
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String text;
  final String linkText;
  final VoidCallback onLinkTap;

  const _LegalCheckbox({
    required this.value,
    required this.onChanged,
    required this.text,
    required this.linkText,
    required this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const Gap(8),
        Expanded(
          child: GestureDetector(
            onTap: onLinkTap,
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12),
                children: [
                  TextSpan(
                    text: text,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: linkText),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

