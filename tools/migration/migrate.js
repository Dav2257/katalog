const { createClient } = require('@supabase/supabase-js');
const { Pool } = require('pg');
const { S3Client, PutObjectCommand, ListObjectsV2Command, HeadBucketCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');
const path = require('path');
const dotenv = require('dotenv');

// Load environment variables from .env
const envPath = path.resolve(__dirname, '../../.env');
dotenv.config({ path: envPath });

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://yakrixngwazvoriwuzoe.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlha3JpeG5nd2F6dm9yaXd1em9lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5MDM3MzMsImV4cCI6MjEwNDQ3OTczM30.8hLICjab92RWriaPJeut35GbtVglkcF5ge2EG-TFbbo';

const pgPool = new Pool({
  host: process.env.DB_HOST || '100.100.172.109',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'davin_db',
  user: process.env.DB_USER || 'davin',
  password: process.env.DB_PASSWORD || 'davin',
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

const r2Account = process.env.R2_ACCOUNT_ID || '8fb564d193109f2b71d36d8ddb5b1433';
const r2AccessKey = process.env.R2_ACCESS_KEY_ID || 'e1630a7ce282a7a59a15af4556557594';
const r2SecretKey = process.env.R2_SECRET_ACCESS_KEY || '20c38894070c6b46fd0038fa79e20b2331973f22b617da6121acf79599eef838';
const r2Bucket = process.env.R2_BUCKET_NAME || 'jatimas-sangkar';
const r2PublicDomain = (process.env.R2_PUBLIC_DOMAIN || 'https://pub-8ee60eb20db74c5f9b34ef8efa85263e.r2.dev').replace(/\/+$/, '');

const s3Client = new S3Client({
  region: 'auto',
  endpoint: `https://${r2Account}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: r2AccessKey,
    secretAccessKey: r2SecretKey,
  },
});

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function testConnections() {
  console.log('🔍 Menguji koneksi database PostgreSQL...');
  const client = await pgPool.connect();
  const res = await client.query('SELECT NOW() as current_time, current_database() as db_name, version()');
  console.log(`✅ Terhubung ke PostgreSQL: ${res.rows[0].db_name} (${res.rows[0].current_time})`);
  client.release();

  console.log('🔍 Menguji koneksi Cloudflare R2...');
  try {
    const listRes = await s3Client.send(new ListObjectsV2Command({ Bucket: r2Bucket, MaxKeys: 5 }));
    console.log(`✅ Terhubung ke Cloudflare R2 Bucket [${r2Bucket}]. Total item saat ini: ${listRes.KeyCount || 0}`);
  } catch (err) {
    console.error('❌ Gagal akses bucket R2:', err.message);
    throw err;
  }
}

async function setupPostgresSchema() {
  console.log('\n📦 Menyiapkan schema database PostgreSQL...');
  const client = await pgPool.connect();
  try {
    await client.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";');
    await client.query('CREATE EXTENSION IF NOT EXISTS "pgcrypto";');

    // 1. Tabel Produk
    await client.query(`
      CREATE TABLE IF NOT EXISTS public.produk (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        kode VARCHAR(50),
        nama VARCHAR(255) NOT NULL,
        deskripsi TEXT,
        gambar_url TEXT,
        hashtags TEXT,
        variasi JSONB,
        last_edited_date VARCHAR(50),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
      );
    `);

    // 2. Tabel User Private
    await client.query(`
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
    `);

    // 3. Tabel Produk Custom
    await client.query(`
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
    `);

    // 4. Tabel Pesanan
    await client.query(`
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
    `);

    // 5. Tabel App Settings
    await client.query(`
      CREATE TABLE IF NOT EXISTS public.app_settings (
        id VARCHAR(50) PRIMARY KEY DEFAULT 'global_settings',
        settings_json JSONB NOT NULL,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
      );
    `);

    // 6. Tabel Bentuk Sangkar
    await client.query(`
      CREATE TABLE IF NOT EXISTS public.bentuk_sangkar (
        id VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        image_url TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
      );
    `);

    // 7. Tabel Hashtags
    await client.query(`
      CREATE TABLE IF NOT EXISTS public.hashtags (
        id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
        name VARCHAR(100) UNIQUE NOT NULL,
        use_count INT DEFAULT 1,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
      );
    `);

    console.log('✅ Schema tabel PostgreSQL berhasil dibuat/disiapkan.');
  } finally {
    client.release();
  }
}

// Upload file bytes to Cloudflare R2
async function uploadToR2(key, body, contentType) {
  const cleanKey = key.replace(/^\/+/, '');
  const command = new PutObjectCommand({
    Bucket: r2Bucket,
    Key: cleanKey,
    Body: body,
    ContentType: contentType || 'image/jpeg',
  });
  await s3Client.send(command);
  const publicUrl = `${r2PublicDomain}/${cleanKey}`;
  return publicUrl;
}

// Download image from URL and upload to R2
const urlMapping = new Map();

async function migrateUrlToR2(url) {
  if (!url || typeof url !== 'string') return url;
  const trimmed = url.trim();
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return url;

  if (urlMapping.has(trimmed)) {
    return urlMapping.get(trimmed);
  }

  // Cek apakah url adalah dari supabase storage
  if (trimmed.includes('supabase.co/storage/v1/object/public/')) {
    try {
      console.log(`   📥 Mengunduh aset dari Supabase Storage: ${trimmed}`);
      const resp = await fetch(trimmed);
      if (!resp.ok) {
        console.warn(`   ⚠️ Gagal download aset: ${resp.statusText}`);
        return trimmed;
      }
      const arrayBuffer = await resp.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);
      const contentType = resp.headers.get('content-type') || 'image/jpeg';

      // Ekstrak nama file / path dari URL Supabase
      const urlObj = new URL(trimmed);
      const parts = urlObj.pathname.split('/storage/v1/object/public/');
      let keyPath = parts[1] || `migrated/${Date.now()}.jpg`;
      // Hapus nama bucket pertama jika ada format bucket/filename
      if (keyPath.startsWith('katalog/')) {
        keyPath = keyPath.substring('katalog/'.length);
      }

      console.log(`   📤 Mengunggah ke Cloudflare R2: ${keyPath}`);
      const newUrl = await uploadToR2(keyPath, buffer, contentType);
      console.log(`   ✨ Berhasil migrasi aset -> ${newUrl}`);
      urlMapping.set(trimmed, newUrl);
      return newUrl;
    } catch (e) {
      console.error(`   ❌ Gagal migrasi URL ${trimmed}:`, e.message);
      return trimmed;
    }
  }

  return trimmed;
}

async function migrateStorageBuckets() {
  console.log('\n🗂️ Memeriksa bucket penyimpanan Supabase Storage...');
  const buckets = ['katalog', 'images', 'uploads', 'public', 'photos'];
  for (const b of buckets) {
    try {
      const { data: files, error } = await supabase.storage.from(b).list('', { limit: 100 });
      if (error || !files || files.length === 0) continue;
      console.log(`Ditemukan ${files.length} file di bucket '${b}'`);
      for (const f of files) {
        if (!f.name) continue;
        const publicUrl = supabase.storage.from(b).getPublicUrl(f.name).data.publicUrl;
        await migrateUrlToR2(publicUrl);
      }
    } catch (e) {
      // Abaikan jika bucket tidak ada
    }
  }
}

// Recursive helper to transform all Supabase storage URLs in JSON objects
async function replaceUrlsInObject(obj) {
  if (!obj) return obj;
  if (typeof obj === 'string') {
    if (obj.includes('supabase.co/storage/v1/object/public/')) {
      return await migrateUrlToR2(obj);
    }
    return obj;
  }
  if (Array.isArray(obj)) {
    const arr = [];
    for (const item of obj) {
      arr.push(await replaceUrlsInObject(item));
    }
    return arr;
  }
  if (typeof obj === 'object') {
    const res = {};
    for (const [k, v] of Object.entries(obj)) {
      res[k] = await replaceUrlsInObject(v);
    }
    return res;
  }
  return obj;
}

async function migrateData() {
  const client = await pgPool.connect();

  try {
    // 1. Migrasi Tabel `produk`
    console.log('\n--- 1. Migrasi Tabel PRODUK ---');
    const { data: produkList, error: errProduk } = await supabase.from('produk').select('*');
    if (errProduk) {
      console.error('Error membaca produk dari Supabase:', errProduk);
    } else {
      console.log(`Ditemukan ${produkList.length} data produk di Supabase.`);
      for (const item of produkList) {
        let gambarUrl = item.gambar_url;
        if (gambarUrl) {
          gambarUrl = await migrateUrlToR2(gambarUrl);
        }
        let variasi = item.variasi;
        if (variasi) {
          variasi = await replaceUrlsInObject(variasi);
        }

        await client.query(`
          INSERT INTO public.produk (id, kode, nama, deskripsi, gambar_url, hashtags, variasi, last_edited_date, created_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
          ON CONFLICT (id) DO UPDATE SET
            kode = EXCLUDED.kode,
            nama = EXCLUDED.nama,
            deskripsi = EXCLUDED.deskripsi,
            gambar_url = EXCLUDED.gambar_url,
            hashtags = EXCLUDED.hashtags,
            variasi = EXCLUDED.variasi,
            last_edited_date = EXCLUDED.last_edited_date;
        `, [
          item.id,
          item.kode,
          item.nama,
          item.deskripsi,
          gambarUrl,
          item.hashtags,
          JSON.stringify(variasi || {}),
          item.last_edited_date,
          item.created_at || new Date().toISOString()
        ]);
      }
      console.log(`✅ Sukses migrasi ${produkList.length} data produk ke PostgreSQL.`);
    }

    // 2. Migrasi Tabel `user_private`
    console.log('\n--- 2. Migrasi Tabel USER_PRIVATE ---');
    const { data: userList, error: errUser } = await supabase.from('user_private').select('*');
    if (errUser) {
      console.error('Error membaca user_private dari Supabase:', errUser);
    } else {
      console.log(`Ditemukan ${userList.length} data user_private di Supabase.`);
      for (const item of userList) {
        await client.query(`
          INSERT INTO public.user_private (id, name, phone, email, password, join_date, jumlah_logo_custom, request_count, created_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
          ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            phone = EXCLUDED.phone,
            email = EXCLUDED.email,
            password = EXCLUDED.password,
            join_date = EXCLUDED.join_date,
            jumlah_logo_custom = EXCLUDED.jumlah_logo_custom,
            request_count = EXCLUDED.request_count;
        `, [
          item.id,
          item.name || '',
          item.phone,
          item.email,
          item.password,
          item.join_date,
          item.jumlah_logo_custom || 0,
          item.request_count || 0,
          item.created_at || new Date().toISOString()
        ]);
      }
      console.log(`✅ Sukses migrasi ${userList.length} data user_private ke PostgreSQL.`);
    }

    // 3. Migrasi Tabel `produk_custom`
    console.log('\n--- 3. Migrasi Tabel PRODUK_CUSTOM ---');
    const { data: customList, error: errCustom } = await supabase.from('produk_custom').select('*');
    if (errCustom) {
      console.error('Error membaca produk_custom dari Supabase:', errCustom);
    } else {
      console.log(`Ditemukan ${customList.length} data produk_custom di Supabase.`);
      for (const item of customList) {
        let gambarUrl = item.gambar_url;
        if (gambarUrl) {
          gambarUrl = await migrateUrlToR2(gambarUrl);
        }
        let variasi = item.variasi;
        if (variasi) {
          variasi = await replaceUrlsInObject(variasi);
        }

        await client.query(`
          INSERT INTO public.produk_custom (id, user_identifier, kode, nama, harga, deskripsi, gambar_url, kategori, variasi, last_edited_date, created_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
          ON CONFLICT (id) DO UPDATE SET
            user_identifier = EXCLUDED.user_identifier,
            kode = EXCLUDED.kode,
            nama = EXCLUDED.nama,
            harga = EXCLUDED.harga,
            deskripsi = EXCLUDED.deskripsi,
            gambar_url = EXCLUDED.gambar_url,
            kategori = EXCLUDED.kategori,
            variasi = EXCLUDED.variasi,
            last_edited_date = EXCLUDED.last_edited_date;
        `, [
          item.id,
          item.user_identifier,
          item.kode,
          item.nama,
          item.harga || 0,
          item.deskripsi,
          gambarUrl,
          item.kategori,
          JSON.stringify(variasi || {}),
          item.last_edited_date,
          item.created_at || new Date().toISOString()
        ]);
      }
      console.log(`✅ Sukses migrasi ${customList.length} data produk_custom ke PostgreSQL.`);
    }

    // 4. Migrasi Tabel `pesanan`
    console.log('\n--- 4. Migrasi Tabel PESANAN ---');
    const { data: pesananList, error: errPesanan } = await supabase.from('pesanan').select('*');
    if (errPesanan) {
      console.error('Error membaca pesanan dari Supabase:', errPesanan);
    } else {
      console.log(`Ditemukan ${pesananList.length} data pesanan di Supabase.`);
      for (const item of pesananList) {
        let items = item.items;
        if (items) {
          items = await replaceUrlsInObject(items);
        }

        await client.query(`
          INSERT INTO public.pesanan (id, phone, customer_name, email, order_date, status, stage_number, is_completed, total_amount, items, created_at)
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
          ON CONFLICT (id) DO UPDATE SET
            phone = EXCLUDED.phone,
            customer_name = EXCLUDED.customer_name,
            email = EXCLUDED.email,
            order_date = EXCLUDED.order_date,
            status = EXCLUDED.status,
            stage_number = EXCLUDED.stage_number,
            is_completed = EXCLUDED.is_completed,
            total_amount = EXCLUDED.total_amount,
            items = EXCLUDED.items;
        `, [
          item.id,
          item.phone,
          item.customer_name || '',
          item.email,
          item.order_date,
          item.status,
          item.stage_number || 1,
          item.is_completed || false,
          item.total_amount || 0,
          JSON.stringify(items || []),
          item.created_at || new Date().toISOString()
        ]);
      }
      console.log(`✅ Sukses migrasi ${pesananList.length} data pesanan ke PostgreSQL.`);
    }

    // 5. Migrasi Tabel `app_settings`
    console.log('\n--- 5. Migrasi Tabel APP_SETTINGS ---');
    const { data: settingsList, error: errSettings } = await supabase.from('app_settings').select('*');
    if (errSettings) {
      console.error('Error membaca app_settings dari Supabase:', errSettings);
    } else {
      console.log(`Ditemukan ${settingsList.length} data app_settings di Supabase.`);
      for (const item of settingsList) {
        let settingsJson = item.settings_json;
        if (settingsJson) {
          settingsJson = await replaceUrlsInObject(settingsJson);
        }

        await client.query(`
          INSERT INTO public.app_settings (id, settings_json, updated_at)
          VALUES ($1, $2, $3)
          ON CONFLICT (id) DO UPDATE SET
            settings_json = EXCLUDED.settings_json,
            updated_at = EXCLUDED.updated_at;
        `, [
          item.id,
          JSON.stringify(settingsJson || {}),
          item.updated_at || new Date().toISOString()
        ]);
      }
      console.log(`✅ Sukses migrasi ${settingsList.length} data app_settings ke PostgreSQL.`);
    }

    // 6. Migrasi Tabel `bentuk_sangkar`
    console.log('\n--- 6. Migrasi Tabel BENTUK_SANGKAR ---');
    const { data: cageList, error: errCage } = await supabase.from('bentuk_sangkar').select('*');
    if (errCage) {
      console.error('Error membaca bentuk_sangkar dari Supabase:', errCage);
    } else {
      console.log(`Ditemukan ${cageList.length} data bentuk_sangkar di Supabase.`);
      for (const item of cageList) {
        let imageUrl = item.image_url;
        if (imageUrl) {
          imageUrl = await migrateUrlToR2(imageUrl);
        }

        await client.query(`
          INSERT INTO public.bentuk_sangkar (id, name, image_url, created_at)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT (id) DO UPDATE SET
            name = EXCLUDED.name,
            image_url = EXCLUDED.image_url;
        `, [
          item.id,
          item.name,
          imageUrl,
          item.created_at || new Date().toISOString()
        ]);
      }
      console.log(`✅ Sukses migrasi ${cageList.length} data bentuk_sangkar ke PostgreSQL.`);
    }

    // 7. Migrasi Tabel `hashtags`
    console.log('\n--- 7. Migrasi Tabel HASHTAGS ---');
    const { data: hashtagList, error: errHash } = await supabase.from('hashtags').select('*');
    if (errHash) {
      console.error('Error membaca hashtags dari Supabase:', errHash);
    } else {
      console.log(`Ditemukan ${hashtagList.length} data hashtags di Supabase.`);
      for (const item of hashtagList) {
        await client.query(`
          INSERT INTO public.hashtags (id, name, use_count, created_at, updated_at)
          VALUES ($1, $2, $3, $4, $5)
          ON CONFLICT (name) DO UPDATE SET
            use_count = EXCLUDED.use_count,
            updated_at = EXCLUDED.updated_at;
        `, [
          item.id,
          item.name,
          item.use_count || 1,
          item.created_at || new Date().toISOString(),
          item.updated_at || new Date().toISOString()
        ]);
      }
      console.log(`✅ Sukses migrasi ${hashtagList.length} data hashtags ke PostgreSQL.`);
    }

    console.log('\n🎉 =========================================================');
    console.log('🎉 SEMUA DATA DAN ASET BERHASIL DIPINDAHKAN KE POSTGRESQL & R2!');
    console.log('🎉 =========================================================\n');
  } finally {
    client.release();
  }
}

async function run() {
  try {
    await testConnections();
    await setupPostgresSchema();
    await migrateStorageBuckets();
    await migrateData();
  } catch (err) {
    console.error('\n❌ Terjadi kesalahan saat proses migrasi:', err);
    process.exit(1);
  } finally {
    await pgPool.end();
  }
}

run();
