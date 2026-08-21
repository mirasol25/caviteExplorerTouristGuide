import { Injectable, CanActivate, ExecutionContext, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma.service';

@Injectable()
export class NeonGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid Authorization header');
    }

    // Grab the actual token string
    const token = authHeader.split(' ')[1];

    try {
      // Decoding alone is unsafe: verify both the signature and expiration.
      const decodedPayload = await this.jwtService.verifyAsync(token);
      const userId = decodedPayload.sub;
      if (!userId) throw new UnauthorizedException('Invalid token subject');
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, email: true, role: true, isActive: true },
      });
      if (!user) throw new UnauthorizedException('User no longer exists');
      if (!user.isActive) throw new ForbiddenException('This account has been disabled');

      request.user = {
        id: user.id,
        email: user.email,
        role: user.role,
      };

      return true; 
    } catch (error) {
      console.error("NeonGuard Error decoding token:", error);
      if (error instanceof ForbiddenException || error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('Invalid token or failed to authenticate.');
    }
  }
}

@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const user = context.switchToHttp().getRequest().user;
    if (!['admin', 'editor'].includes(user?.role)) throw new ForbiddenException('Editor or administrator access is required');
    return true;
  }
}

@Injectable()
export class FullAdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const user = context.switchToHttp().getRequest().user;
    if (user?.role !== 'admin') throw new ForbiddenException('Administrator access is required');
    return true;
  }
}
