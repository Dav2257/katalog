# 🪵 Jatimas Sangkar - Katalog & Sistem Manajemen Pesanan

Aplikasi web & mobile katalog produk kerajinan sangkar burung kayu jati Jepara (**Jatimas Sangkar**) yang dilengkapi fitur pemesanan WhatsApp otomatis berfoto, asisten kecerdasan buatan (AI) suara & teks dengan kartu visual interaktif, pelacakan progres pengerjaan pesanan 4 tahap, katalog kustom member private, serta dashboard administrator terpadu.

🌐 **Akses Web Live**: [https://katalog-jatimas-2257.web.app](https://katalog-jatimas-2257.web.app)

---

## ✨ Fitur Unggulan
- **🤖 Asisten AI Suara & Teks Interaktif**: Pengenalan suara (`speech_to_text`), teks ketik, pembacaan suara AI (`flutter_tts`), ditenagai LLM Nous Hermes 3 Llama-3.1 8B & Groq Llama 3.3.
- **🖼️ Kartu Rekomendasi Visual Produk**: Kartu visual produk dengan foto asli dari katalog, kode produk, harga Rupiah, dan tombol aksi langsung: `[Pesan]`, `[+ Keranjang]`, dan `[Detail]`.
- **⚡ Quick Order Form AI**: BottomSheet pemesanan cepat dengan aturan khusus: pesanan hanya untuk produk katalog (tidak buat baru dari awal) dan catatan khusus inisial/teks kecil pada model yang dipilih, langsung terhubung ke WhatsApp.
- **📱 Responsif & Anti-Overflow**: Dioptimalkan bebas error pixel overflow (`FittedBox`, `Flexible`, `Wrap`) pada mobile (< 400px) dan desktop (> 700px).
- **🪵 Dashboard Administrator & Jadwal Produksi**: Analisis metrik real-time, manajemen bentuk sangkar relasional Supabase, jadwal produksi 5-view Notion-style, dan auto-complete tagar terpusat.

---

## 📚 Dokumentasi Lengkap Proyek
Seluruh dokumentasi perencanaan, arsitektur antarmuka, service layer, dan skema database cloud Supabase tersusun rapi di direktori [dokumen/](dokumen/README.md):
- [📄 Perencanaan & Spesifikasi Proyek (SRS)](dokumen/planing/README.md)
- [📱 Arsitektur Antarmuka & Frontend Flutter](dokumen/frontend/README.md)
- [🗄️ Skema Database & Layanan Cloud Supabase](dokumen/backend/README.md)

---

## 🚀 Menjalankan Proyek
```bash
# Instalasi dependensi
flutter pub get

# Jalankan di Chrome (Web)
flutter run -d chrome

# Build rilis Web
flutter build web --release

# Deploy ke Firebase Hosting
firebase deploy --only hosting
```
