# 📱 Dokumentasi Frontend (Flutter)

Dokumen ini menjelaskan arsitektur antarmuka, struktur kode, tata cara instalasi, dan panduan pengembangan frontend aplikasi **Katalog**.

---

## 1. 🏗️ Struktur Folder Frontend (`lib/`)

```text
lib/
├── main.dart                             # Titik masuk aplikasi (entry point), routing role, katalog umum, & mobile footer
├── supabase_config.dart                  # Konfigurasi koneksi Supabase client
├── models/                               # Definisi model data
│   └── product.dart                      # Model Product, CartItem, & ProductCageVariation
├── pages/                                # Halaman-halaman antarmuka pengguna
│   ├── admin_dashboard_page.dart         # Dashboard admin (metrik, pesanan, user private, produk umum, sangkar, & footer admin)
│   ├── admin_order_detail_page.dart      # Detail pesanan masuk, kontak WA pembeli, & 4 tahapan produksi custom
│   ├── admin_completed_order_detail_page.dart # Riwayat pesanan selesai dengan tanggal penyelesaian & status
│   ├── admin_user_detail_page.dart       # Detail profil & logo custom Member Private
│   ├── admin_add_product_page.dart       # Tambah produk baru publik dengan auto-complete hashtag & variasi bentuk
│   ├── admin_edit_product_page.dart      # Edit produk publik dengan auto-complete hashtag & sinkronisasi CageService
│   ├── admin_settings_page.dart          # Pengaturan nomor WhatsApp tujuan pesanan, banner, navbar style, & font
│   ├── cart_page.dart                    # Keranjang belanja, tracking pesanan, konfirmasi berfoto, & Pesan WA
│   ├── login_page.dart                   # Halaman login pengguna bertema Jatimas Sangkar (Member & Admin)
│   ├── product_detail_page.dart          # Detail produk bersih (tanpa bintang rating), variasi bentuk sangkar < >, fullscreen viewer
│   └── user_home_page.dart               # Beranda khusus member (katalog logo custom & request desain)
├── services/                             # Lapisan bisnis & manajemen state terpusat
│   ├── auth_service.dart                 # Layanan autentikasi & pemisahan role (Guest, Member, Admin)
│   ├── user_service.dart                 # Layanan pengelolaan member private & toleransi skema Supabase
│   ├── cage_service.dart                 # Layanan reaktif manajemen varian bentuk sangkar (ChangeNotifier, deduplikasi, clean sync)
│   ├── order_service.dart                # Layanan pesanan masuk, progres 4 tahap, riwayat selesai, & tracking
│   ├── product_service.dart              # Layanan sinkronisasi data produk katalog publik (tambah/edit/hapus)
│   ├── hashtag_service.dart              # Layanan database & auto-complete hashtag (SharedPreferences + Supabase)
│   ├── storage_service.dart              # Layanan upload media gambar ke Supabase Storage
│   ├── settings_service.dart             # Layanan pengaturan toko, nomor WhatsApp wa.me, banner, style, & font
│   └── ai_assistant_service.dart         # Layanan asisten cerdas AI teks & visual (filter sapaan, opini, alternatif)
└── widgets/                              # Komponen UI yang dapat digunakan kembali (reusable)
    ├── hero_banner.dart                  # Komponen visual header dinamis Jatimas Sangkar
    ├── top_navbar.dart                   # Bilah navigasi atas responsif (auto-hide keranjang & profil pada mobile)
    ├── hashtag_autocomplete_field.dart   # Input hashtag pintar dengan dropdown auto-complete & quick chips
    ├── product_fullscreen_viewer.dart    # Viewer gambar fullscreen interaktif (pinch-to-zoom, pan, slide < >)
    └── ai_assistant_dialog.dart          # Dialog asisten AI teks & visual, kartu rekomendasi visual, & quick order sheet
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
- **Navigasi Footer Mobile & Clean Header**:
  - Pada layar smartphone (< 768px), antarmuka menampilkan footer navigasi terintegrasi di bagian bawah layar (`bottomNavigationBar`):
    - *Katalog Umum & Member*: Keranjang (badge counter) - Beranda (tombol bulat kuning emas di tengah) - Profil.
    - *Dashboard Admin*: Setting Toko - Preview Umum (tombol bulat etalase di tengah) - Profil Admin.
  - TopNavbar mobile secara pintar menyembunyikan ikon keranjang dan profil agar search bar mendapatkan lebar penuh. Header Admin mobile dioptimalkan hanya menampilkan teks judul tanpa tombol hamburger `☰` dan tanpa ikon profil di header.
- **Viewer Gambar Layar Penuh (`ProductFullscreenViewer`)**:
  - Modal fullscreen interaktif dengan latar gelap (`Colors.black.withValues(alpha: 0.94)`), navigasi slide `<` `>`, pinch-to-zoom, double-tap zoom, mouse drag & wheel, serta indikator nomor slide.
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
  - **Deduplikasi & Sinkronisasi Bersih**: 8 data dummy lama dan duplikasi nama telah dibersihkan secara tuntas. Fungsi `fetchCages` menerapkan deduplikasi nama & ID.
  - **Penghapusan Cloud Terjamin (`await`)**: Fungsi `removeCage` menunggu konfirmasi penghapusan cloud Supabase secara tuntas (`await`) sehingga data yang dihapus tidak pernah muncul kembali saat refresh.
  - Sinkronisasi instan jumlah bentuk sangkar ke kartu metrik dashboard admin (`JUMLAH BENTUK SANGKAR`) dan pilihan variasi bentuk sangkar di detail produk.
- **`OrderService`**:
  - Mengelola pesanan masuk (`incomingOrders`) dan riwayat pesanan selesai (`completedOrders`).
  - Mendukung perekaman nama pemesan (`customerName`) untuk kemudahan identifikasi di dashboard admin.
  - Mendukung update progres 4 tahap produksi (*Verifikasi Desain*, *Kayu Jati*, *Ukir/Grafir*, *Perakitan & Finishing*) dan aksi penyelesaian pesanan (`completeOrder()`).
  - Menyediakan tracking pesanan aktif khusus bagi akun member pada halaman keranjang belanja.
- **`UserService`**:
  - Mengelola data member private (`user_private`), registrasi akun lengkap dengan nama pemesan, dan sinkronisasi pengajuan desain logo custom.
  - Mendukung fitur *auto-fill* data nama dan nomor WhatsApp saat member melakukan checkout dari halaman keranjang.
- **`ProductService`**:
  - State manager reaktif untuk katalog produk publik (`ChangeNotifier`).
  - Menyediakan fungsi penambahan produk baru (`addProduct`), pengeditan produk (`updateProduct`), serta penghapusan produk secara langsung disinkronkan dengan tampilan katalog umum.
- **`HashtagService`**:
  - Arsitektur hybrid untuk auto-complete tagar produk.
  - Menyimpan cache lokal instan di `SharedPreferences` (`cached_hashtags_list_v1`), tersinkronisasi dengan tabel `public.hashtags` di Supabase, dan auto-harvesting seluruh tag unik dari produk eksisting.
  - Mendukung pencarian instan (`getSuggestions`), pencegahan duplikasi, dan pembuatan tagar baru secara otomatis.
- **`StorageService`**:
  - Layanan unggah media gambar ke Supabase Storage bucket (`products` / `katalog`).
  - Mendukung konversi upload file lokal perangkat (laptop/HP) menjadi URL publik permanen dengan fallback data URI Base64.
- **`AppSettingsService`**:
  - Mengelola konfigurasi nomor WhatsApp admin untuk checkout (`wa.me`), banner kustom, navbar style, font katalog, dan pembentukan link WhatsApp berfoto.
- **`AiAssistantService`**:
  - Layanan state manager berbasis `ChangeNotifier` untuk asisten AI interaktif (suara & teks).
  - Terintegrasi dengan model LLM canggih via OpenRouter (`NousResearch/Hermes-3-Llama-3.1-8B`, fallback Groq `llama-3.3-70b-versatile`).
  - **Injeksi Konteks Produk Real-time**: Mengambil data seluruh produk aktif secara otomatis dari `ProductService` (kode, nama, harga, variasi bentuk sangkar, dan warna motif ukiran).
  - **Deteksi Warna & Motif Cerdas**: AI secara otomatis mengenali warna dan motif sangkar (contoh: motif naga biru, emas, merah, hitam, jati natural) berdasarkan deskripsi produk dan preferensi pengguna.
  - **Parsing Ekstraksi Produk**: Dilengkapi regular expression cerdas yang mengekstrak kode produk (`A01`, `A05`, dll.) dari respons AI bahkan dengan berbagai format pemisah (titik, strip, pipa `|`, titik dua `:`).
  - **Proteksi Desain**: AI menegaskan aturan katalog di mana pelanggan umum hanya dapat memesan produk yang tersedia di katalog (bukan membuat desain custom baru dari awal). Catatan pesanan hanya untuk penambahan teks/inisial kecil pada model yang dipilih.
  - **Penyimpanan Lokal**: Persistensi riwayat percakapan dan preferensi suara di `SharedPreferences`.
- **Pemisahan Keranjang Tamu vs Member**:
  - `_guestCart`: Keranjang belanja terisolasi saat bertindak sebagai tamu.
  - `_userCart`: Keranjang belanja terisolasi untuk member login.

---

## 🔗 Dokumen Terkait
- [Rincian Arsitektur UI & Komponen](./arsitektur_ui.md)
