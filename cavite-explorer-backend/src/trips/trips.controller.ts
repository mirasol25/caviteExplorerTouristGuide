import { Controller, Post, Get, Delete, Patch, Body, Param, Req, UseGuards } from '@nestjs/common';
import { TripsService } from './trips.service';
import { NeonGuard } from '../auth/neon.guard'; // Adjust path to your guard

@Controller('trips')
@UseGuards(NeonGuard) // Protects ALL endpoints in this controller
export class TripsController {
  constructor(private readonly tripsService: TripsService) {}

  @Post('save')
  async saveTrip(@Req() req: any, @Body() body: any) {
    // Note: Adjust `req.user.id` if your NeonGuard attaches the user ID differently (e.g., req.user.sub)
    const userId = req.user.id; 
    return this.tripsService.saveTrip(userId, body);
  }

  @Get()
  async getMyTrips(@Req() req: any) {
    const userId = req.user.id;
    return this.tripsService.getUserTrips(userId);
  }

  @Patch(':id/progress')
  async updateProgress(@Req() req: any, @Param('id') tripId: string, @Body() body: any) {
    return this.tripsService.updateTripProgress(req.user.id, tripId, body);
  }

  @Delete(':id')
  async deleteTrip(@Req() req: any, @Param('id') tripId: string) {
    const userId = req.user.id;
    return this.tripsService.deleteTrip(tripId, userId);
  }
}
