import { BadRequestException, Body, Controller, Get, Param, Patch, Post, Put, Query, Req, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { NeonGuard } from '../auth/neon.guard';
import { CloudinaryStorageService } from '../storage/cloudinary-storage.service';
import { RewardsService } from './rewards.service';

@Controller('rewards')
@UseGuards(NeonGuard)
export class RewardsController {
  constructor(private readonly rewards: RewardsService, private readonly storage: CloudinaryStorageService) {}

  @Get('badges/:userBadgeId')
  badge(@Req() req: any, @Param('userBadgeId') id: string) {
    return this.rewards.badgeCredential(req.user.id, id);
  }

  @Get('partners')
  partners() {
    return this.rewards.partners();
  }

  @Get('partner/dashboard')
  dashboard(@Req() req: any) {
    return this.rewards.dashboard(req.user.id, req.user.role);
  }

  @Get('partner/redemptions')
  redemptions(@Req() req: any, @Query('range') range = '30d', @Query('page') page = '1') {
    return this.rewards.redemptionReport(req.user.id, req.user.role, range, Number(page));
  }

  @Get('partner/application')
  application(@Req() req: any) {
    return this.rewards.application(req.user.id, req.user.role);
  }

  @Put('partner/application')
  saveApplication(@Req() req: any, @Body() body: any) {
    return this.rewards.saveApplication(req.user.id, req.user.role, body);
  }

  @Post('partner/logo')
  @UseInterceptors(FileInterceptor('file', {
    storage: memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (_req, file, callback) =>
      callback(null, ['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)),
  }))
  async uploadPartnerLogo(@Req() req: any, @UploadedFile() file?: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('Choose a JPG, PNG, or WebP logo up to 5 MB.');
    }
    const image = await this.storage.upload(file, 'partners');
    return this.rewards.savePartnerLogo(
      req.user.id,
      req.user.role,
      image,
    );
  }

  @Post('partner/application/submit')
  submitApplication(@Req() req: any) {
    return this.rewards.submitApplication(req.user.id, req.user.role);
  }

  @Patch('partner/discount')
  updatePartnerDiscount(@Req() req: any, @Body() body: any) {
    return this.rewards.updatePartnerDiscount(req.user.id, req.user.role, body);
  }

  @Post('partner/scan')
  scan(@Req() req: any, @Body() body: { token: string; latitude?: number; longitude?: number; accuracy?: number }) {
    return this.rewards.scan(req.user.id, req.user.role, body);
  }
}
