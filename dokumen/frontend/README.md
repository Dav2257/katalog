# 📱 Dokumentasi Frontend (Flutter)

Dokumen ini menjelaskan arsitektur antarmuka, struktur kode, tata cara instalasi, dan panduan pengembangan frontend aplikasi **Katalog**.

---

## 1. 🏗️ Struktur Folder Frontend (`lib/`)

```text
lib/
├── main.dart                             # Titik masuk aplikasi (entry point), routing role, & katalog umum
├── supabase_config.dart                  # Konfigurasi koneksi Supabase client
├── models/                               # Definisi model data
│   └── product.dart                      # Model Product, CartItem, & ProductCageVariation
├── pages/                                # Halaman-halaman antarmuka pengguna
│   ├── admin_dashboard_page.dart         # Dashboard admin (analisis data, pesanan, user private, produk umum, sangkar)
│   ├── admin_order_detail_page.dart      # Detail pesanan masuk, kontak WA pembeli, & 4 tahapan produksi custom
│   ├── admin_completed_order_detail_page.dart # Riwayat pesanan selesai dengan tanggal penyelesaian & status
│   ├── admin_user_detail_page.dart       # Detail profil & logo custom Member Private
│   ├── admin_add_product_page.dart       # Tambah produk baru publik dengan foto & bentuk sangkar
│   ├── admin_edit_product_page.dart      # Edit produk publik dengan sinkronisasi dua arah ke CageService
│   ├── admin_settings_page.dart          # Pengaturan nomor WhatsApp tujuan pesanan, banner, navbar style, & font
│   ├── cart_page.dart                    # Keranjang belanja, tracking pesanan, konfirmasi berfoto, & Pesan WA
│   ├── login_page.dart                   # Halaman login pengguna bertema Jatimas Sangkar (Member & Admin)
│   ├── product_detail_page.dart          # Detail produk, navigasi bentuk sangkar < >, catatan, & kuantitas
│   └── user_home_page.dart               # Beranda khusus member (katalog logo custom & request desain)
├── services/                             # Lapisan bisnis & manajemen state terpusat
│   ├── auth_service.dart                 # Layanan autentikasi & pemisahan role (Guest, Member, Admin)
│   ├── cage_service.dart                 # Layanan reaktif manajemen varian bentuk sangkar (ChangeNotifier)
│   ├── order_service.dart                # Layanan pesanan masuk, progres 4 tahap, riwayat selesai, & tracking
│   ├── product_service.dart              # Layanan sinkronisasi data produk katalog publik (tambah/edit/hapus)
│   └── settings_service.dart             # Layanan pengaturan toko, nomor WhatsApp wa.me, banner, style, & font
└── widgets/                              # Komponen UI yang dapat digunakan kembali (reusable)
    ├── hero_banner.dart                  # Komponen visual header dinamis Jatimas Sangkar
    └── top_navbar.dart                   # Bilah navigasi atas responsif dengan variasi style layout (1-3)
```

---

## 2. ⚙️ Prasyarat & Instalasi

Pastikan telah menginstal:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi `>= 3.11.4`)
- [Dart SDK](https://dart.dev/)
- Android Studio / VS Code dengan ekstensi Flutter & Dart

### Langkah Menjalankan Aplikasi:

1. **Ambil Dependensi:**
   ```bash
   flutter pub get
   ```

2. **Jalankan Aplikasi pada Perangkat / Emulator:**
   ```bash
   # Menjalankan di Chrome (Web)
   flutter run -d chrome

   # Menjalankan di Windows Desktop
   flutter run -d windows

   # Menjalankan di Android Device/Emulator
   flutter run
   ```

3. **Build Aplikasi (Produksi):**
   ```bash
   # Build APK Android
   flutter build apk --release

   # Build Web
   flutter build web --release
   ```

---

## 3. 🎨 Tema & Gaya Desain (Design System)

- **Design Guidelines**: Google Material Design 3 (`useMaterial3: true`).
- **Palet Warna**:
  - *Teakwood Brown*: `#382314` (sidebar admin & aksen gelap) dan `#7A4B29` / `#8B5328` (indikator metrik & tombol utama).
  - *WhatsApp Green*: `#25D366` (tombol pesan WA & badge selesai).
  - *Latar Belakang*: `Colors.grey.shade50` dan `#F5F6F8` (kontras lembut dan bersih).
- **Page Transitions**: Dikonfigurasi tanpa animasi transisi (*instant transition*) via custom `PageTransitionsTheme` untuk navigasi cepat dan responsif.
- **Dukungan Scrolling Desktop**:
  - `ScrollConfiguration` dengan `PointerDeviceKind.mouse` aktif.
  - Event konversi perputaran roda mouse vertikal ke horizontal untuk baris bentuk sangkar (`SingleChildScrollView`).

---

## 4. 🧠 Manajemen State & Service Layer

Aplikasi menggunakan arsitektur modular yang rapi dengan kombinasi **StatefulWidget & ChangeNotifier Services**:
- **`AuthService`**:
  - Mengelola sesi dan hak akses (`isGuest`, `isLoggedIn`, `isAdmin`).
  - Mengarahkan akun admin (`admin@gmail.com`) ke `AdminDashboardPage`, dan member ke `UserHomePage`.
- **`CageService`**:
  - State manager terpusat menggunakan `ChangeNotifier`.
  - Sinkronisasi instan jumlah bentuk sangkar ke kartu metrik dashboard admin (`JUMLAH BENTUK SANGKAR`) dan pilihan sangkar pada halaman detail produk.
- **`OrderService`**:
  - Mengelola pesanan masuk (`incomingOrders`) dan riwayat pesanan selesai (`completedOrders`).
  - Mendukung update progres 4 tahap produksi (*Verifikasi Desain*, *Kayu Jati*, *Ukir/Grafir*, *Perakitan & Finishing*) dan aksi penyelesaian pesanan (`completeOrder()`).
  - Menyediakan tracking pesanan aktif khusus bagi akun member pada halaman keranjang belanja.
- **`ProductService`**:
  - State manager reaktif untuk katalog produk publik (`ChangeNotifier`).
  - Menyediakan fungsi penambahan produk baru (`addProduct`), pengeditan produk (`updateProduct`), serta penghapusan produk secara langsung disinkronkan dengan tampilan katalog umum.
- **`AppSettingsService`**:
  - Mengelola preferensi toko oleh Admin: nomor WhatsApp tujuan pesanan (`adminWhatsApp`), banner kustom, style navbar (1-3), dan font katalog.
  - Membentuk link pemesanan WhatsApp (`createOrderWhatsAppUri`) berformat rapi yang otomatis menyematkan **nama produk, bentuk sangkar, kuantitas, catatan, dan link foto produk**.
- **Pemisahan Keranjang Tamu vs Member**:
  - `_guestCart`: Keranjang belanja terisolasi saat bertindak sebagai tamu.
  - `_userCart`: Keranjang belanja terisolasi untuk member login.

---

## 🔗 Dokumen Terkait
- [Rincian Arsitektur UI & Komponen](./arsitektur_ui.md)
