const { Pool } = require('pg');
const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const pool = new Pool({
  host: process.env.DB_HOST || '100.100.172.109',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'davin_db',
  user: process.env.DB_USER || 'davin',
  password: process.env.DB_PASSWORD || 'davin',
});

async function main() {
  const tables = ['produk', 'user_private', 'produk_custom', 'pesanan', 'app_settings', 'bentuk_sangkar', 'hashtags'];
  console.log('=== STATUS DATA DI POSTGRESQL (davin_db) ===');
  for (const t of tables) {
    const res = await pool.query(`SELECT COUNT(*) FROM public.${t}`);
    console.log(`- Tabel ${t.padEnd(16)}: ${res.rows[0].count} baris`);
  }
  await pool.end();
}

main().catch(console.error);
