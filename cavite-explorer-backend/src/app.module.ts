import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config'; // <-- 1. Import ConfigModule
import { AuthModule } from './auth/auth.module';
import { PlacesModule } from './places/places.module';
import { PrismaService } from './prisma.service';
import { TripsModule } from './trips/trips.module';
import { AssistantModule } from './assistant/assistant.module';
import { AdminModule } from './admin/admin.module';
import { TransportModule } from './transport/transport.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }), // <-- 2. Initialize it globally
    AuthModule, 
    PlacesModule,
    TripsModule,
    AssistantModule,
    AdminModule,
    TransportModule,
  ],
  controllers: [],
  providers: [PrismaService],
  exports: [PrismaService], // Export so PlacesService can use it
})
export class AppModule {}
