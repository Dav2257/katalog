-- ==============================================================================
-- SKRIP SETUP SUPABASE: TABEL PRODUK & KEBIJAKAN ROW LEVEL SECURITY (RLS)
-- ==============================================================================
-- Cara Menjalankan:
-- 1. Buka dashboard Supabase Anda: https://supabase.com/dashboard/project/yakrixngwazvoriwuzoe
-- 2. Pilih menu "SQL Editor" di bilah samping kiri.
-- 3. Klik "New query", tempelkan (paste) seluruh skrip di bawah ini, lalu klik "Run".
-- ==============================================================================

-- 1. Buat Tabel Produk Sangkar
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

-- 2. Aktifkan Row Level Security (RLS)
ALTER TABLE public.produk ENABLE ROW LEVEL SECURITY;

-- 3. Buat Kebijakan Akses (RLS Policies)
DROP POLICY IF EXISTS "Publik dapat melihat produk" ON public.produk;
CREATE POLICY "Publik dapat melihat produk" 
ON public.produk FOR SELECT 
USING (true);

DROP POLICY IF EXISTS "Akses tambah produk" ON public.produk;
CREATE POLICY "Akses tambah produk" 
ON public.produk FOR INSERT 
WITH CHECK (true);

DROP POLICY IF EXISTS "Akses ubah produk" ON public.produk;
CREATE POLICY "Akses ubah produk" 
ON public.produk FOR UPDATE 
USING (true);

DROP POLICY IF EXISTS "Akses hapus produk" ON public.produk;
CREATE POLICY "Akses hapus produk" 
ON public.produk FOR DELETE 
USING (true);

-- 4. Beri izin hak akses tabel ke role anon dan authenticated
GRANT ALL ON TABLE public.produk TO anon, authenticated;
