import { BadRequestException, Body, Controller, Get, Param, Post, Req, UploadedFiles, UseGuards, UseInterceptors } from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { randomUUID } from 'crypto';
import { mkdirSync } from 'fs';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { PlacesService } from './places.service';
import { AdminGuard, NeonGuard } from '../auth/neon.guard';

@Controller('places')
export class PlacesController {
  constructor(private readonly placesService: PlacesService) {}

  @Get()
  getAllPlaces() {
    return this.placesService.findAll();
  }

  @Get(':id/community')
  community(@Param('id') id: string) {
    return this.placesService.community(id);
  }

  @UseGuards(NeonGuard)
  @Post(':id/community')
  @UseInterceptors(FilesInterceptor('photos', 6, {
    storage: diskStorage({
      destination: (_req, _file, callback) => {
        const directory = join(process.cwd(), 'uploads', 'memories');
        mkdirSync(directory, { recursive: true });
        callback(null, directory);
      },
      filename: (_req, file, callback) =>
        callback(null, `${randomUUID()}${extname(file.originalname).toLowerCase()}`),
    }),
    limits: { fileSize: 6 * 1024 * 1024 },
    fileFilter: (_req, file, callback) => callback(
      null,
      ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'].includes(file.mimetype),
    ),
  }))
  saveCommunityPost(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: any,
    @UploadedFiles() files: Express.Multer.File[] = [],
  ) {
    if (files.length > 6) throw new BadRequestException('Upload up to 6 photos.');
    return this.placesService.saveCommunityPost(
      req.user.id,
      id,
      body,
      files.map((file) => `/uploads/memories/${file.filename}`),
    );
  }

  // 2. Use the new NeonGuard instead of the old JwtAuthGuard!
  @UseGuards(NeonGuard, AdminGuard)
  @Post()
  addPlace(@Body() placeData: any) {
    console.log('Received new place from Admin UI:', placeData);
    return this.placesService.create(placeData);
  }
}
