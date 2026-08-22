import { v2 as cloudinary } from 'cloudinary';
import { readdir, stat } from 'node:fs/promises';
import path from 'node:path';
import pg from 'pg';
import sharp from 'sharp';

if (!process.env.CLOUDINARY_URL) throw new Error('CLOUDINARY_URL is missing from .env.');
if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is missing from .env.');

cloudinary.config({ secure: true });
const uploadsRoot = path.resolve('uploads');
const folders = ['landmarks', 'partners', 'memories'];
const urlByLocalPath = new Map();

for (const folder of folders) {
  const directory = path.join(uploadsRoot, folder);
  let names = [];
  try { names = await readdir(directory); } catch { continue; }
  for (const name of names) {
    const filePath = path.join(directory, name);
    const fileInfo = await stat(filePath);
    if (!fileInfo.isFile()) continue;
    let uploadSource = filePath;
    if (fileInfo.size > 10 * 1024 * 1024) {
      const compressed = await sharp(filePath)
        .rotate()
        .resize({ width: 2400, height: 2400, fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 82, progressive: true })
        .toBuffer();
      uploadSource = `data:image/jpeg;base64,${compressed.toString('base64')}`;
      process.stdout.write(`Compressed migration copy for ${folder}/${name}\n`);
    }
    const publicId = path.parse(name).name;
    const result = await cloudinary.uploader.upload(uploadSource, {
      folder: `cavite-explorer/${folder}`,
      public_id: publicId,
      overwrite: true,
      resource_type: 'image',
    });
    urlByLocalPath.set(`/uploads/${folder}/${name}`, result.secure_url);
    process.stdout.write(`Uploaded ${folder}/${name}\n`);
  }
}

const normalize = (value) => {
  if (!value || typeof value !== 'string') return value;
  if (value.startsWith('file:///uploads/')) return value.slice('file://'.length);
  return value;
};
const replace = (value) => urlByLocalPath.get(normalize(value)) || value;
const replaceMany = (values) => Array.isArray(values) ? values.map(replace) : [];

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
const client = await pool.connect();
try {
  await client.query('BEGIN');
  const landmarks = await client.query('SELECT id, images, "badgeImage" FROM "Landmark"');
  for (const row of landmarks.rows) {
    await client.query('UPDATE "Landmark" SET images = $1, "badgeImage" = $2 WHERE id = $3', [replaceMany(row.images), replace(row.badgeImage), row.id]);
  }
  const businesses = await client.query('SELECT id, image FROM "PartnerBusiness"');
  for (const row of businesses.rows) {
    await client.query('UPDATE "PartnerBusiness" SET image = $1 WHERE id = $2', [replace(row.image), row.id]);
  }
  const community = await client.query('SELECT id, photos FROM "LandmarkCommunityPost"');
  for (const row of community.rows) {
    await client.query('UPDATE "LandmarkCommunityPost" SET photos = $1 WHERE id = $2', [replaceMany(row.photos), row.id]);
  }
  const memories = await client.query('SELECT id, photos FROM "LandmarkMemory"');
  for (const row of memories.rows) {
    await client.query('UPDATE "LandmarkMemory" SET photos = $1 WHERE id = $2', [replaceMany(row.photos), row.id]);
  }
  await client.query('COMMIT');
  process.stdout.write(`Migration complete: ${urlByLocalPath.size} files uploaded and database URLs updated.\n`);
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
} finally {
  client.release();
  await pool.end();
}
