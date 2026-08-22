import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

const RETURN_GRACE_SECONDS = 5 * 60;
const MAX_CREDIT_PER_CHECK_IN_SECONDS = 30;

@Injectable()
export class BadgesService {
  constructor(private readonly prisma: PrismaService) {}

  private distanceMeters(
    latitudeA: number,
    longitudeA: number,
    latitudeB: number,
    longitudeB: number,
  ) {
    const radians = (degrees: number) => (degrees * Math.PI) / 180;
    const earthRadius = 6371000;
    const latitudeDelta = radians(latitudeB - latitudeA);
    const longitudeDelta = radians(longitudeB - longitudeA);
    const value =
      Math.sin(latitudeDelta / 2) ** 2 +
      Math.cos(radians(latitudeA)) *
        Math.cos(radians(latitudeB)) *
        Math.sin(longitudeDelta / 2) ** 2;
    return earthRadius * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
  }

  async checkIn(userId: string, landmarkId: string, body: any) {
    const latitude = Number(body.latitude);
    const longitude = Number(body.longitude);
    const accuracy = Math.max(0, Math.min(Number(body.accuracy) || 0, 25));
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      throw new BadRequestException('A valid location is required.');
    }

    const landmark = await this.prisma.landmark.findUnique({
      where: { id: landmarkId },
      select: {
        id: true,
        name: true,
        latitude: true,
        longitude: true,
        badgeName: true,
        badgeImage: true,
        badgeRequiredMinutes: true,
        badgeRadiusMeters: true,
      },
    });
    if (!landmark) throw new NotFoundException('Landmark not found.');

    const existingBadge = await this.prisma.userBadge.findUnique({
      where: { userId_landmarkId: { userId, landmarkId } },
    });
    const requiredSeconds = Math.max(60, landmark.badgeRequiredMinutes * 60);
    const distanceMeters = this.distanceMeters(
      latitude,
      longitude,
      landmark.latitude,
      landmark.longitude,
    );
    const inside = distanceMeters <= landmark.badgeRadiusMeters + accuracy;
    if (existingBadge) {
      return this.response(landmark, {
        inside,
        distanceMeters,
        requiredSeconds,
        accumulatedSeconds: requiredSeconds,
        status: 'COMPLETED',
        earned: true,
        graceRemainingSeconds: 0,
      });
    }

    const now = new Date();
    let visit = await this.prisma.badgeVisit.findUnique({
      where: { userId_landmarkId: { userId, landmarkId } },
    });
    if (!visit) {
      visit = await this.prisma.badgeVisit.create({
        data: {
          userId,
          landmarkId,
          status: inside ? 'ACTIVE' : 'OUTSIDE',
          lastCheckInAt: inside ? now : null,
        },
      });
    }

    let accumulatedSeconds = visit.accumulatedSeconds;
    let status = visit.status;
    let leftAt = visit.leftAt;
    let lastCheckInAt = visit.lastCheckInAt;
    let graceRemainingSeconds = 0;

    if (inside) {
      const graceExpired =
        leftAt != null &&
        (now.getTime() - leftAt.getTime()) / 1000 >= RETURN_GRACE_SECONDS;
      if (graceExpired || status === 'RESET') accumulatedSeconds = 0;

      if (status === 'ACTIVE' && lastCheckInAt != null) {
        const elapsed = Math.floor(
          (now.getTime() - lastCheckInAt.getTime()) / 1000,
        );
        accumulatedSeconds += Math.max(
          0,
          Math.min(elapsed, MAX_CREDIT_PER_CHECK_IN_SECONDS),
        );
      }
      status = 'ACTIVE';
      leftAt = null;
      lastCheckInAt = now;
    } else {
      if (status === 'ACTIVE' || !leftAt) leftAt = now;
      const awaySeconds = Math.floor(
        (now.getTime() - (leftAt?.getTime() ?? now.getTime())) / 1000,
      );
      graceRemainingSeconds = Math.max(0, RETURN_GRACE_SECONDS - awaySeconds);
      if (awaySeconds >= RETURN_GRACE_SECONDS) {
        accumulatedSeconds = 0;
        status = 'RESET';
        lastCheckInAt = null;
      } else {
        status = accumulatedSeconds > 0 ? 'PAUSED' : 'OUTSIDE';
      }
    }

    const earned = accumulatedSeconds >= requiredSeconds;
    if (earned) {
      accumulatedSeconds = requiredSeconds;
      status = 'COMPLETED';
    }

    await this.prisma.$transaction(async (transaction) => {
      await transaction.badgeVisit.update({
        where: { id: visit!.id },
        data: {
          accumulatedSeconds,
          status,
          lastCheckInAt,
          leftAt,
        },
      });
      if (earned) {
        await transaction.userBadge.upsert({
          where: { userId_landmarkId: { userId, landmarkId } },
          create: { userId, landmarkId },
          update: {},
        });
      }
    });

    return this.response(landmark, {
      inside,
      distanceMeters,
      requiredSeconds,
      accumulatedSeconds,
      status,
      earned,
      graceRemainingSeconds,
    });
  }

  private response(landmark: any, state: any) {
    return {
      ...state,
      distanceMeters: Math.round(state.distanceMeters),
      remainingSeconds: Math.max(
        0,
        state.requiredSeconds - state.accumulatedSeconds,
      ),
      verificationRadiusMeters: landmark.badgeRadiusMeters,
      badge: {
        name: landmark.badgeName || `${landmark.name} Explorer`,
        image: landmark.badgeImage,
      },
    };
  }
}
