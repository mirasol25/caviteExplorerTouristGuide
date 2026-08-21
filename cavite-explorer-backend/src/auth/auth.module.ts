import { Global, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { PrismaService } from '../prisma.service';
import { AdminGuard, FullAdminGuard, NeonGuard } from './neon.guard';

@Global()
@Module({
  imports: [
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: { expiresIn: '30d' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [PrismaService, NeonGuard, AdminGuard, FullAdminGuard],
  exports: [JwtModule, PrismaService, NeonGuard, AdminGuard, FullAdminGuard],
})
export class AuthModule {}
