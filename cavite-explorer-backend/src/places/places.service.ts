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
          COALESCE(r."reviewCount", 0)::int AS "reviewCount",
          COALESCE(b."badgeClaimCount", 0)::int AS "badgeClaimCount"
        FROM "Landmark" l
        LEFT JOIN (
          SELECT "landmarkId", AVG(rating) AS "averageRating", COUNT(*) AS "reviewCount"
          FROM "LandmarkCommunityPost"
          GROUP BY "landmarkId"
        ) r ON r."landmarkId" = l.id
        LEFT JOIN (
          SELECT "landmarkId", COUNT(DISTINCT "userId") AS "badgeClaimCount"
          FROM "UserBadge"
          GROUP BY "landmarkId"
        ) b ON b."landmarkId" = l.id
        WHERE l."publicationStatus" = 'published'
        ORDER BY l.name ASC
      `);
      return result.rows;
    } catch (error) {
      console.error('Database Fetch Error:', error);
      throw new InternalServerErrorException('Failed to fetch historical places.');
    }
  }

  async favorites(userId: string) {
    const result = await this.pool.query(`
      SELECT l.*, s."createdAt" AS "savedAt",
        COALESCE(r."averageRating", 0)::float AS "averageRating",
        COALESCE(r."reviewCount", 0)::int AS "reviewCount"
      FROM "SavedLandmark" s
      JOIN "Landmark" l ON l.id = s."landmarkId"
      LEFT JOIN (
        SELECT "landmarkId", AVG(rating) AS "averageRating", COUNT(*) AS "reviewCount"
        FROM "LandmarkCommunityPost" GROUP BY "landmarkId"
      ) r ON r."landmarkId" = l.id
      WHERE s."userId" = $1 AND l."publicationStatus" = 'published'
      ORDER BY s."createdAt" DESC
    `, [userId]);
    return result.rows;
  }

  async favoriteStatus(userId: string, landmarkId: string) {
    const result = await this.pool.query(
      'SELECT id FROM "SavedLandmark" WHERE "userId" = $1 AND "landmarkId" = $2 LIMIT 1',
      [userId, landmarkId],
    );
    return { saved: result.rowCount === 1 };
  }

  async saveFavorite(userId: string, landmarkId: string) {
    const result = await this.pool.query(`
      INSERT INTO "SavedLandmark" (id, "userId", "landmarkId", "createdAt")
      VALUES ($1, $2, $3, NOW())
      ON CONFLICT ("userId", "landmarkId") DO UPDATE SET "createdAt" = EXCLUDED."createdAt"
      RETURNING *
    `, [crypto.randomUUID(), userId, landmarkId]);
    return { saved: true, favorite: result.rows[0] };
  }

  async removeFavorite(userId: string, landmarkId: string) {
    await this.pool.query(
      'DELETE FROM "SavedLandmark" WHERE "userId" = $1 AND "landmarkId" = $2',
      [userId, landmarkId],
    );
    return { saved: false };
  }

  private distanceMeters(aLat: number, aLng: number, bLat: number, bLng: number) {
    const radians = (value: number) => (value * Math.PI) / 180;
    const dLat = radians(bLat - aLat);
    const dLng = radians(bLng - aLng);
    const value = Math.sin(dLat / 2) ** 2 + Math.cos(radians(aLat)) * Math.cos(radians(bLat)) * Math.sin(dLng / 2) ** 2;
    return 6371000 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
  }

  async nearbyPartners(landmarkId: string) {
    const landmarkResult = await this.pool.query(
      'SELECT id, name, latitude, longitude FROM "Landmark" WHERE id = $1',
      [landmarkId],
    );
    const landmark = landmarkResult.rows[0];
    if (!landmark) throw new NotFoundException('Landmark not found.');
    const result = await this.pool.query(`
      SELECT b.*,
        COALESCE(
          json_agg(json_build_object(
            'id', o.id,
            'title', o.title,
            'description', o.description,
            'discountLabel', o."discountLabel"
          ) ORDER BY o."createdAt" DESC) FILTER (WHERE o.id IS NOT NULL),
          '[]'::json
        ) AS offers
      FROM "PartnerBusiness" b
      JOIN "DiscountOffer" o ON o."businessId" = b.id
        AND o."badgeLandmarkId" = $1
        AND o."isActive" = TRUE
      WHERE b."approvalStatus" = 'approved'
        AND b."isActive" = TRUE
        AND b.latitude IS NOT NULL
        AND b.longitude IS NOT NULL
        AND (o."startsAt" IS NULL OR o."startsAt" <= NOW())
        AND (o."endsAt" IS NULL OR o."endsAt" >= NOW())
      GROUP BY b.id
    `, [landmarkId]);
    return result.rows
      .map((business) => ({
        ...business,
        distanceMeters: Math.round(this.distanceMeters(
          Number(landmark.latitude),
          Number(landmark.longitude),
          Number(business.latitude),
          Number(business.longitude),
        )),
      }))
      .filter((business) => business.distanceMeters <= 2500)
      .sort((a, b) => a.distanceMeters - b.distanceMeters);
  }

  private async requireEarnedBadge(userId: string, landmarkId: string) {
    const badge = await this.pool.query(
      'SELECT id, "earnedAt" FROM "UserBadge" WHERE "userId" = $1 AND "landmarkId" = $2',
      [userId, landmarkId],
    );
    if (badge.rowCount === 0) {
      throw new ForbiddenException(
        'Earn this landmark badge before adding personal memories.',
      );
    }
    return badge.rows[0];
  }

  async personalMemories(userId: string, landmarkId: string) {
    await this.requireEarnedBadge(userId, landmarkId);
    const [landmarkResult, memoriesResult] = await Promise.all([
      this.pool.query(
        'SELECT id, name, municipality, barangay, images, "badgeName", "badgeImage" FROM "Landmark" WHERE id = $1',
        [landmarkId],
      ),
      this.pool.query(
        `SELECT * FROM "LandmarkMemory"
         WHERE "userId" = $1 AND "landmarkId" = $2
         ORDER BY "visitedAt" DESC, "createdAt" DESC`,
        [userId, landmarkId],
      ),
    ]);
    if (!landmarkResult.rows[0]) {
      throw new NotFoundException('Landmark not found.');
    }
    return {
      landmark: landmarkResult.rows[0],
      memories: memoriesResult.rows,
    };
  }

  async savePersonalMemory(
    userId: string,
    landmarkId: string,
    body: any,
    uploadedPhotos: string[],
  ) {
    await this.requireEarnedBadge(userId, landmarkId);
    const story = String(body.story ?? '').trim();
    if (!story) {
      throw new BadRequestException('Write something about this visit.');
    }
    if (story.length > 4000) {
      throw new BadRequestException('Keep your memory under 4,000 characters.');
    }
    const ratingText = String(body.rating ?? '').trim();
    const rating = ratingText ? Number(ratingText) : null;
    if (rating !== null && (!Number.isInteger(rating) || rating < 1 || rating > 5)) {
      throw new BadRequestException('Choose a rating from 1 to 5 stars.');
    }
    const visitedAt = body.visitedAt ? new Date(body.visitedAt) : new Date();
    if (Number.isNaN(visitedAt.getTime())) {
      throw new BadRequestException('Choose a valid visit date.');
    }
    const sharePublicly = body.sharePublicly === true || body.sharePublicly === 'true';
    const visibility = sharePublicly ? 'PUBLIC' : 'PRIVATE';
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const memoryResult = await client.query(
        `INSERT INTO "LandmarkMemory"
          (id, "userId", "landmarkId", title, story, "favoriteMoment", mood,
           rating, photos, "visitedAt", visibility, "createdAt", "updatedAt")
         VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8::text[], $9, $10, NOW(), NOW())
         RETURNING *`,
        [
          userId,
          landmarkId,
          String(body.title ?? '').trim() || null,
          story,
          String(body.favoriteMoment ?? '').trim() || null,
          String(body.mood ?? '').trim() || null,
          rating,
          uploadedPhotos,
          visitedAt,
          visibility,
        ],
      );
      // Public sharing updates the visitor's single review for ranking, while
      // every personal journal entry remains preserved independently.
      if (sharePublicly && rating !== null) {
        await client.query(
          `INSERT INTO "LandmarkCommunityPost"
            (id, "userId", "landmarkId", rating, memory, thoughts, photos, "createdAt", "updatedAt")
           VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6::text[], NOW(), NOW())
           ON CONFLICT ("userId", "landmarkId") DO UPDATE SET
             rating = EXCLUDED.rating,
             memory = EXCLUDED.memory,
             thoughts = EXCLUDED.thoughts,
             photos = EXCLUDED.photos,
             "updatedAt" = NOW()`,
          [
            userId,
            landmarkId,
            rating,
            story,
            String(body.favoriteMoment ?? '').trim() || null,
            uploadedPhotos,
          ],
        );
      }
      await client.query('COMMIT');
      return memoryResult.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async removePersonalMemory(userId: string, landmarkId: string, memoryId: string) {
    const result = await this.pool.query(
      `DELETE FROM "LandmarkMemory"
       WHERE id = $1 AND "userId" = $2 AND "landmarkId" = $3
       RETURNING id`,
      [memoryId, userId, landmarkId],
    );
    if (result.rowCount === 0) {
      throw new NotFoundException('Memory not found.');
    }
    return { deleted: true, id: memoryId };
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
