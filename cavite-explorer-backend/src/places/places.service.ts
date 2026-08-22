import { BadRequestException, ForbiddenException, Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import { Pool } from 'pg';
import * as crypto from 'crypto'; // Built into Node.js, perfect for generating IDs!

@Injectable()
export class PlacesService {
  private pool: Pool;

  constructor() {
    this.pool = new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: {
        rejectUnauthorized: false,
      },
    });
  }

  // Fetch all places from your existing Landmark table
  async findAll() {
    try {
      // Notice the double quotes around "Landmark"!
      const result = await this.pool.query(`
        SELECT l.*,
          COALESCE(r."averageRating", 0)::float AS "averageRating",
          COALESCE(r."reviewCount", 0)::int AS "reviewCount"
        FROM "Landmark" l
        LEFT JOIN (
          SELECT "landmarkId", AVG(rating) AS "averageRating", COUNT(*) AS "reviewCount"
          FROM "LandmarkCommunityPost"
          GROUP BY "landmarkId"
        ) r ON r."landmarkId" = l.id
        WHERE l."publicationStatus" = 'published'
        ORDER BY l.name ASC
      `);
      return result.rows;
    } catch (error) {
      console.error('Database Fetch Error:', error);
      throw new InternalServerErrorException('Failed to fetch historical places.');
    }
  }

  async community(landmarkId: string) {
    const landmarkResult = await this.pool.query(
      'SELECT id, name FROM "Landmark" WHERE id = $1',
      [landmarkId],
    );
    const landmark = landmarkResult.rows[0];
    if (!landmark) throw new NotFoundException('Landmark not found.');
    const [postsResult, aggregateResult] = await Promise.all([
      this.pool.query(
        `SELECT p.*, json_build_object('id', u.id, 'name', u.name) AS user
         FROM "LandmarkCommunityPost" p
         JOIN "User" u ON u.id = p."userId"
         WHERE p."landmarkId" = $1
         ORDER BY p."createdAt" DESC`,
        [landmarkId],
      ),
      this.pool.query(
        `SELECT COALESCE(AVG(rating), 0)::float AS average,
                COUNT(*)::int AS count
         FROM "LandmarkCommunityPost" WHERE "landmarkId" = $1`,
        [landmarkId],
      ),
    ]);
    return {
      landmark,
      averageRating: aggregateResult.rows[0]?.average ?? 0,
      reviewCount: aggregateResult.rows[0]?.count ?? 0,
      posts: postsResult.rows,
    };
  }

  async saveCommunityPost(
    userId: string,
    landmarkId: string,
    body: any,
    uploadedPhotos: string[],
  ) {
    const rating = Number(body.rating);
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      throw new BadRequestException('Choose a rating from 1 to 5 stars.');
    }
    const badge = await this.pool.query(
      'SELECT id FROM "UserBadge" WHERE "userId" = $1 AND "landmarkId" = $2',
      [userId, landmarkId],
    );
    if (badge.rowCount === 0) {
      throw new ForbiddenException(
        'Earn this landmark badge before sharing a verified memory.',
      );
    }
    const existingResult = await this.pool.query(
      'SELECT photos FROM "LandmarkCommunityPost" WHERE "userId" = $1 AND "landmarkId" = $2',
      [userId, landmarkId],
    );
    const existing = existingResult.rows[0];
    const memory = String(body.memory ?? '').trim().slice(0, 1200) || null;
    const thoughts = String(body.thoughts ?? '').trim().slice(0, 1200) || null;
    const photos = uploadedPhotos.length > 0
      ? uploadedPhotos
      : existing?.photos ?? [];
    if (!memory && !thoughts && photos.length === 0) {
      throw new BadRequestException('Add a photo, memory, or thought to share.');
    }
    const id = crypto.randomUUID();
    const result = await this.pool.query(
      `INSERT INTO "LandmarkCommunityPost"
         (id, "userId", "landmarkId", rating, memory, thoughts, photos, "createdAt", "updatedAt")
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
       ON CONFLICT ("userId", "landmarkId") DO UPDATE SET
         rating = EXCLUDED.rating,
         memory = EXCLUDED.memory,
         thoughts = EXCLUDED.thoughts,
         photos = EXCLUDED.photos,
         "updatedAt" = NOW()
       RETURNING *`,
      [id, userId, landmarkId, rating, memory, thoughts, photos],
    );
    const user = await this.pool.query(
      'SELECT id, name FROM "User" WHERE id = $1',
      [userId],
    );
    return { ...result.rows[0], user: user.rows[0] };
  }

  // Insert a new place into your Landmark table
  async create(placeData: any) {
    const { name, municipality, barangay, description, latitude, longitude } = placeData;
    
    // Generate a unique ID and current timestamp for your columns
    const newId = crypto.randomUUID(); 
    const now = new Date();

    try {
      const query = `
        INSERT INTO "Landmark" (id, name, municipality, barangay, description, latitude, longitude, "updatedAt")
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *;
      `;
      const values = [newId, name, municipality, barangay || null, description, latitude, longitude, now];
      
      const result = await this.pool.query(query, values);
      return result.rows[0]; 
    } catch (error) {
      console.error('Database Insert Error:', error);
      throw new InternalServerErrorException('Failed to save the location to the database.');
    }
  }
}
