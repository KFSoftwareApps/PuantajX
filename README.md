# PuantajX 🏗️🏗️

**PuantajX**, inşaat ve şantiye yönetimini dijitalleştiren, modern ve verimli bir personel takip ve günlük raporlama uygulamasıdır. Hem mobil (Android/iOS) hem de web platformlarında kesintisiz senkronizasyon ile çalışır.

## ✨ Özellikler

- **📍 Proje Yönetimi:** Birden fazla şantiyeyi ve projeyi tek ekrandan yönetin.
- **👥 Ekip Yönetimi:** Personel listesi, rol tanımları (Sahip, Yönetici, İzleyici) ve ekip bazlı yetkilendirme.
- **📝 Günlük Rapor (Daily Report):** Hava durumu, vardiya, yapılan işler ve görsel kanıtlarla desteklenen profesyonel raporlama sihirbazı.
- **⏰ Puantaj Takibi:** Personel devam kontrolü ve otomatik hakediş hesaplama temelleri.
- **🔄 Gerçek Zamanlı Senkronizasyon:** Supabase Realtime ile veriler tüm cihazlarda anlık olarak güncellenir.
- **📶 Çevrimdışı Mod:** İnternet olmasa dahi veri girişi yapabilir, bağlantı geldiğinde otomatik senkronize edebilirsiniz (Mobil).

## 🚀 Teknoloji Yığını

- **Framework:** [Flutter](https://flutter.dev/) (3.x+)
- **State Management:** [Riverpod](https://riverpod.dev/) (Generator tabanlı)
- **Backend:** [Supabase](https://supabase.com/) (Auth, Database, Storage, Realtime, Functions)
- **Local DB:** [Isar](https://isar.dev/) (Yüksek performanslı NoSQL)
- **Navigation:** [GoRouter](https://pub.dev/packages/go_router)

## 🛠️ Kurulum

1. **Depoyu klonlayın:**
   ```bash
   git clone https://github.com/KFSoftwareApps/PuantajX.git
   ```

2. **Bağımlılıkları yükleyin:**
   ```bash
   flutter pub get
   ```

3. **Kod üreticilerini çalıştırın:**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Uygulamayı başlatın:**
   ```bash
   flutter run
   ```

## 📂 Dosya Yapısı

```text
lib/
├── core/           # Ortak servisler, temalar, widget'lar ve platform adaptörleri
├── features/       # Özellik bazlı klasörleme (Domain-Driven Design yaklaşımı)
│   ├── auth/       # Giriş, Kayıt, Organizasyon ve Ekip Yönetimi
│   ├── project/    # Proje listeleme, detay ve düzenleme
│   ├── report/     # Günlük rapor sihirbazı ve geçmiş raporlar
│   └── workers/    # Personel kayıt ve takip
└── main.dart       # Uygulama giriş noktası
```

## 📄 Lisans

Bu proje **KF Software** tarafından geliştirilmiştir. Tüm hakları saklıdır.

---
Developed with ❤️ by [KF Software](mailto:kfsoftwareapp@gmail.com)
