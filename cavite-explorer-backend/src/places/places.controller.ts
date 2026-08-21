import { Controller, Get, Post, Body, UseGuards } from '@nestjs/common';
import { PlacesService } from './places.service';
import { AdminGuard, NeonGuard } from '../auth/neon.guard';

@Controller('places')
export class PlacesController {
  constructor(private readonly placesService: PlacesService) {}

  @Get()
  getAllPlaces() {
    return this.placesService.findAll();
  }

  // 2. Use the new NeonGuard instead of the old JwtAuthGuard!
  @UseGuards(NeonGuard, AdminGuard)
  @Post()
  addPlace(@Body() placeData: any) {
    console.log('Received new place from Admin UI:', placeData);
    return this.placesService.create(placeData);
  }
}
