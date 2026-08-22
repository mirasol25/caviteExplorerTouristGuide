import { BadRequestException, Body, Controller, Delete, Get, Param, Post, Req, UploadedFiles, UseGuards, UseInterceptors } from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { PlacesService } from './places.service';
import { AdminGuard, NeonGuard } from '../auth/neon.guard';
import { CloudinaryStorageService } from '../storage/cloudinary-storage.service';

@Controller('places')
export class PlacesController {
  constructor(private readonly placesService: PlacesService, private readonly storage: CloudinaryStorageService) {}

  @Get()
  getAllPlaces() {
    return this.placesService.findAll();
  }

  @UseGuards(NeonGuard)
  @Get('favorites/me')
  favorites(@Req() req: any) {
    return this.placesService.favorites(req.user.id);
  }

  @UseGuards(NeonGuard)
  @Get(':id/favorite')
  favoriteStatus(@Req() req: any, @Param('id') id: string) {
    return this.placesService.favoriteStatus(req.user.id, id);
  }

  @UseGuards(NeonGuard)
  @Post(':id/favorite')
  saveFavorite(@Req() req: any, @Param('id') id: string) {
    return this.placesService.saveFavorite(req.user.id, id);
  }

  @UseGuards(NeonGuard)
  @Delete(':id/favorite')
  removeFavorite(@Req() req: any, @Param('id') id: string) {
    return this.placesService.removeFavorite(req.user.id, id);
  }

  @Get(':id/community')
  community(@Param('id') id: string) {
    return this.placesService.community(id);
  }

  @Get(':id/partners')
  partners(@Param('id') id: string) {
    return this.placesService.nearbyPartners(id);
  }

  @UseGuards(NeonGuard)
  @Get(':id/memories/me')
  memories(@Req() req: any, @Param('id') id: string) {
    return this.placesService.personalMemories(req.user.id, id);
  }

  @UseGuards(NeonGuard)
  @Post(':id/memories')
  @UseInterceptors(FilesInterceptor('photos', 8, {
    storage: memoryStorage(),
    limits: { fileSize: 6 * 1024 * 1024 },
    fileFilter: (_req, file, callback) => callback(
      null,
      ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'].includes(file.mimetype),
    ),
  }))
  async saveMemory(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: any,
    @UploadedFiles() files: Express.Multer.File[] = [],
  ) {
    const photos = await this.storage.uploadMany(files, 'memories');
    return this.placesService.savePersonalMemory(
      req.user.id,
      id,
      body,
      photos,
    );
  }

  @UseGuards(NeonGuard)
  @Delete(':id/memories/:memoryId')
  removeMemory(
    @Req() req: any,
    @Param('id') id: string,
    @Param('memoryId') memoryId: string,
  ) {
    return this.placesService.removePersonalMemory(req.user.id, id, memoryId);
  }

  @UseGuards(NeonGuard)
  @Post(':id/community')
  @UseInterceptors(FilesInterceptor('photos', 6, {
    storage: memoryStorage(),
    limits: { fileSize: 6 * 1024 * 1024 },
    fileFilter: (_req, file, callback) => callback(
      null,
      ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'].includes(file.mimetype),
    ),
  }))
  async saveCommunityPost(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: any,
    @UploadedFiles() files: Express.Multer.File[] = [],
  ) {
    if (files.length > 6) throw new BadRequestException('Upload up to 6 photos.');
    const photos = await this.storage.uploadMany(files, 'community');
    return this.placesService.saveCommunityPost(
      req.user.id,
      id,
      body,
      photos,
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
