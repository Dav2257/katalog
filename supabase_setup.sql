-- ==============================================================================
-- SKRIP LENGKAP & BERSIH SUPABASE (ANTI ERROR)
-- ==============================================================================
-- Cara Menjalankan:
-- 1. Buka SQL Editor di Supabase: https://supabase.com/dashboard/project/yakrixngwazvoriwuzoe
-- 2. Buat "New query", HAPUS semua teks yang ada di editor, lalu tempelkan skrip ini.
-- 3. Klik tombol hijau "Run".
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. TABEL PRODUK KATALOG UMUM
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.produk (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    kode VARCHAR(50),
    nama VARCHAR(255) NOT NULL,
    harga BIGINT NOT NULL DEFAULT 0,
    deskripsi TEXT,
    gambar_url TEXT,
    kategori VARCHAR(255),
    hashtags TEXT,
    rating NUMERIC(3, 2) DEFAULT 4.8,
    stok INT NOT NULL DEFAULT 10,
    variasi JSONB,
    last_edited_date VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.produk ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Akses penuh produk" ON public.produk;
CREATE POLICY "Akses penuh produk" ON public.produk FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.produk TO anon, authenticated;


-- ------------------------------------------------------------------------------
-- 2. TABEL USER PRIVATE (Akun Member & Jumlah Logo Custom)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_private (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(255) DEFAULT '',
    phone VARCHAR(50),
    email VARCHAR(255),
    password VARCHAR(255) NOT NULL,
    join_date VARCHAR(50),
    jumlah_logo_custom INT DEFAULT 0,
    request_count INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE IF EXISTS public.user_private ADD COLUMN IF NOT EXISTS name VARCHAR(255) DEFAULT '';
ALTER TABLE IF EXISTS public.user_private ADD COLUMN IF NOT EXISTS jumlah_logo_custom INT DEFAULT 0;
ALTER TABLE IF EXISTS public.user_private ADD COLUMN IF NOT EXISTS request_count INT DEFAULT 0;

ALTER TABLE public.user_private ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Akses penuh user private" ON public.user_private;
CREATE POLICY "Akses penuh user private" ON public.user_private FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.user_private TO anon, authenticated;


-- ------------------------------------------------------------------------------
-- 3. TABEL PRODUK CUSTOM PRIBADI MILIK USER
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.produk_custom (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_identifier VARCHAR(255) NOT NULL,
    kode VARCHAR(50),
    nama VARCHAR(255) NOT NULL,
    harga BIGINT NOT NULL DEFAULT 0,
    deskripsi TEXT,
    gambar_url TEXT,
    kategori VARCHAR(255) DEFAULT '#LogoCustomPribadi',
    variasi JSONB,
    last_edited_date VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.produk_custom ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Akses penuh produk custom" ON public.produk_custom;
CREATE POLICY "Akses penuh produk custom" ON public.produk_custom FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.produk_custom TO anon, authenticated;


-- ------------------------------------------------------------------------------
-- 4. TABEL PESANAN (Pesanan Masuk & Riwayat Pesanan Selesai)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pesanan (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    phone VARCHAR(50) NOT NULL,
    customer_name VARCHAR(255) DEFAULT '',
    email VARCHAR(255),
    order_date VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Tahap 1',
    stage_number INT NOT NULL DEFAULT 1,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    total_amount BIGINT NOT NULL DEFAULT 0,
    items JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE IF EXISTS public.pesanan ADD COLUMN IF NOT EXISTS customer_name VARCHAR(255) DEFAULT '';

ALTER TABLE public.pesanan ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Akses penuh pesanan" ON public.pesanan;
CREATE POLICY "Akses penuh pesanan" ON public.pesanan FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.pesanan TO anon, authenticated;


-- ------------------------------------------------------------------------------
-- 5. TABEL PENGATURAN GLOBAL TOKO / APLIKASI (Logo, Banner, Login Wallpaper, WA, Akun)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_settings (
    id VARCHAR(50) PRIMARY KEY DEFAULT 'global_settings',
    settings_json JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Akses penuh app_settings" ON public.app_settings;
CREATE POLICY "Akses penuh app_settings" ON public.app_settings FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.app_settings TO anon, authenticated;


-- ------------------------------------------------------------------------------
-- 6. SUPABASE STORAGE BUCKET & POLICIES (Bucket 'katalog' untuk Gambar & JSON)
-- ------------------------------------------------------------------------------
-- 1. Buat bucket 'katalog' jika belum ada dan pastikan publik
INSERT INTO storage.buckets (id, name, public)
VALUES ('katalog', 'katalog', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Kebijakan RLS storage.objects agar publik/anon bisa melihat, mengunggah, memperbarui, & menghapus
DROP POLICY IF EXISTS "Public Access Katalog Storage" ON storage.objects;
CREATE POLICY "Public Access Katalog Storage" ON storage.objects
FOR ALL USING (bucket_id = 'katalog') WITH CHECK (bucket_id = 'katalog');


-- ------------------------------------------------------------------------------
-- 7. TABEL BENTUK SANGKAR (Variasi Bentuk Sangkar di Dashboard Admin)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bentuk_sangkar (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.bentuk_sangkar ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Akses penuh bentuk_sangkar" ON public.bentuk_sangkar;
CREATE POLICY "Akses penuh bentuk_sangkar" ON public.bentuk_sangkar FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.bentuk_sangkar TO anon, authenticated;


-- ------------------------------------------------------------------------------
-- 8. TABEL HASHTAGS (Database Hashtag untuk Auto-Complete Produk Admin)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hashtags (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    use_count INT DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.hashtags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Akses penuh hashtags" ON public.hashtags;
CREATE POLICY "Akses penuh hashtags" ON public.hashtags FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON TABLE public.hashtags TO anon, authenticated;

-- Masukkan hashtag awal default Jatimas Sangkar (jika belum ada)
INSERT INTO public.hashtags (name)
VALUES
    ('#sangkar'),
    ('#jati'),
    ('#jepara'),
    ('#ukir'),
    ('#cungkok'),
    ('#kacer'),
    ('#murai'),
    ('#kenari'),
    ('#pleci'),
    ('#kosan'),
    ('#replika'),
    ('#finishing'),
    ('#natural'),
    ('#mentahan'),
    ('#kayu'),
    ('#bambu'),
    ('#serdadu'),
    ('#carbon')
ON CONFLICT (name) DO NOTHING;


