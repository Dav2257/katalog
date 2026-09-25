# 🎨 Arsitektur Antarmuka & Komponen UI (Frontend)

Dokumen ini mendokumentasikan secara rinci komponen-komponen antarmuka pengguna (UI), hierarki halaman, interaksi widget, dan service layer dalam aplikasi **Katalog**.

---

## 1. 📑 Rincian Halaman (Pages)

### A. `lib/main.dart` (`MyHomePage`) & `UserHomePage`
- **Tanggung Jawab**: Menampilkan katalog utama produk untuk publik/tamu, search bar dinamis, grid produk sangkar, dan routing cerdas berdasarkan role autentikasi.
- **Fitur Utama**:
  - **Latar Belakang Warna Krem Hangat (*Warm Cream / Ivory* - `#F8F4EA`)**: Warna background resmi aplikasi yang menyatukan katalog umum dan katalog khusus dalam nuansa hangat, elegan, dan harmonis dengan kerajinan kayu jati (*teak wood*).
  - **Top Navigation Bar Responsif & Penyesuaian Mobile**:
    - *Desktop / Tablet*: Dilengkapi emblem logo Jatimas Sangkar, pencarian instan, tombol badge angka belanjaan pada ikon keranjang, dan tombol profil/login.
    - *Mobile (< 768px)*: Ikon keranjang dan tombol profil di Top Navbar disembunyikan agar search bar dapat melebar secara penuh dan nyaman digunakan tanpa memicu overflow.
  - **Footer Navigasi Bawah Layar Mobile (`_buildMobileFooterNavigation`)**:
    - Hadir otomatis pada perangkat mobile di bagian bawah layar (`bottomNavigationBar`) dengan latar belakang cokelat gelap kayu jati (`#2C1A0E`), bayangan lembut, dan border atas emas (`#D4AF37`).
    - **Keranjang (Kiri)**: Ikon keranjang belanja dilengkapi badge merah jumlah item belanjaan aktif (`Badge.count`).
    - **Beranda (Tengah)**: Tombol lingkaran kuning emas (`#FFDF00` - `#D4AF37`) dengan ikon rumah cokelat (`Icons.home_rounded`) yang membawa pengguna kembali ke katalog beranda.
    - **Profil (Kanan)**: Ikon profil yang menampilkan avatar pengguna/admin dan membuka modal sheet login/profil secara instan.
  - **Hero Banner Universal**: Banner visual utama (`HeroBanner`) kini selalu tampil penuh di bagian atas katalog bagi seluruh tipe pengunjung (pengguna umum, member private, maupun admin yang sedang melakukan pratinjau katalog standar).
  - **Tombol Navigasi Kembali di Bawah Banner (Sebelah Kanan)**: Saat admin atau member beralih melihat katalog standar, tombol navigasi kembali (*"Kembali ke Dashboard Admin"* atau *"Kembali ke Katalog Custom Saya"*) ditempatkan rapi di bawah banner dan di atas katalog di sebelah kanan dengan tombol cokelat kayu jati berikon panah emas.
  - **Grid Katalog Produk Seragam**: Ukuran kartu produk (katalog 1 s/d 5) diseragamkan tinggi dan rasio gambarnya dengan kartu berwarna putih di atas kanvas krem.
  - **Search Filter Dinamis**: Menyaring produk berdasarkan kecocokan nama dan kategori secara instan.
  - **Transisi Halaman Instan**: Seluruh perpindahan halaman diatur tanpa animasi transisi (instant transition) untuk pengalaman navigasi yang cepat dan responsif.

### B. `lib/pages/admin_dashboard_page.dart` (`AdminDashboardPage`)
- **Tanggung Jawab**: Pusat kendali operasional terpadu bagi administrator (`Admin 1` / `admin@gmail.com`).
- **Fitur Utama**:
  - **Sidebar Navigasi Kayu Jati (Desktop)**:
    - Berwarna cokelat kayu jati pekat (`#382314`), lebar 220px dengan aksen emas (`#D4AF37`).
    - Logo emblem diperbesar (**62 × 62 px**) dengan border emas 2.0px dan tipografi *JATIMAS SANGKAR* serta badge *ADMIN PANEL*.
    - Menu aktif berlatar belakang kontras, serta tombol "Preview Umum" dan "Keluar" (Logout).
  - **Header & Navigasi Mobile Bersih Tanpa Hamburger (`_buildMobileAdminFooterNavigation`)**:
    - **Header Bersih**: Pada layar mobile, AppBar hanya menampilkan teks judul "Dashboard Admin" dengan latar cokelat jati (`#382314`). Tombol menu hamburger `☰` (`automaticallyImplyLeading: false`) serta seluruh ikon profil di header dihilangkan untuk tampilan yang bersih, fokus, dan profesional.
    - **Footer Navigasi Admin Mobile**: Seluruh akses penting dialihkan ke footer navigasi bawah layar:
      1. *Setting (Kiri)*: Ikon gear pengaturan (`Icons.settings_rounded`) membuka halaman `AdminSettingsPage`.
      2. *Preview Umum (Tengah)*: Tombol lingkaran kuning emas dengan ikon etalase toko (`Icons.storefront_rounded`) untuk beralih instan ke mode pratinjau katalog publik.
      3. *Profil (Kanan)*: Ikon profil admin yang membuka dialog pop-up profil dan opsi keluar (logout).
  - **Analisis Data Metrik (Strict 2 Rows x 3 Columns)**:
    - **Baris 1**: `JUMLAH DESIGN PRODUK` (1.200), `JUMLAH PESANAN` (259), `JUMLAH DESIGN REQUEST` (12).
    - **Baris 2**: `JUMLAH BENTUK SANGKAR` (terhubung dinamis ke `CageService.cages.length`), `JUMLAH PESANAN BARU` (2), kolom ke-3 sengaja dikosongkan untuk keseimbangan tata letak visual.
    - Setiap kartu metrik memiliki garis penanda vertikal cokelat jati (`#8B5328`), tinggi 112px, dan angka tebal berukuran font 36.
  - **Tabel Pesanan Masuk (Full-Width Responsive Table)**:
    - Mengadopsi arsitektur responsif `LayoutBuilder` dengan perhitungan jarak kolom dinamis (`dynamicSpacing`) dan `minTableWidth`. Pada layar desktop lebar, tabel otomatis membentang mengisi 100% lebar kartu putih tanpa menyisakan ruang kosong di kanan dan tanpa memotong tombol *Action*.
    - Pada perangkat mobile/tablet, tabel mempertahankan tata letak yang proporsional dengan scrolling horizontal (`SingleChildScrollView` + `Scrollbar`) tanpa error overflow.
    - Memuat 8 kolom lengkap: *No.*, *Nama* (nama pemesan), *Nomor Telp.*, *Tgl Pesanan*, *Jumlah Pesanan*, *Kode Produk*, *Status*, dan *Action* (tombol Detail cokelat jati).
  - **Tabel User Private (Full-Width Responsive Table)**:
    - Menampung akun pelanggan member eksklusif (*User Private*).
    - Berbasis `LayoutBuilder` dinamis yang menyesuaikan diri dengan lebar layar secara proporsional.
    - Memuat 8 kolom lengkap: *No.*, *Nama* (nama lengkap member), *No. Telp*, *Email*, *Password*, *Tgl Masuk*, *Jumlah Logo Custom*, dan *Action* (tombol Detail profil).
  - **Tabel Riwayat Pesanan Selesai (Full-Width Responsive Table)**:
    - Menampilkan seluruh pesanan yang telah rampung dengan layout responsif dinamis penuh, memuat kolom *No.*, *Nomor Telp.*, *Tgl Pesanan*, *Jumlah Pesanan*, *Kode Produk*, *Status*, dan *Action*.
  - **Section "List Produk User Umum" & Paginasi Responsif**:
    - Menampilkan katalog produk yang sedang tayang di sisi publik.
    - Header pencarian "Cari berdasarkan:" dengan tombol pill pilihan `Nama` (cokelat aktif) dan `Kode` (abu-abu), serta dua kolom input filter real-time (`.....` dan `...`).
    - Grid kartu produk berisi gambar thumbnail proporsional, nama produk (contoh: `A01-Batman Swing biru cantik`), dan tag produk (`#superhero #batman #DC`).
    - **Paginasi Ramah Mobile**: Tombol navigasi halaman ("Sebelumnya" dan "Selanjutnya") dirancang dengan tata letak fleksibel tanpa memicu overflow pixel pada smartphone.
  - **Section "Sangkar" (Manajemen Varian Bentuk Sangkar Mandiri Database)**:
    - Terhubung langsung secara mandiri baris per baris ke tabel PostgreSQL `public.bentuk_sangkar` di Supabase.
    - **Data Bersih & Bebas Duplikat**: Database telah dibersihkan dari 8 item dummy lama dan duplikasi nama; hanya memuat 4 bentuk sangkar riil: "Replika", "Kosan standard", "Kosan Ceper", dan "Tebok".
    - **Penghapusan Cloud Terjamin (`await`)**: Fitur `removeCage` menunggu konfirmasi penghapusan cloud Supabase secara tuntas sehingga data yang dihapus tidak akan muncul kembali saat halaman direfresh.
    - **Navigasi Multi-Input Lengkap**: Tombol panah navigasi `<` dan `>`, scroll roda mouse horizontal, mouse drag, dan scrollbar horizontal khusus.
    - **Tombol "Tambah Sangkar" Cepat**: Terletak di sudut kanan bawah section untuk mendaftarkan variasi sangkar baru langsung ke cloud.

### C. `lib/pages/product_detail_page.dart` (`ProductDetailPage`)
- **Tanggung Jawab**: Menyajikan detail lengkap mengenai sangkar burung yang dipilih pengguna dan konfigurasi pemesanan kustom.
- **Fitur Utama**:
  - **Viewer Gambar Fullscreen Interaktif (`ProductFullscreenViewer`)**:
    - Mengklik atau mengetuk gambar foto produk utama maupun foto varian bentuk sangkar (baik di layar HP maupun laptop/PC) secara instan membuka dialog viewer layar penuh dengan latar belakang hitam elegan (`Colors.black.withValues(alpha: 0.94)`).
    - **Fitur Zoom & Geser Multi-Input**: Mendukung *pinch-to-zoom*, *double-tap zoom*, *mouse drag*, *mouse wheel zoom*, dan pan interaktif via `InteractiveViewer` & `TransformationController`.
    - **Navigasi Slide Lengkap**: Tombol panah kiri `<` dan kanan `>`, swipe gesture sentuhan di HP, indikator nomor slide (`1 / N`), nama bentuk sangkar di bar atas, serta tombol tutup `X` dan tombol keyboard Escape.
  - **Tampilan Visual Produk Presisi & Minimalis**:
    - Kotak foto utama berukuran **tinggi 350 px**, warna latar abu-abu halus (`#B0B0B0`), kelengkungan sudut **`borderRadius: 18`**, dan bayangan lembut.
    - Menggunakan properti **`fit: BoxFit.contain`** dan `Product.buildImageFromSource` sehingga logo/artwork persegi (seperti *Es Durian Shake*), landscape, maupun portrait **tampil 100% utuh tanpa terpotong (no-crop)**.
    - Tampilan bersih tanpa kotak thumbnail duplikat di samping sangkar (nama/label langsung fokus pada variasi).
    - **Peniadaan Ikon Bintang Rating**: Ikon bintang rating review dihilangkan demi antarmuka yang bersih, profesional, dan fokus pada keindahan ukiran serta spesifikasi sangkar.
  - **Navigasi Bentuk Sangkar dengan Tombol Next & Previous**: Dilengkapi tombol panah kiri (`<`) dan kanan (`>`) di samping deretan bentuk sangkar dinamis dari `CageService`.
  - **Dukungan Foto Sangkar Spesifik per Produk**: Setiap produk dapat memiliki foto sangkar yang berbeda-beda untuk variasi ukuran yang sama (disimpan pada kolom `variasi` di data produk).
  - **Counter Kuantitas per Bentuk**: Tombol `+` dan `-` kuantitas yang tersimpan secara terpisah untuk setiap bentuk sangkar.
  - **Catatan Dinamis per Bentuk**: Kolom catatan (*note*) berada di posisi yang konsisten, namun isi teks note dan batasan kata tersimpan secara independen untuk setiap bentuk sangkar yang dipilih.
  - **Tombol Keranjang**: Menambahkan pesanan setiap bentuk sangkar yang memiliki kuantitas > 0 ke keranjang belanja secara terpisah.


### D. `lib/pages/cart_page.dart` (`CartPage`)
- **Tanggung Jawab**: Menampilkan daftar barang pesanan pembeli, seleksi item, kalkulasi harga, checkout WhatsApp dengan tautan foto produk, dan pelacakan pesanan.
- **Fitur Utama**:
  - **Bagian "Pesanan Anda" (Eksklusif Akun Member Login)**:
    - Khusus ditampilkan jika pengguna berstatus login sebagai Member.
    - Menampilkan daftar pesanan berjalan dari `OrderService` lengkap dengan status tahapan pengerjaan (*Tahap 1 Verifikasi & Desain* s/d *Tahap 4 Perakitan & Finishing*), nomor invoice, dan rincian item.
    - **Terisolasi dari Pengguna Tamu**: Bagian ini otomatis disembunyikan jika pengunjung adalah tamu/umum (guest).
  - **Formulir Identifikasi Pemesan & Auto-Fill Member**:
    - **Pengguna Umum (Guest)**: Dialog konfirmasi checkout mewajibkan input **Nama Pemesan** dan **Nomor WhatsApp** agar pesanan di Admin Dashboard dapat langsung dikenali pemiliknya.
    - **Pengguna Member (User Private)**: Sistem otomatis menarik dan mengisi data **Nama** dan **Nomor WhatsApp** dari database profil member (`user_private`) secara instan (*read-only / auto-fill*), mencegah salah kirim dan mempercepat checkout.
  - **Pemisahan Item per Bentuk Sangkar**: Pesanan dengan bentuk sangkar berbeda otomatis dipisahkan menjadi kartu item tersendiri dengan badge `Bentuk: Sangkar X`.
  - **Kotak Catatan Khusus**: Menampilkan catatan kustom yang telah diinput pengguna pada masing-masing item.
  - **Penghapusan Responsif & Pembersihan Jejak Pesanan**: Tombol hapus ikon tempat sampah pada tiap item bekerja instan. Saat keranjang kosong, seluruh state pemesanan direset bersih.
  - **Checkbox Seleksi Item & Pilih Semua**: Pengguna dapat mencentang item tertentu yang ingin dibeli atau menggunakan tombol "Pilih Semua".
  - **Tombol Hapus Semua Dinamis**: Tombol "Hapus Semua" hanya muncul jika terdapat item yang dicentang.
  - **Dialog Konfirmasi Pesanan Berfoto**: Pop-up konfirmasi pesanan menampilkan thumbnail foto produk, rincian kuantitas, catatan, dan verifikasi kontak pemesan.
  - **Tombol Pesan WhatsApp Resmi di Kanan Bawah**:
    - Tombol berwarna hijau resmi WhatsApp (`#25D366`) berpadu dengan **Logo Resmi WhatsApp** (`WhatsAppLogo`).
    - **Otomatis Menyertakan Foto Produk**: Pesan WhatsApp yang dibuat via `AppSettingsService.createOrderWhatsAppUri` menyematkan nama pemesan, nama produk, kuantitas, catatan, dan **URL foto produk** (`📸 Foto Produk: https://...`) yang memicu *rich link preview* gambar di aplikasi WhatsApp.
    - Mengarahkan pesanan langsung ke nomor WhatsApp Admin yang dikonfigurasi.

### E. `lib/pages/login_page.dart` (`LoginPage`)
- **Tanggung Jawab**: Formulir autentikasi pengguna dengan pemisahan akun member dan administrator serta registrasi member baru.
- **Fitur Utama**:
  - Latar belakang foto sangkar di taman alam berpadu gradien zaitun-cokelat gelap elegan.
  - Header brand `JATIMAS SANGKAR` kuning emas.
  - **Registrasi Member Baru Lengkap**: Mode pendaftaran akun private menyediakan input **Nama Lengkap**, **Nomor WhatsApp/Telepon**, **Email**, dan **Password**, yang langsung tersinkronisasi ke tabel `public.user_private`.
  - Input Email dan Password dengan visibilitas toggle.
  - Tombol Masuk Supabase Auth.
  - Tombol Masuk Cepat (Mode Demo) & Dukungan Akun Admin (`admin@gmail.com`).

### F. `lib/pages/user_home_page.dart` (`UserHomePage`)
- **Tanggung Jawab**: Halaman beranda khusus untuk pengguna yang telah login (Member Jatimas Sangkar).
- **Fitur Utama**:
  - **Latar Belakang Warna Krem (*#F8F4EA*)**: Memiliki background krem yang seragam dengan katalog umum sehingga visual aplikasi terasa selaras dan menenangkan.
  - **Pemisahan Data Total**: Keranjang belanja dan katalog member dipisahkan 100% dari pengguna tamu (guest).
  - **Banner Penuh dengan Tombol "Katalog Umum" Menimpa (*Overlay*)**: Mengadopsi komponen `HeroBanner` yang sama persis dengan katalog umum. Di sudut kanan atas banner disematkan tombol *"Katalog Umum"* dengan gaya dark-glass semi-transparan (`Colors.black.withValues(alpha: 0.5)`) dan border putih tipis sehingga tetap kontras dan mudah diklik di atas gambar banner apa pun.
  - **Tombol "Permintaan Logo Custom" di Atas Katalog (Sebelah Kanan)**: Tombol aksi utama berwarna kuning emas (`#FFD900`) diletakkan di atas daftar katalog logo custom sebelah kanan (sejajar dengan judul pada desktop/tablet, dan rata kanan pada mobile).
  - **Form Request dengan Fitur Insert Gambar**: Menginput gambar referensi desain kustom pelanggan langsung dari galeri/file lokal yang otomatis diunggah ke cloud storage.
  - **Katalog Beranda Khusus Logo Custom**: Grid kartu logo custom berlatar putih dengan border aksen amber halus di atas kanvas krem.

### G. `lib/pages/admin_order_detail_page.dart` (`AdminOrderDetailPage`)
- **Tanggung Jawab**: Menampilkan dan mengelola rincian pesanan masuk yang dibuat oleh pelanggan.
- **Fitur Utama**:
  - **Info Kontak & Direct WhatsApp**: Menampilkan nomor telepon pemesan beserta tombol "Hubungi WhatsApp" langsung (`https://wa.me/...`).
  - **Daftar Produk Pesanan**: Menampilkan kartu produk lengkap dengan foto thumbnail, nama variasi sangkar, kuantitas, dan catatan khusus dari pembeli.
  - **Kontrol 4 Tahapan Produksi**: Pilihan radio interaktif untuk 4 tahapan pengerjaan (*Tahap 1: Verifikasi & Desain*, *Tahap 2: Pemilihan Kayu Jati*, *Tahap 3: Proses Ukir & Grafir*, *Tahap 4: Perakitan & Finishing*).
  - **Tombol "Simpan Perubahan" & "Selesaikan Pesanan"**: Menyimpan progres pesanan ke `OrderService` atau memindahkan pesanan ke riwayat pesanan selesai.

### H. `lib/pages/admin_completed_order_detail_page.dart` (`AdminCompletedOrderDetailPage`)
- **Tanggung Jawab**: Menampilkan rincian pesanan yang telah diselesaikan (*Riwayat Pesanan*).
- **Fitur Utama**:
  - Menampilkan nomor pesanan, tanggal penyelesaian, nomor kontak pembeli, dan tombol hubungi WhatsApp.
  - Daftar produk dan spesifikasi bentuk sangkar yang telah diselesaikan.
  - Badge visual status hijau bertuliskan "Selesai".

### I. `lib/pages/admin_user_detail_page.dart` (`AdminUserDetailPage`)
- **Tanggung Jawab**: Menampilkan profil lengkap pelanggan private (*Member*) dan mengelola hasil editan gambar logo custom.
- **Fitur Utama**:
  - Informasi kredensial pengguna (nama, email, no HP/WhatsApp, alamat).
  - **Fokus Sunting Gambar Desain User (Tanpa Tambah Manual)**: Admin murni hanya meninjau dan mengedit gambar/desain yang sudah diunggah oleh user private via `AdminEditProductPage`, tanpa adanya tombol penambahan manual di sisi admin (*read & edit only*).
  - Menampilkan daftar logo custom pribadi pengguna dengan pratinjau kartu interaktif.

### J. `lib/pages/admin_add_product_page.dart` & `admin_edit_product_page.dart`
- **Tanggung Jawab**: Menambah produk baru ke katalog publik atau menyunting detail produk yang sudah ada.
- **Fitur Utama**:
  - Input nama produk, kategori, harga, kode produk, tagar (#), dan URL gambar.
  - **Auto-Complete Tagar Terpusat**: Menggunakan `HashtagAutocompleteField` yang terhubung dengan `HashtagService`. Saat admin mengetik tanda pagar `#` atau kata kunci tagar, sistem menampilkan daftar rekomendasi tagar dari database terpusat (`public.hashtags`), memanen tagar baru secara otomatis, dan menghindarkan pengetikan berulang.
  - **Sinkronisasi Bentuk Sangkar**: Mengintegrasikan pilihan variasi bentuk sangkar (`ProductCageVariation`) dengan foto kustom yang tersinkronisasi dua arah ke `CageService`.

### K. `lib/pages/admin_settings_page.dart` (`AdminSettingsPage`)
- **Tanggung Jawab**: Pusat pengaturan konfigurasi toko dan tampilan katalog oleh Admin.
- **Fitur Utama**:
  - **Nomor WhatsApp Tujuan Pesanan**: Mengatur nomor WhatsApp Admin penerima seluruh pesanan publik dan member.
  - **Banner Katalog Kustom**: Pilihan sampel banner siap pakai atau input URL gambar banner kustom.
  - **Layout Navbar**: Pilihan 3 variasi tata letak Top Navbar katalog umum (Style 1, Style 2, Style 3).
  - **Jenis Font Katalog**: Pilihan tipografi (`Times New Roman`, `Outfit`, `Poppins`, `Roboto`, `Playfair Display`).

### L. `lib/pages/schedule_production_page.dart` (`ScheduleProductionPage`)
- **Tanggung Jawab**: Manajemen jadwal proses produksi sangkar bertingkat enterprise dengan format antarmuka serbaguna ala Notion database yang meniru referensi `https://jatimas.beelink.web.id/`.
- **Fitur Utama**:
  - **5 Mode Tampilan (Multi-View Toolbar)**:
    1. **Bulanan**: Tampilan kalender grid bulanan lengkap dengan filter tanggal dan indikator status produksi.
    2. **Mingguan**: Tampilan kalender per pekan dengan slot waktu dan penjadwalan harian.
    3. **Gallery**: Grid kartu visual berukuran konsisten (300px) dengan cover foto produk, badge status warna, deskripsi, dan tanggal target.
    4. **Board (Kanban)**: Kolom alur status vertikal (*Direncanakan*, *Proses Produksi*, *Finishing*, *Selesai*) dengan drag/klik pemindahan status.
    5. **Table**: Tabel data terstruktur dengan kolom Foto, Judul Tugas, Kategori, Target Selesai, Status, Catatan, dan Tombol Aksi Cepat.
  - **Tata Letak Rata Kiri Konsisten**: Menggunakan `crossAxisAlignment: CrossAxisAlignment.stretch`, container full-width (`width: double.infinity`), dan pembungkus `Align(alignment: Alignment.topLeft)` pada seluruh view sehingga kartu dan baris data tersusun rapi dari sisi kiri layar ke kanan tanpa ada tampilan yang memusat canggung ke tengah.
  - **Upload Gambar Perangkat (Laptop & HP)**: Admin dapat memilih file foto langsung dari galeri smartphone atau file browser komputer via `image_picker` yang otomatis diunggah ke Supabase Storage via `StorageService` (dengan fallback aman Base64 Data URI).
  - **Pratinjau Gambar Real-Time & Validasi Wajib**: Menyediakan kartu preview foto interaktif dengan tombol hapus/ganti. Foto jadwal produksi bersifat **wajib (mandatory)**; form modal secara ketat menolak penyimpanan jika foto belum diunggah atau URL kosong.
  - **Universal Image Renderer**: Didukung `buildScheduleImage` di `schedule_image_helper.dart` yang secara tangguh menangani Supabase Storage URL, Web HTTP/HTTPS, Base64 Data URI, maupun Asset Image lokal.

### M. `lib/widgets/ai_assistant_dialog.dart` (`AiAssistantDialog`)
- **Tanggung Jawab**: Dialog percakapan asisten kecerdasan buatan (AI) interaktif multi-modal (suara & teks) yang membantu pelanggan menemukan produk sangkar yang tepat, mengenali preferensi warna & motif, menampilkan kartu produk visual, serta menyediakan form pemesanan cepat langsung ke WhatsApp.
- **Fitur Utama**:
  - **Mode Tampilan Adaptif Multi-Perangkat**:
    - *Mobile (< 700px)*: Tampil sebagai BottomSheet geser responsif dari bawah layar dengan handling keyboard dinamis (`viewInsets.bottom`).
    - *Desktop / Tablet (> 700px)*: Tampil sebagai dialog pop-up elegan dengan sudut melengkung 24px (`maxWidth: 580, maxHeight: 720`), bayangan lembut, dan tata letak terpusat.
  - **Interaksi Suara (Voice-to-Text & Text-to-Speech)**:
    - Dilengkapi fitur pengenalan suara (`speech_to_text`) via mikrofon perangkat dengan animasi gelombang suara saat mendengarkan.
    - Pembacaan respons AI otomatis bersuara menggunakan `flutter_tts` dengan toggle suara aktif/nonaktif.
  - **Injeksi Data Produk Katalog Real-time & Deteksi Warna Motif**:
    - Menghubungkan konteks percakapan ke seluruh data produk aktif dari `ProductService` (kode, nama, harga, variasi bentuk sangkar, dan warna motif ukiran).
    - **Pengenalan Warna Motif Cerdas**: AI secara otomatis mengenali preferensi warna yang disebut pengguna (contoh: motif naga biru, ukiran emas, merah, hitam, kayu jati natural) dan memetakan langsung ke produk katalog yang sesuai.
  - **Kartu Rekomendasi Visual Produk (`_buildProductCard`)**:
    - Menggantikan tampilan teks daftar bernomor polos dengan kartu visual produk yang interaktif dan kaya informasi.
    - Menampilkan foto asli produk dari katalog, kode produk (contoh: `[A05]`), nama produk, badge harga format Rupiah (`Rp ...`), dan penjelasan alasan rekomendasi.
    - **Aksi Langsung Interaktif pada Kartu**:
      1. `[Pesan]`: Membuka BottomSheet formulir pemesanan cepat dengan data produk terisi otomatis.
      2. `[+ Keranjang]`: Langsung memasukkan produk ke keranjang belanja pengguna secara instan.
      3. `[Detail]`: Membuka halaman detail produk lengkap untuk melihat spesifikasi dan variasi bentuk sangkar.
  - **Proteksi Anti-Overflow Ekstrem**:
    - Tombol aksi kartu dibungkus dengan `FittedBox(fit: BoxFit.scaleDown)` sehingga teks tombol tidak pernah pecah atau terpotong pada layar ponsel sempit (< 400px).
    - Judul produk menggunakan `Flexible` dan baris harga menggunakan `Wrap` untuk menjamin tidak ada error pixel `RenderFlex overflowed`.
  - **Formulir Pemesanan Cepat AI (`_showOrderFormBottomSheet`)**:
    - Kartu ringkasan produk terpilih (foto, kode, nama, harga, jumlah pemesanan).
    - Field input: **Nama Pemesan**, **Nomor WhatsApp**, dan **Catatan Tambahan**.
    - **Aturan Bisnis Katalog Umum**: Menegaskan bahwa pelanggan umum hanya dapat memesan produk yang tersedia di katalog (tidak melayani pembuatan desain baru dari awal/scratch).
    - **Batasan Catatan Pemesanan**: Kolom catatan secara eksplisit difungsikan hanya jika pelanggan ingin menambahkan teks atau inisial kecil pada karakter produk yang dipilih (contoh: *"di samping karakternya ditambah tulisan GB"*).
    - **Bebas Alamat di Chat**: AI tidak menanyakan alamat pengiriman dalam sesi chat (alamat pengiriman ditangani saat checkout keranjang).
    - **Tombol Kirim Pesanan via WhatsApp**: Menyusun pesan WhatsApp berformat rapi dan langsung membuka deep link WhatsApp toko (`wa.me`).

---

## 2. 🧩 Lapisan Layanan Terpusat (Service Layer)

| Service | File | Peran & Tanggung Jawab |
| :--- | :--- | :--- |
| `AuthService` | `lib/services/auth_service.dart` | Mengelola status login, identitas pengguna, dan pemisahan role antara Tamu (*Guest*), Member (`davin@gmail.com`), dan Admin (`admin@gmail.com` / `Admin 1`). |
| `CageService` | `lib/services/cage_service.dart` | State manager berbasis `ChangeNotifier` yang mengelola variasi bentuk sangkar secara mandiri baris per baris ke tabel PostgreSQL `public.bentuk_sangkar`, cache offline instan `SharedPreferences`, dan cadangan storage. Database telah dibersihkan dari 8 item dummy lama dan duplikasi nama. Dilengkapi deduplikasi data saat fetch, serta `await` penghapusan Supabase cloud sehingga data yang dihapus tidak pernah muncul kembali saat refresh. |
| `OrderService` | `lib/services/order_service.dart` | Mengelola antrean pesanan masuk (`incomingOrders`), riwayat pesanan selesai (`completedOrders`), update 4 tahapan produksi custom, dan pelacakan pesanan aktif member di keranjang. |
| `ProductService` | `lib/services/product_service.dart` | Mengelola data katalog produk umum secara reaktif (`ChangeNotifier`), sinkronisasi tambah/edit produk admin ke katalog publik. |
| `AppSettingsService` | `lib/services/settings_service.dart` | Mengelola nomor WhatsApp tujuan pesanan (`adminWhatsApp`), banner kustom, style navbar (1-3), font katalog, konfigurasi AI Assistant toggle/model/API key, pembentukan link pesanan WhatsApp berfoto, serta penyedia logo terpadu (`buildLogoWidget`) yang dioptimasi dengan varian resolusi (1.0x, 2.0x, 3.0x), auto downsampling `cacheWidth`/`cacheHeight`, dan anti-aliasing `FilterQuality.medium`. |
| `AiAssistantService` | `lib/services/ai_assistant_service.dart` | Layanan AI interaktif berbasis LLM (OpenRouter Hermes 3 Llama-3.1 8B / fallback Groq Llama-3.3 70B), injeksi konteks katalog real-time, pencocokan warna motif, parsing kode produk regex cerdas, dan sinkronisasi ke keranjang & checkout WhatsApp. |
| `HashtagService` | `lib/services/hashtag_service.dart` | Mengelola kamus database tagar terpusat (`public.hashtags`), memfasilitasi pencarian auto-complete cerdas saat pengetikan produk di admin, cache memori instan, dan auto-harvesting tagar baru yang otomatis didaftarkan ke database. |
| `StorageService` | `lib/services/storage_service.dart` | Menangani proses upload berkas gambar dari memori/perangkat pengguna (Web, Windows, Android, iOS) ke bucket Supabase Storage (`products` / `katalog`) dengan pengembalian Public URL instan dan fallback Base64. |

---

## 3. 🧩 Komponen Reusable (Widgets)

| Widget | File | Fungsi & Penggunaan |
| :--- | :--- | :--- |
| `AiAssistantDialog` | `widgets/ai_assistant_dialog.dart` | Modal dialog asisten AI suara & teks, kartu visual rekomendasi produk dengan tombol aksi instan (`[Pesan]`, `[+ Keranjang]`, `[Detail]`), dan bottom sheet formulir pemesanan cepat langsung ke WhatsApp. |
| `FloatingActionButton Asisten AI` | `main.dart` | Tombol mengambang elegan di kanan bawah layar bertema kayu jati dan aksen lingkaran emas untuk memicu dialog asisten AI ("Coba" asisten cerdas). |
| `ProductFullscreenViewer` | `widgets/product_fullscreen_viewer.dart` | Viewer gambar layar penuh interaktif untuk foto produk dan bentuk sangkar. Mendukung navigasi PageView, gestur sentuh (pinch-to-zoom, double-tap zoom), mouse drag di web/desktop, scroll wheel zoom, keyboard escape/arrows, judul dinamis, dan indikator nomor slide. |
| `TopNavbar` | `widgets/top_navbar.dart` | Bilah navigasi atas yang memuat emblem logo lingkaran 44px bersanding dengan teks merek elegan `JATIMAS SANGKAR` (kombinasi putih tebal & kuning emas), search input dinamis, ikon keranjang belanja dengan badge counter, dan tombol profil/login. Pada mode mobile (< 768px), tombol keranjang dan profil disembunyikan agar search bar dapat tampil leluasa. |
| `MobileFooterNav` (`_buildMobileFooterNavigation`) | `main.dart` | Footer navigasi bawah layar khusus mobile untuk Katalog Umum & Member: Keranjang (kiri dengan badge), Beranda (tengah dengan tombol emas melingkar), dan Profil (kanan). |
| `AdminMobileFooterNav` (`_buildMobileAdminFooterNavigation`) | `pages/admin_dashboard_page.dart` | Footer navigasi bawah layar khusus mobile untuk Dashboard Admin: Setting Toko (kiri), Preview Umum (tengah dengan tombol emas marketplace), dan Profil Admin (kanan). |
| `HeroBanner` | `widgets/hero_banner.dart` | Banner visual di bagian atas halaman katalog untuk memperkuat identitas brand Jatimas Sangkar, mendukung gambar bawaan maupun banner kustom admin. |
| `HashtagAutocompleteField` | `widgets/hashtag_autocomplete_field.dart` | Input textfield cerdas dengan dropdown overlay dinamis untuk rekomendasi tagar otomatis (#kayujati, #sangkar, dll.) dengan sinkronisasi database terpusat. |
| `WhatsAppLogo` | `pages/cart_page.dart` | Komponen logo resmi WhatsApp berbasis Base64 memory image untuk tombol Pesan. |
| `WhatsAppIcon` | `pages/admin_order_detail_page.dart` | Komponen ikon WhatsApp presisi berbasis CustomPainter untuk tombol hubungi pembeli di halaman admin. |

---

## 4. 📐 Hierarki Tampilan & Navigasi (Navigation Graph)

```mermaid
graph TD
    A[MyHomePage - main.dart] -->|Status Tamu| A1[Katalog Standar Umum]
    A -->|Login Member| A2[UserHomePage - Beranda Member]
    A -->|Login Admin| AD[AdminDashboardPage - Dashboard Admin]
    
    %% Navigasi Mobile Footer Pengguna
    A1 -->|Footer Mobile: Tengah| A1
    A1 -->|Footer Mobile: Kiri| B[CartPage - Keranjang]
    A1 -->|Footer Mobile: Kanan| C[Modal Profil / LoginPage]
    
    %% Navigasi Mobile Footer Admin
    AD -->|Footer Mobile: Tengah| A1
    AD -->|Footer Mobile: Kiri| S1[AdminSettingsPage - WA, Font, Banner, Navbar]
    AD -->|Footer Mobile: Kanan| PADM[Dialog Profil Admin & Logout]
    
    AD -->|Tombol Preview Umum Desktop| A1
    A1 -->|Banner Kembali ke Dashboard| AD

    AD -->|Aksi Detail Pesanan| O1[AdminOrderDetailPage - Detail & 4 Tahap Produksi]
    O1 -->|Hubungi WA| WA1[Direct Chat WhatsApp Pembeli]
    O1 -->|Selesaikan Pesanan| O2[AdminCompletedOrderDetailPage - Riwayat Selesai]
    AD -->|Tab Riwayat Selesai| O2
    AD -->|Aksi Detail User Private| U1[AdminUserDetailPage - Profil & Desain Member]
    AD -->|Tambah Produk Baru| P1[AdminAddProductPage - Auto-Complete Hashtag]
    AD -->|Edit Produk Eksisting| P2[AdminEditProductPage - Auto-Complete Hashtag]
    AD -->|Menu Pengaturan Toko| S1

    A2 -->|Tombol Request| R[Modal Request: Insert Gambar Desain]
    A2 -->|Katalog Logo Custom Saya| D(ProductDetailPage: Navigasi Bentuk < >)
    A1 -->|Klik Card Produk Standar| D
    
    %% Fullscreen Viewer
    D -->|Klik Gambar Produk / Bentuk Sangkar| FS[ProductFullscreenViewer: Zoom & Slide Layar Penuh]
    FS -->|Tutup X / Swipe / Esc| D
    
    A -->|Klik Ikon Keranjang Desktop/Footer| B
    B -->|User Member| B1[Bagian: Pesanan Anda - Tracking Status]
    B -->|User Tamu / Member| B2[Daftar Item Keranjang Aktif]
    
    A -->|Klik Login / Profil| C
    D -->|Masuk Keranjang| B
    B2 -->|Dialog Konfirmasi Berfoto| CF[Dialog Konfirmasi Pesanan]
    CF -->|Kirim Pesanan| E[WhatsApp Gateway: wa.me + Link Foto Produk]

    %% Asisten AI Suara & Teks
    A1 -->|Floating Action Button: AI Asisten| AI[AiAssistantDialog: Suara & Teks]
    AI -->|Deteksi Warna & Motif| AIC[Kartu Visual Rekomendasi Produk]
    AIC -->|Tombol Detail| D
    AIC -->|Tombol + Keranjang| B2
    AIC -->|Tombol Pesan| OF[Order Form BottomSheet: Nama, WA, Catatan Tambahan]
    OF -->|Kirim Pesanan Langsung| E
```
