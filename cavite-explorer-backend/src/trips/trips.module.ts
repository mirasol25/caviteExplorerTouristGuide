import { Module } from '@nestjs/common';
import { TripsController } from './trips.controller';
import { TripsService } from './trips.service';
import { PrismaService } from '../prisma.service'; // Adjust path if necessary

@Module({
  // Imports are ONLY for other Modules (e.g., HttpModule). Leave this empty or remove it.
  imports: [], 
  
  controllers: [TripsController],
  
  // Providers are for Services. Both TripsService and PrismaService go here!
  providers: [TripsService, PrismaService], 
})
export class TripsModule {}