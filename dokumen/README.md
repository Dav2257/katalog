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
    └── skema_database.md          # Struktur 4 tabel inti (produk, produk_custom, user_private, pesanan), Storage, & RLS
```

---

## 📌 Ringkasan Bagian Dokumen

| Kategori | Deskripsi | Tautan |
| :--- | :--- | :--- |
| **Planing** | Rencana proyek, ruang lingkup, target pengguna, kebutuhan fungsional (FR-01 s/d FR-22) & non-fungsional, alur pengguna, serta roadmap rilis. | [Lihat Dokumen Planing](./planing/README.md) |
| **Frontend** | Arsitektur aplikasi Flutter, rincian seluruh halaman (`AdminDashboardPage`, `AdminOrderDetailPage`, `AdminCompletedOrderDetailPage`, `AdminUserDetailPage`, `AdminSettingsPage`, `UserHomePage`, `CartPage`), service layer (`AuthService`, `CageService`, `OrderService`, `ProductService`, `AppSettingsService`), komponen (`widgets`), dan manajemen state. | [Lihat Dokumen Frontend](./frontend/README.md) |
| **Backend** | Integrasi Backend-as-a-Service (BaaS) Supabase, konfigurasi URL & API Key, skema 4 tabel inti PostgreSQL (`produk`, `produk_custom`, `user_private`, `pesanan`), Supabase Storage (`katalog`), dan aturan keamanan (RLS). | [Lihat Dokumen Backend](./backend/README.md) |

---

## 🛠️ Stack Teknologi & Infrastruktur

- **Frontend Framework**: [Flutter SDK](https://flutter.dev/) (Dart `>= 3.11.4`)
- **Backend & Database**: [Supabase](https://supabase.com/) (PostgreSQL 4 Tabel Inti + JSONB, Supabase Auth, Storage)
- **Web Hosting**: [Firebase Hosting](https://firebase.google.com/) (`firebase.json` -> `build/web`)
- **State & Service Layer**: Modular Service Pattern (`ChangeNotifier`, `AuthService`, `CageService`, `OrderService`, `ProductService`, `AppSettingsService`)
- **Messaging & Checkout**: WhatsApp Deep Link Gateway (`wa.me`) dengan penyertaan foto produk otomatis
- **Target Platform**: Android, iOS, Web (Chrome, Edge), Windows Desktop
