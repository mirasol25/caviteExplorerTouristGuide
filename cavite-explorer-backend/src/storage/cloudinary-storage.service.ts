import { BadRequestException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';

@Injectable()
export class CloudinaryStorageService {
  constructor() {
    if (process.env.CLOUDINARY_URL) cloudinary.config({ secure: true });
  }

  private ensureConfigured() {
    if (!process.env.CLOUDINARY_URL) {
      throw new ServiceUnavailableException('Image storage is not configured. Add CLOUDINARY_URL.');
    }
  }

  upload(file: Express.Multer.File, folder: string): Promise<string> {
    this.ensureConfigured();
    if (!file?.buffer?.length) throw new BadRequestException('The selected image is empty.');
    return new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: `cavite-explorer/${folder}`,
          resource_type: 'image',
          use_filename: true,
          unique_filename: true,
          overwrite: false,
        },
        (error, result?: UploadApiResponse) => {
          if (error || !result?.secure_url) {
            reject(new ServiceUnavailableException('Image upload failed. Please try again.'));
            return;
          }
          resolve(result.secure_url);
        },
      );
      stream.end(file.buffer);
    });
  }

  uploadMany(files: Express.Multer.File[], folder: string) {
    return Promise.all(files.map((file) => this.upload(file, folder)));
  }
}
