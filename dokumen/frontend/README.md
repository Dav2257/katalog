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
│   ├── schedule_production_page.dart     # Jadwal proses pembuatan (Notion-style: Bulanan, Mingguan, Gallery, Board, Table)
│   ├── admin_order_detail_page.dart      # Detail pesanan masuk, kontak WA pembeli, & 4 tahapan produksi custom
│   ├── admin_completed_order_detail_page.dart # Riwayat pesanan selesai dengan tanggal penyelesaian & status
│   ├── admin_user_detail_page.dart       # Detail profil & logo custom Member Private
│   ├── admin_add_product_page.dart       # Tambah produk baru publik dengan auto-complete hashtag & variasi bentuk
│   ├── admin_edit_product_page.dart      # Edit produk publik dengan auto-complete hashtag & sinkronisasi CageService
│   ├── admin_settings_page.dart          # Pengaturan nomor WhatsApp tujuan pesanan, banner, navbar style, & font
│   ├── cart_page.dart                    # Keranjang belanja, tracking pesanan, konfirmasi berfoto, & Pesan WA
│   ├── login_page.dart                   # Halaman login pengguna bertema Jatimas Sangkar (Member & Admin)
│   ├── product_detail_page.dart          # Detail produk bersih (tanpa bintang rating), variasi bentuk sangkar < >, catatan
│   └── user_home_page.dart               # Beranda khusus member (katalog logo custom & request desain)
├── services/                             # Lapisan bisnis & manajemen state terpusat
│   ├── auth_service.dart                 # Layanan autentikasi & pemisahan role (Guest, Member, Admin)
│   ├── cage_service.dart                 # Layanan reaktif manajemen varian bentuk sangkar (ChangeNotifier)
│   ├── order_service.dart                # Layanan pesanan masuk, progres 4 tahap, riwayat selesai, & tracking
│   ├── product_service.dart              # Layanan sinkronisasi data produk katalog publik (tambah/edit/hapus)
│   ├── schedule_service.dart             # Layanan terpusat jadwal proses pembuatan (ProductionScheduleService)
│   ├── hashtag_service.dart              # Layanan database & auto-complete hashtag (SharedPreferences + Supabase)
│   ├── storage_service.dart              # Layanan upload media gambar ke Supabase Storage
│   └── settings_service.dart             # Layanan pengaturan toko, nomor WhatsApp wa.me, banner, style, & font
└── widgets/                              # Komponen UI yang dapat digunakan kembali (reusable)
    ├── hero_banner.dart                  # Komponen visual header dinamis Jatimas Sangkar
    ├── top_navbar.dart                   # Bilah navigasi atas responsif dengan variasi style layout (1-3)
    ├── hashtag_autocomplete_field.dart   # Input hashtag pintar dengan dropdown auto-complete & quick chips
    └── schedule/                         # Komponen tampilan jadwal produksi Notion-style
        ├── schedule_gallery_view.dart    # Tampilan Gallery Notion dengan cover image & status pill
        ├── schedule_board_view.dart      # Tampilan Kanban Board 5 kolom status Notion-style
        ├── schedule_table_view.dart      # Tampilan Grouped Table mingguan Notion-style
        └── schedule_image_helper.dart    # Helper universal render gambar URL & upload Base64 perangkat
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
  - *Latar Belakang*: **Warna Krem Hangat (*Warm Cream / Ivory* - `#F8F4EA`)** pada katalog umum, katalog khusus, dan `web/index.html` yang berpadu serasi dengan nuansa kayu jati.
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
  - Mengelola data master bentuk sangkar secara mandiri baris per baris ke tabel PostgreSQL `public.bentuk_sangkar` di Supabase, cache lokal `SharedPreferences`, dan cadangan storage.
  - Sinkronisasi instan jumlah bentuk sangkar ke kartu metrik dashboard admin (`JUMLAH BENTUK SANGKAR`) dan pilihan variasi bentuk sangkar di detail produk.
  - Otomatis dipanggil saat inisialisasi aplikasi (`main()`) dan saat halaman admin dibuka.
- **`OrderService`**:
  - Mengelola pesanan masuk (`incomingOrders`) dan riwayat pesanan selesai (`completedOrders`).
  - Mendukung update progres 4 tahap produksi (*Verifikasi Desain*, *Kayu Jati*, *Ukir/Grafir*, *Perakitan & Finishing*) dan aksi penyelesaian pesanan (`completeOrder()`).
  - Menyediakan tracking pesanan aktif khusus bagi akun member pada halaman keranjang belanja.
- **`ProductService`**:
  - State manager reaktif untuk katalog produk publik (`ChangeNotifier`).
  - Menyediakan fungsi penambahan produk baru (`addProduct`), pengeditan produk (`updateProduct`), serta penghapusan produk secara langsung disinkronkan dengan tampilan katalog umum.
- **`ProductionScheduleService`**:
  - State manager terpusat untuk agenda jadwal proses pembuatan produk/pesanan.
  - Berbagi satu basis data reaktif (`items`) untuk semua mode tampilan: Bulanan, Mingguan, Gallery, Board (Kanban), dan Table.
  - Menyediakan operasi CRUD (`addItem`, `updateItem`, `deleteItem`) dan penyimpanan permanen lokal serta cloud.
- **`HashtagService`**:
  - Arsitektur hybrid untuk auto-complete tagar produk.
  - Menyimpan cache lokal instan di `SharedPreferences` (`cached_hashtags_list_v1`), tersinkronisasi dengan tabel `public.hashtags` di Supabase, dan auto-harvesting seluruh tag unik dari produk eksisting.
  - Mendukung pencarian instan (`getSuggestions`), pencegahan duplikasi, dan pembuatan tagar baru secara otomatis.
- **`StorageService`**:
  - Layanan unggah media gambar ke Supabase Storage bucket (`katalog`).
  - Mendukung konversi upload file lokal perangkat (laptop/HP) menjadi URL publik permanen dengan fallback data URI Base64.
- **Pemisahan Keranjang Tamu vs Member**:
  - `_guestCart`: Keranjang belanja terisolasi saat bertindak sebagai tamu.
  - `_userCart`: Keranjang belanja terisolasi untuk member login.

---

## 🔗 Dokumen Terkait
- [Rincian Arsitektur UI & Komponen](./arsitektur_ui.md)
