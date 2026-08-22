import { Body, Controller, Param, Post, Req, UseGuards } from '@nestjs/common';
import { NeonGuard } from '../auth/neon.guard';
import { BadgesService } from './badges.service';

@Controller('badges')
@UseGuards(NeonGuard)
export class BadgesController {
  constructor(private readonly badgesService: BadgesService) {}

  @Post(':landmarkId/check-in')
  checkIn(
    @Req() req: any,
    @Param('landmarkId') landmarkId: string,
    @Body() body: any,
  ) {
    return this.badgesService.checkIn(req.user.id, landmarkId, body);
  }
}
