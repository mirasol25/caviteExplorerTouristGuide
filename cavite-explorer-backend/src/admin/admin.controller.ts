import { BadRequestException, Body, Controller, Delete, ForbiddenException, Get, Param, Patch, Post, Query, Req, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { randomUUID } from 'crypto';
import { mkdirSync } from 'fs';
import { diskStorage } from 'multer';
import { extname, join } from 'path';
import { AdminGuard, NeonGuard } from '../auth/neon.guard';
import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(NeonGuard, AdminGuard)
export class AdminController {
  constructor(private readonly admin: AdminService) {}
  private requireAdmin(req: any) { if (req.user?.role !== 'admin') throw new ForbiddenException('Administrator access is required'); }
  @Get('users') users(@Req() req: any) { this.requireAdmin(req); return this.admin.users(); }
  @Patch('users/:id') updateUser(@Req() req: any, @Param('id') id: string, @Body() body: any) { this.requireAdmin(req); return this.admin.updateUser(req.user.id, id, body); }
  @Get('invites') invites(@Req() req: any) { this.requireAdmin(req); return this.admin.invites(); }
  @Post('invites') createInvite(@Req() req: any, @Body() body: { email: string; name?: string; role: string }) { this.requireAdmin(req); return this.admin.createInvite(req.user.id, body); }
  @Get('places') places() { return this.admin.places(); }
  @Post('places') createPlace(@Req() req: any, @Body() body: any) { return this.admin.createPlace(req.user.id, req.user.role, req.user.email, body); }
  @Patch('places/:id') updatePlace(@Req() req: any, @Param('id') id: string, @Body() body: any) { if (['published', 'archived'].includes(body.publicationStatus)) this.requireAdmin(req); return this.admin.updatePlace(req.user.id, req.user.email, id, body); }
  @Delete('places/:id') removePlace(@Req() req: any, @Param('id') id: string) { this.requireAdmin(req); return this.admin.removePlace(req.user.id, id); }
  @Post('places/upload-image')
  @UseInterceptors(FileInterceptor('file', {
    storage: diskStorage({
      destination: (_req, _file, callback) => { const directory = join(process.cwd(), 'uploads', 'landmarks'); mkdirSync(directory, { recursive: true }); callback(null, directory); },
      filename: (_req, file, callback) => callback(null, `${randomUUID()}${extname(file.originalname).toLowerCase()}`),
    }),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (_req, file, callback) => callback(null, ['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)),
  }))
  uploadPlaceImage(@UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException('Choose a JPG, PNG, or WebP image up to 5 MB.');
    return { path: `/uploads/landmarks/${file.filename}` };
  }
  @Get('transport/stops') stops() { return this.admin.stops(); }
  @Post('transport/stops') createStop(@Req() req: any, @Body() body: any) { return this.admin.saveStop(req.user.id, body); }
  @Patch('transport/stops/:id') updateStop(@Req() req: any, @Param('id') id: string, @Body() body: any) { return this.admin.saveStop(req.user.id, body, id); }
  @Get('transport/routes') routes() { return this.admin.routes(); }
  @Post('transport/routes') createRoute(@Req() req: any, @Body() body: any) { return this.admin.saveRoute(req.user.id, body); }
  @Patch('transport/routes/:id') updateRoute(@Req() req: any, @Param('id') id: string, @Body() body: any) { return this.admin.saveRoute(req.user.id, body, id); }
  @Delete('transport/routes/:id') removeRoute(@Req() req: any, @Param('id') id: string) { return this.admin.removeRoute(req.user.id, id); }
  @Get('transport/tricycle-terminals') tricycleTerminals() { return this.admin.tricycleTerminals(); }
  @Get('transport/osm-roads') osmRoads(@Query('lat') latitude: string, @Query('lng') longitude: string, @Query('radius') radius: string) { return this.admin.osmRoads(latitude, longitude, radius); }
  @Post('transport/tricycle-terminals') createTricycleTerminal(@Req() req: any, @Body() body: any) { return this.admin.saveTricycleTerminal(req.user.id, body); }
  @Patch('transport/tricycle-terminals/:id') updateTricycleTerminal(@Req() req: any, @Param('id') id: string, @Body() body: any) { return this.admin.saveTricycleTerminal(req.user.id, body, id); }
  @Delete('transport/tricycle-terminals/:id') removeTricycleTerminal(@Req() req: any, @Param('id') id: string) { return this.admin.removeTricycleTerminal(req.user.id, id); }
  @Get('businesses') businesses() { return this.admin.businesses(); }
  @Post('businesses') createBusiness(@Req() req: any, @Body() body: any) { return this.admin.saveBusiness(req.user.id, body); }
  @Patch('businesses/:id') updateBusiness(@Req() req: any, @Param('id') id: string, @Body() body: any) { return this.admin.saveBusiness(req.user.id, body, id); }
  @Get('offers') offers() { return this.admin.offers(); }
  @Post('offers') createOffer(@Req() req: any, @Body() body: any) { return this.admin.saveOffer(req.user.id, body); }
  @Patch('offers/:id') updateOffer(@Req() req: any, @Param('id') id: string, @Body() body: any) { return this.admin.saveOffer(req.user.id, body, id); }
}
