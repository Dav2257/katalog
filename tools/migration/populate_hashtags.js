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
  const tags = [
    '#sangkar', '#jati', '#jepara', '#ukir', '#cungkok', '#kacer',
    '#murai', '#kenari', '#pleci', '#kosan', '#replika', '#finishing',
    '#natural', '#mentahan', '#kayu', '#bambu', '#serdadu', '#carbon'
  ];

  for (const tag of tags) {
    await pool.query(
      'INSERT INTO public.hashtags (name) VALUES ($1) ON CONFLICT (name) DO NOTHING',
      [tag]
    );
  }

  const res = await pool.query('SELECT COUNT(*) FROM public.hashtags');
  console.log('✅ Berhasil memasukkan hashtags. Total hashtags di DB:', res.rows[0].count);
  await pool.end();
}

main().catch(console.error);
