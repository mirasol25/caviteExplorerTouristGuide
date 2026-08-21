import { BadRequestException, Controller, Get, Query } from '@nestjs/common';
import { TransportService } from './transport.service';

@Controller('transport')
export class TransportController {
  constructor(private readonly transport: TransportService) {}

  @Get('routes')
  routes() { return this.transport.activeRoutes(); }

  @Get('tricycle-terminals')
  tricycleTerminals() { return this.transport.activeTricycleTerminals(); }

  @Get('routes/match')
  match(
    @Query('startLat') startLat: string, @Query('startLng') startLng: string,
    @Query('destinationLat') destinationLat: string, @Query('destinationLng') destinationLng: string,
  ) {
    const values = [startLat, startLng, destinationLat, destinationLng].map(Number);
    if (values.some((value) => !Number.isFinite(value))) throw new BadRequestException('Valid start and destination coordinates are required.');
    return this.transport.match(values[0], values[1], values[2], values[3]);
  }
}
