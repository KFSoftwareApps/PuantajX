import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../core/constants/plans.dart';
import '../../../core/subscription/subscription_service.dart';
import '../../../core/widgets/custom_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/iap_service.dart';
import '../../../features/auth/data/repositories/auth_repository.dart';
import '../../../core/subscription/plan_config.dart' show SubscriptionPlan;
import '../../../core/subscription/subscription_model.dart';
import '../../../core/subscription/subscription_providers.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium\'a Yükselt')),
      body: const SafeArea(child: PaywallContent()),
    );
  }
}

class PaywallContent extends ConsumerStatefulWidget {
  final bool isDialog;
  const PaywallContent({super.key, this.isDialog = false});

  @override
  ConsumerState<PaywallContent> createState() => _PaywallContentState();
}

class _PaywallContentState extends ConsumerState<PaywallContent> {
  final PageController _controller = PageController(viewportFraction: 0.9);

  @override
  Widget build(BuildContext context) {
    try {
      // Use the new products provider
      final productsAsync = ref.watch(productsProvider);

      return productsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (e, s) {
               return Center(
                 child: SingleChildScrollView(
                   padding: const EdgeInsets.all(24),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const Icon(Icons.error_outline, size: 48, color: Colors.red),
                       const Gap(16),
                       Text(
                         'Mağaza Hatası',
                         style: Theme.of(context).textTheme.titleLarge,
                         textAlign: TextAlign.center,
                       ),
                       const Gap(8),
                       Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           color: Colors.red.shade50,
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: Colors.red.shade100),
                         ),
                         child: Text(
                           'Hata: $e',
                           style: const TextStyle(color: Colors.red, fontSize: 12),
                           textAlign: TextAlign.center,
                         ),
                       ),
                       const Gap(24),
                       ElevatedButton.icon(
                         onPressed: () => ref.refresh(productsProvider), 
                         icon: const Icon(Icons.refresh),
                         label: const Text('Tekrar Dene'),
                       )
                     ],
                   ),
                 ),
               );
            },
            data: (products) {
              if (products.isEmpty) {
                 return Center(
                   child: SingleChildScrollView(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         const Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.blueGrey),
                         const Gap(16),
                         const Text('Ürün Bulunamadı', style: TextStyle(fontWeight: FontWeight.bold)),
                         const Gap(8),
                         const Padding(
                           padding: EdgeInsets.symmetric(horizontal: 32),
                           child: Text(
                             'Google Play Store ürün listesi boş döndü. Lütfen internet bağlantınızı kontrol edin veya Google Play hesabınızın test lisansına sahip olduğundan emin olun.',
                             textAlign: TextAlign.center,
                             style: TextStyle(fontSize: 12, color: Colors.grey),
                           ),
                         ),
                         const Gap(16),
                         ElevatedButton(
                           onPressed: () => ref.refresh(productsProvider),
                           child: const Text('Yenile'),
                         )
                       ],
                     ),
                   ),
                 );
              }

              return _buildPaywallUI(context, products);
            },
          );
    } catch (e) {
      return Material(
        color: Colors.white,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'KRİTİK GÖRÜNTÜLEME HATASI:\n$e', 
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildPaywallUI(BuildContext context, List<ProductDetails> products) {
        // Sort products or filter them if needed
        // Assuming products contains pro and business monthly
        
        return ListView(
               padding: const EdgeInsets.all(16),
               shrinkWrap: widget.isDialog,
               children: [
                 _buildHeader(context),
                 // Map Products to Cards
                 ...products.map((product) {
                    final isBusiness = product.id.contains('business');
                    return _PlanCard(
                      product: product,
                      features: isBusiness 
                        ? const ['Sınırsız Proje', '25 Kullanıcı', 'Onay Akışı & Loglar', 'Excel Export']
                        : const ['5 Proje', '10 Kullanıcı', 'Bulut Yedekleme', 'Filigransız PDF'],
                      isRecommended: !isBusiness,
                      color: isBusiness ? Colors.purple : Colors.blue,
                    );
                 }),
                 _buildFooter(context),
               ],
             );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
         if (widget.isDialog) ...[
             const Center(child: Icon(Icons.star_border, size: 48, color: Colors.amber)),
             const Gap(8),
          ] else ...[
             const Icon(Icons.star_border, size: 60, color: Colors.amber),
             const Gap(16),
          ],
          Text(
            'Limitlere Takılma!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          const Text(
            'İhtiyacınıza uygun planı seçin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          const Gap(16),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
         const Gap(16),
         const Text(
          'Abonelikler otomatik yenilenir. İstediğin zaman iptal et.',
          style: TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        TextButton(
            onPressed: () async {
              // Prepare restoration
              final iapService = ref.read(iapServiceProvider);
              await iapService.restorePurchases();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Satın alımlar geri yükleniyor...')));
              }
              // Note: The actual restoration logic should be handled by listening to the stream in a top-level widget or here
              // For simplicity in this migration, allow user to trigger it and feedback depends on stream listener elsewhere
            },
            child: const Text('Satın Alımları Geri Yükle', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        const Gap(20),
      ],
    );
  }
}

class _PlanCard extends ConsumerWidget {
  final PlanConfig? config;
  final ProductDetails? product; // From IAP
  final List<String> features;
  final bool isRecommended;
  final Color color;

  const _PlanCard({
    this.config,
    this.product,
    required this.features,
    this.isRecommended = false,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                if (isRecommended)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('En Popüler', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                Text(
                  product != null ? product!.title.replaceAll('(PuantajX)', '').trim() : (config?.name ?? 'Plan'), 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const Gap(8),
                Text(
                  product != null 
                      ? product!.price
                      : '${config?.monthlyPrice.toStringAsFixed(0)} ₺ / Ay',
                  style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.bold),
                ),
                const Gap(24),
                // Features
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 20, color: color),
                      const Gap(8),
                      Expanded(child: Text(f)),
                    ],
                  ),
                )),
              ],
            ),
            
            // Button at the bottom
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: CustomButton(
                text: product != null 
                   ? 'Satın Al ${product!.price}'
                   : 'Abone Ol (${config?.monthlyPrice.toStringAsFixed(0) ?? 0} ₺)',
                backgroundColor: color,
                onPressed: () {
                  if (product != null) {
                     _handlePurchase(context, ref, product!);
                     return;
                  }
                },
              ),
            ),
          ],
        ),
      );
    } catch (e, s) {
      return Container(
        height: 100,
        color: Colors.red.shade100,
        alignment: Alignment.center,
        child: Text('Render Hatası: $e', style: const TextStyle(color: Colors.red)),
      );
    }
  }

  Future<void> _handlePurchase(BuildContext context, WidgetRef ref, ProductDetails product) async {
    try {
      final iapService = ref.read(iapServiceProvider);
      await iapService.buyProduct(product);
      // The stream listener in the service/provider should handle the rest
    } catch (e) {
      debugPrint('Purchase Error: $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }
}
