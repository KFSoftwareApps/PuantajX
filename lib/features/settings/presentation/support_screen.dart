import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/custom_app_bar.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Destek ve İletişim', showProjectChip: false, showSyncStatus: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.support_agent, size: 48, color: Theme.of(context).colorScheme.primary),
                ),
                const Gap(16),
                Text(
                  'Nasıl yardımcı olabiliriz?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Gap(8),
                Text(
                  'Sorularınız ve geri bildirimleriniz için bize ulaşın.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Gap(32),

          // Contact Options
          _SectionHeader('İLETİŞİM KANALLARI'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: Theme.of(context).cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), 
              side: BorderSide(color: Theme.of(context).dividerColor)
            ),
            child: Column(
              children: [
                _ContactTile(
                  icon: Icons.email_outlined,
                  title: 'E-posta Gönder',
                  subtitle: 'destek@puantajx.com',
                  onTap: () => _launchUrl('mailto:destek@puantajx.com'),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                _ContactTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'WhatsApp Destek',
                  subtitle: '+90 850 123 45 67',
                  onTap: () => _launchUrl('https://wa.me/908501234567'), // Placeholder
                ),
              ],
            ),
          ),
          const Gap(24),

          // Legal
          _SectionHeader('YASAL'),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: Theme.of(context).cardTheme.color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), 
              side: BorderSide(color: Theme.of(context).dividerColor)
            ),
            child: Column(
              children: [
                _ContactTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Gizlilik Politikası',
                  onTap: () => context.push('/settings/privacy-policy'), // Assuming route exists or will exist based on legal_screens.dart
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                _ContactTile(
                  icon: Icons.description_outlined,
                  title: 'Kullanım Koşulları',
                  onTap: () => context.push('/settings/terms-of-service'),
                ),
              ],
            ),
          ),
          const Gap(48),

          // Version
          Center(
            child: Text(
              'Versiyon $_version',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[600])) : null,
      trailing: Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
