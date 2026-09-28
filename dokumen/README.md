# Dokumentasi Proyek Katalog

Selamat datang di direktori dokumentasi proyek **Katalog (Jatimas Sangkar)**. Dokumentasi ini disusun untuk memberikan gambaran lengkap mengenai perencanaan, arsitektur antarmuka (frontend), service layer, serta infrastruktur dan basis data (backend).

---

## 📁 Struktur Direktori Dokumen

```text
dokumen/
├── README.md                      # Indeks utama dokumentasi proyek
├── planing/                       # Perencanaan proyek & analisis kebutuhan
│   ├── README.md                  # Ringkasan perencanaan, target pengguna, backlog, & roadmap pengembangan
│   └── spesifikasi_projek.md      # SRS, use case, alur sistem (Guest, Member, Admin), & kebutuhan fungsional
├── frontend/                      # Dokumentasi client-side (Flutter)
│   ├── README.md                  # Panduan setup, struktur lib, service layer, & design system
│   └── arsitektur_ui.md           # Rincian halaman (Admin Dashboard, Member, Cart, dll.), navigasi, & widget
└── backend/                       # Dokumentasi server-side & database (Supabase)
    ├── README.md                  # Konfigurasi Supabase, autentikasi role, Storage, & integrasi Service
    └── skema_database.md          # Struktur 6 tabel inti aktif (produk, produk_custom, user_private, pesanan, bentuk_sangkar, app_settings), Storage, & RLS
```

---

## 📌 Ringkasan Bagian Dokumen

| Kategori | Deskripsi | Tautan |
| :--- | :--- | :--- |
| **Planing** | Rencana proyek, ruang lingkup, target pengguna, kebutuhan fungsional (FR-01 s/d FR-47) & non-fungsional, alur pengguna, serta roadmap rilis. | [Lihat Dokumen Planing](./planing/README.md) |
| **Frontend** | Arsitektur aplikasi Flutter, rincian seluruh halaman (`AdminDashboardPage`, `AdminOrderDetailPage`, `AdminCompletedOrderDetailPage`, `AdminUserDetailPage`, `AdminAddProductPage`, `AdminEditProductPage`, `AdminSettingsPage`, `UserHomePage`, `CartPage`, `ProductDetailPage`), gestur pull-to-refresh, hero banner edge-to-edge dengan optimasi WebGL, asisten AI teks & visual (`AiAssistantDialog`), kartu rekomendasi visual produk, navigasi footer mobile (Katalog & Admin), viewer layar penuh (`ProductFullscreenViewer`), tema warna krem hangat, rangkaian pengujian anti-overflow otomatis (`test/overflow_test.dart`), service layer (`AuthService`, `UserService`, `CageService`, `OrderService`, `ProductService`, `AppSettingsService`, `AiAssistantService`, `HashtagService`, `StorageService`), komponen (`widgets`), dan manajemen state. | [Lihat Dokumen Frontend](./frontend/README.md) |
| **Backend** | Integrasi Backend-as-a-Service (BaaS) Supabase, konfigurasi URL & API Key, skema 8 tabel aktif PostgreSQL (`produk`, `produk_custom`, `user_private`, `pesanan`, `bentuk_sangkar`, `app_settings`, `hashtags`, `production_schedules`), strategi decoupling media ke Cloudinary (25 GB), deployment Cloudflare Pages via `wrangler.json` (`jatimas.derylandri.my.id`), dan aturan keamanan (RLS). | [Lihat Dokumen Backend](./backend/README.md) |

---

## 🛠️ Stack Teknologi & Infrastruktur

- **Frontend Framework**: [Flutter SDK](https://flutter.dev/) (Dart `>= 3.11.4`)
- **AI Intelligence**: [OpenRouter API](https://openrouter.ai/) (Nous Hermes 3 Llama-3.1 8B) & [Groq Cloud](https://groq.com/) (Llama 3.3 70B Versatile), filter intent sapaan & konsultasi opini murni
- **Input Suara & Gestur**: `speech_to_text` (input suara mikrofon), percakapan teks hening responsif, dan `RefreshIndicator` (pull-to-refresh mobile)
- **Backend & Database**: [Supabase](https://supabase.com/) (PostgreSQL 8 Tabel Inti Aktif + JSONB, Supabase Auth, Storage)
- **Storage & Media Decoupling**: Supabase Storage + kesiapan decoupling ke [Cloudinary](https://cloudinary.com/) (CDN global 25 GB free tier)
- **Web Hosting & Edge CDN**:
  - [Cloudflare Pages](https://pages.cloudflare.com/) (`https://jatimas.derylandri.my.id`) via Wrangler (`wrangler.json`)
  - [Firebase Hosting](https://firebase.google.com/) (`https://katalog-jatimas-2257.web.app`)
- **Quality Assurance**: Automated Widget Test Suite (`test/overflow_test.dart`) memvalidasi imunitas overflow di resolusi 320px, 600px, dan 1200px
- **State & Service Layer**: Modular Service Pattern (`ChangeNotifier`, `AuthService`, `UserService`, `CageService`, `OrderService`, `ProductService`, `AppSettingsService`, `AiAssistantService`, `HashtagService`, `StorageService`)
- **Messaging & Checkout**: WhatsApp Deep Link Gateway (`wa.me`) dengan penyertaan foto produk otomatis
- **Target Platform**: Web (Desktop & Mobile Browser), Android, iOS, Windows Desktop

