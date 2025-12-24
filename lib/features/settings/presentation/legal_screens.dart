import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/custom_app_bar.dart';
import '../../auth/data/repositories/auth_repository.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Gizlilik Politikası', showProjectChip: false, showSyncStatus: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gizlilik Politikası', style: Theme.of(context).textTheme.headlineMedium),
            const Gap(16),
            Text(
              'PuantajX Gizlilik Politikası (v1.0)\n\n'
              'Yürürlük Tarihi: 08.12.2025\n'
              'Uygulama: PuantajX (“Uygulama”)\n'
              'Veri Sorumlusu: KF Software\n'
              'Adres: Sakarya/Türkiye\n'
              'İletişim: destek@kfsoftware.com\n\n'
              '1) Amaç\n'
              'Bu Gizlilik Politikası; Uygulama’yı kullanırken hangi kişisel verilerin işlendiğini, hangi amaçlarla kullanıldığını, nasıl korunduğunu ve haklarınızı açıklar.\n\n'
              '2) İşlenen Veriler\n'
              'Uygulama kapsamında aşağıdaki veri türleri işlenebilir:\n\n'
              'A) Hesap ve iletişim bilgileri\n'
              '- Ad soyad\n'
              '- E-posta adresi\n'
              '- Telefon numarası (opsiyonel)\n'
              '- Profil fotoğrafı (opsiyonel)\n\n'
              'B) Organizasyon / proje ve iş kayıtları\n'
              '- Organizasyon adı/ID ve üyelik bilgileri (rol, erişimler)\n'
              '- Projeler, konum bilgisi (şehir/ilçe gibi)\n'
              '- Çalışan kayıtları (ad-soyad, görev, ücret türü/saatlik-günlük ücret, notlar)\n'
              '- Puantaj kayıtları (tarih, saat, fazla mesai, durum, açıklama)\n'
              '- Günlük raporlar (yapılan işler, vardiya, hava durumu gibi alanlar)\n'
              '- Hakediş/ödeme özetleri (hesaplanan tutarlar, dönem bazlı raporlar)\n\n'
              'C) Fotoğraf/ekler (kanıt)\n'
              '- Rapor fotoğrafları, ek dosyalar, açıklamalar\n'
              '- Dosya metaverileri (dosya adı, boyut, oluşturma zamanı)\n\n'
              'D) Cihaz ve teknik veriler\n'
              '- Cihaz modeli, işletim sistemi sürümü, uygulama sürümü\n'
              '- Hata/çökme kayıtları (varsa)\n'
              '- Senkron kayıtları (son senkron zamanı, bekleyen işlem sayısı gibi)\n\n'
              'E) Destek iletişimi\n'
              '- Destek taleplerinde paylaştığınız mesajlar ve ekler\n\n'
              'Not: Uygulama iş gereği kullanılmak üzere tasarlanmıştır. Uygulamaya gereksiz hassas veri (ör. sağlık verisi, kimlik numarası) girilmemesi önerilir.\n\n'
              '3) Verilerin İşlenme Amaçları\n'
              'Verileriniz şu amaçlarla işlenir:\n'
              '- Hesap oluşturma, kimlik doğrulama, oturum yönetimi\n'
              '- Proje/rapor/puantaj kayıtlarının tutulması ve yönetimi\n'
              '- Organizasyon içi rol ve yetkilendirmelerin uygulanması\n'
              '- Bulut senkronizasyon (aktifse) ve çok cihaz kullanımının sağlanması\n'
              '- PDF/Excel/CSV çıktı üretimi (planınıza bağlı olarak)\n'
              '- Destek sağlama, hata tespiti, hizmetin iyileştirilmesi\n'
              '- Yasal yükümlülüklerin yerine getirilmesi (gerektiğinde)\n\n'
              '4) Hukuki Sebep (KVKK)\n'
              'Kişisel verileriniz, KVKK madde 5 ve ilgili mevzuata uygun olarak, aşağıdaki işleme şartlarına dayanarak işlenebilir:\n'
              '- Bir sözleşmenin kurulması veya ifasıyla doğrudan ilgili olması\n'
              '- Veri sorumlusunun hukuki yükümlülüğünü yerine getirebilmesi\n'
              '- Bir hakkın tesisi, kullanılması veya korunması\n'
              '- Meşru menfaat (temel hak ve özgürlüklerinize zarar vermemek kaydıyla)\n'
              '- Gerekli hallerde açık rıza (ör. pazarlama iletişimi, opsiyonel analitik vb.)\n\n'
              '5) Verilerin Saklanması ve Süreler\n'
              'Veriler; hizmetin sunulması için gerekli süre boyunca saklanır. Örnek saklama yaklaşımı:\n'
              '- Hesap verileri: Hesap aktif olduğu sürece\n'
              '- Organizasyon/proje kayıtları: Organizasyon hesabı aktif olduğu sürece\n'
              '- Yedekler: Kullanıcının oluşturduğu yedek dosyaları kullanıcı kontrolündedir\n'
              '- Log/denetim kayıtları (varsa): Yasal süre boyunca saklanır\n'
              '- Hesap silme sonrası: Yasal yükümlülükler gerektiriyorsa sınırlı süre saklanabilir, aksi halde silinir/anonimleştirilir\n\n'
              '6) Üçüncü Taraf Hizmet Sağlayıcılar\n'
              'Verileriniz satılmaz. Ancak hizmetin çalışması için aşağıdaki üçüncü taraf hizmet sağlayıcılarıyla, yalnızca gerekli olduğu ölçüde veri paylaşımı/aktarımı yapılabilir:\n\n'
              'A) Abonelik ve ödeme işlemleri\n'
              'Ödemeler App Store / Play Store üzerinden işlenir. Kart/banka bilgileriniz tarafımızca saklanmaz. Mağazalar; satın alma durumu, abonelik yenileme/iptal ve iade süreçlerini kendi politikalarına göre yönetir.\n'
              '- Apple App Store (Apple Inc.)\n'
              '- Google Play (Google LLC)\n\n'
              'B) Bulut senkronizasyon (özellik etkinse)\n'
              'Bulut senkron özelliği etkinleştirildiğinde; organizasyon/proje/rapor/puantaj verileri ve (varsa) ek dosyalar bulut altyapısına aktarılabilir.\n'
              '- Supabase (kimlik doğrulama, veritabanı ve dosya depolama hizmetleri)\n\n'
              'C) E-posta bildirimleri ve doğrulamalar (özellik etkinse)\n'
              'Davet, e-posta doğrulama ve fatura e-postası doğrulama süreçlerinde e-posta gönderim hizmetleri kullanılabilir. Bu kapsamda e-posta adresiniz ve gönderim içeriği (doğrulama/davet bağlantısı gibi) işlenebilir.\n'
              '- E-posta gönderim sağlayıcısı: Resend\n\n'
              'D) Bildirimler (özellik etkinse)\n'
              'Uygulama bildirim gönderebilmek için cihaz bildirim token’larını kullanabilir.\n'
              '- Firebase Cloud Messaging (FCM) ve/veya Apple Push Notification Service (APNs)\n\n'
              'E) Hata/performans izleme (özellik etkinse)\n'
              'Uygulamanın güvenli ve hatasız çalışmasını sağlamak için çökme ve hata kayıtları toplanabilir. Bu kayıtlarda cihaz ve uygulama sürümü gibi teknik veriler yer alabilir.\n'
              '- Sentry\n\n'
              'F) İletişim kanalları\n'
              'WhatsApp desteği kullanıldığında, ilgili iletişim Meta/WhatsApp altyapısı üzerinden yürütülür.\n'
              '- WhatsApp\n\n'
              '7) Güvenlik\n'
              'Verilerin güvenliği için makul teknik ve idari tedbirler uygulanır:\n'
              '- Aktarım sırasında şifreleme (TLS/HTTPS)\n'
              '- Erişim kontrolü ve rol bazlı yetkilendirme\n'
              '- Düzenli güncelleme ve güvenlik iyileştirmeleri\n'
              '- Bulut depolamada erişim anahtarlarının korunması\n\n'
              '8) Kullanıcı Hakları (KVKK)\n'
              'KVKK kapsamında şu haklara sahipsiniz:\n'
              '- Kişisel verilerinizin işlenip işlenmediğini öğrenme\n'
              '- İşlenmişse bilgi talep etme\n'
              '- Amacına uygun kullanılıp kullanılmadığını öğrenme\n'
              '- Eksik/yanlış işlenmişse düzeltilmesini isteme\n'
              '- Şartları oluştuğunda silinmesini veya yok edilmesini isteme\n'
              '- Aktarıldığı üçüncü kişilere bildirilmesini isteme\n'
              '- Kanuna aykırı işlem nedeniyle zararın giderilmesini talep etme\n'
              'Başvurularınızı destek@kfsoftware.com adresine “KVKK Başvurusu” konusu ile iletebilirsiniz.\n\n'
              '9) Çocukların Gizliliği\n'
              'Uygulama 18 yaş altına yönelik değildir.\n\n'
              '10) Değişiklikler\n'
              'Bu politika zaman zaman güncellenebilir. Güncel sürüm Uygulama içinde yayınlanır.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Kullanım Koşulları', showProjectChip: false, showSyncStatus: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kullanım Koşulları', style: Theme.of(context).textTheme.headlineMedium),
            const Gap(16),
            Text(
              'PuantajX Kullanım Koşulları (v1.0)\n\n'
              'Yürürlük Tarihi: 08.12.2025\n'
              'Uygulama: PuantajX (“Hizmet”)\n'
              'Hizmet Sağlayıcı: KF Software\n\n'
              '1) Kabul\n'
              'Uygulamayı indirerek/hesap oluşturarak bu Koşulları kabul etmiş sayılırsınız. Kabul etmiyorsanız Uygulama’yı kullanmayın.\n\n'
              '2) Hesap ve Sorumluluk\n'
              '- Hesap bilgilerinizin doğruluğundan siz sorumlusunuz.\n'
              '- Hesabınızla yapılan işlemlerden siz sorumlu olursunuz.\n'
              '- Organizasyon içinde davet ettiğiniz kullanıcıların erişimlerini yönetmek sizin sorumluluğunuzdadır.\n\n'
              '3) Hizmetin Kapsamı\n'
              'PuantajX; proje, ekip, günlük rapor, puantaj, foto/ek ve (planınıza bağlı olarak) hakediş/ödeme özetleri oluşturmanıza yardımcı olur. Bazı özellikler ücretli plan gerektirebilir.\n\n'
              '4) Ücretli Planlar, Abonelik ve Ödemeler\n'
              '- Abonelik satın alma ve yenileme işlemleri App Store / Play Store üzerinden yapılır.\n'
              '- Abonelik iptali ilgili mağaza hesabınızdan yönetilir.\n'
              '- İptal edilse bile, kural olarak mevcut fatura döneminin sonuna kadar erişim sürebilir (mağaza kurallarına tabidir).\n'
              '- İade/geri ödeme süreçleri mağazanın kendi politikalarına tabidir.\n\n'
              '5) Plan Limitleri\n'
              'Free/Pro/Business planlarında proje sayısı, kullanıcı sayısı, çalışan sayısı, depolama ve geçmiş kayıt gibi limitler uygulanabilir. Limitler Uygulama içinde plan ekranında gösterilir ve gerektiğinde güncellenebilir.\n\n'
              '6) Kullanıcı İçeriği ve Mülkiyet\n'
              '- Uygulamaya girdiğiniz raporlar, puantajlar, fotoğraflar ve diğer içerikler (“Kullanıcı İçeriği”) size/organizasyonunuza aittir.\n'
              '- Hizmeti sunmak için bu içeriği işleme, saklama, senkronlama, çıktı alma (PDF/Excel) gibi teknik işlemler yapmamıza izin verirsiniz.\n'
              '- Biz, Kullanıcı İçeriğinizi satmayız.\n\n'
              '7) Yasaklı Kullanımlar\n'
              'Uygulamayı şu amaçlarla kullanamazsınız:\n'
              '- Hukuka aykırı faaliyetler\n'
              '- Yetkisiz erişim sağlama, sistemleri bozma, tersine mühendislik\n'
              '- Zararlı içerik yayma, kötü amaçlı yazılım yükleme\n'
              '- Başkalarının haklarını ihlal etme\n\n'
              '8) Hizmetin Sürekliliği ve Değişiklikler\n'
              '- Hizmeti iyileştirmek için özellikleri değiştirebilir, ekleyebilir veya kaldırabiliriz.\n'
              '- Bakım/arıza nedeniyle kesinti yaşanabilir.\n'
              '- Kritik değişikliklerde Uygulama içinde bilgilendirme yapılabilir.\n\n'
              '9) Yedekleme ve Veri Kaybı\n'
              '- Uygulama yedekleme seçenekleri sunabilir. Yedek alma, saklama ve geri yükleme süreçlerinin doğru uygulanması kullanıcı sorumluluğundadır.\n'
              '- İnternet bağlantısı, cihaz sorunları veya hatalı kullanım nedeniyle veri kaybı riski tamamen sıfırlanamaz.\n\n'
              '10) Sorumluluğun Sınırlandırılması\n'
              'Hizmet “olduğu gibi” sunulur. Dolaylı zararlar, kar kaybı, iş kesintisi gibi sonuçlardan mevzuatın izin verdiği ölçüde sorumluluk kabul edilmez. Zorunlu tüketici hakları saklıdır.\n\n'
              '11) Hesabın Askıya Alınması / Sonlandırılması\n'
              'Aşağıdaki durumlarda hesabınızı/erişiminizi askıya alabilir veya sonlandırabiliriz:\n'
              '- Koşulların ihlali\n'
              '- Güvenlik riski\n'
              '- Yasal zorunluluk\n\n'
              '12) Uygulanacak Hukuk ve Yetki\n'
              'Bu koşullar Türkiye Cumhuriyeti hukukuna tabidir. Uyuşmazlıklarda Sakarya mahkemeleri ve icra daireleri yetkilidir (tüketici işlemleri için ilgili yasal yetkiler saklıdır).\n\n'
              '13) İletişim\n'
              'Destek ve yasal başvurular için: destek@kfsoftware.com\n\n'
              '14) Değişiklikler\n'
              'Koşullar güncellenebilir. Güncel sürüm Uygulama içinde yayınlanır.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Hakkında'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Placeholder
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check, size: 60, color: Colors.white),
            ),
            const Gap(24),
            Text('PuantajX', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Gap(8),
            Text('Sürüm 1.0.0 (Build 12)', style: TextStyle(color: Colors.grey[600])),
            const Gap(32),
            Text('© 2025 PuantajX. Tüm hakları saklıdır.', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }
}

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hesabı Sil', style: TextStyle(color: Colors.red)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bu işlem GERİ ALINAMAZ. Tüm verileriniz, projeleriniz ve çalışanlarınız kalıcı olarak silinecektir.',
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          const Gap(16),
          Text('Onaylamak için "SİL" yazın:', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
          const Gap(8),
          TextField(
            controller: _confirmCtrl,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'SİL'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          onPressed: _confirmCtrl.text == 'SİL' && !_isLoading
              ? () async {
                  setState(() => _isLoading = true);
                  try {
                    await ref.read(authControllerProvider.notifier).deleteAccount();
                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
                      context.go('/login');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog first if possible or handle error
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                    }
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Hesabı Sil'),
        ),
      ],
    );
  }
}
