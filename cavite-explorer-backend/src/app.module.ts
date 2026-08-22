import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config'; // <-- 1. Import ConfigModule
import { AuthModule } from './auth/auth.module';
import { PlacesModule } from './places/places.module';
import { PrismaService } from './prisma.service';
import { TripsModule } from './trips/trips.module';
import { AssistantModule } from './assistant/assistant.module';
import { AdminModule } from './admin/admin.module';
import { TransportModule } from './transport/transport.module';
import { BadgesModule } from './badges/badges.module';
import { RewardsModule } from './rewards/rewards.module';
import { StorageModule } from './storage/storage.module';
import { HealthController } from './health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }), // <-- 2. Initialize it globally
    StorageModule,
    AuthModule, 
    PlacesModule,
    TripsModule,
    AssistantModule,
    AdminModule,
    TransportModule,
    BadgesModule,
    RewardsModule,
  ],
  controllers: [HealthController],
  providers: [PrismaService],
  exports: [PrismaService], // Export so PlacesService can use it
})
export class AppModule {}
