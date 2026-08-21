import { Injectable, InternalServerErrorException } from '@nestjs/common';
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
      const result = await this.pool.query(`SELECT * FROM "Landmark" WHERE "publicationStatus" = 'published' ORDER BY name ASC`);
      return result.rows;
    } catch (error) {
      console.error('Database Fetch Error:', error);
      throw new InternalServerErrorException('Failed to fetch historical places.');
    }
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
