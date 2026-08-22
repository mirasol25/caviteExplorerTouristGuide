import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { randomUUID } from 'crypto';
import { PrismaService } from '../prisma.service';

@Injectable()
export class RewardsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  private distanceMeters(aLat: number, aLng: number, bLat: number, bLng: number) {
    const radians = (value: number) => (value * Math.PI) / 180;
    const dLat = radians(bLat - aLat);
    const dLng = radians(bLng - aLng);
    const value =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(radians(aLat)) *
        Math.cos(radians(bLat)) *
        Math.sin(dLng / 2) ** 2;
    return 6371000 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
  }

  async badgeCredential(userId: string, userBadgeId: string) {
    const badge = await this.prisma.userBadge.findFirst({
      where: { id: userBadgeId, userId },
      include: { landmark: true },
    });
    if (!badge) throw new NotFoundException('Collected badge not found.');

    const businesses = await this.prisma.partnerBusiness.findMany({
      where: {
        isActive: true,
        approvalStatus: 'approved',
        latitude: { not: null },
        longitude: { not: null },
        offers: {
          some: { isActive: true },
        },
      },
      include: {
        offers: {
          where: { isActive: true },
        },
      },
    });
    const nearby = businesses
      .map((business) => ({
        ...business,
        distanceMeters: Math.round(
          this.distanceMeters(
            badge.landmark.latitude,
            badge.landmark.longitude,
            business.latitude!,
            business.longitude!,
          ),
        ),
      }))
      .filter((business) => business.distanceMeters <= 2500)
      .sort((a, b) => a.distanceMeters - b.distanceMeters);
    const redeemed = await this.prisma.discountRedemption.findMany({
      where: {
        userBadgeId: badge.id,
        businessId: { in: nearby.map((business) => business.id) },
      },
      select: { businessId: true, redeemedAt: true, offerId: true },
    });
    const redeemedByBusiness = new Map(
      redeemed.map((item) => [item.businessId, item]),
    );
    const credential = this.jwt.sign(
      {
        type: 'badge-redemption',
        userBadgeId: badge.id,
        userId: badge.userId,
        landmarkId: badge.landmarkId,
      },
      // The badge UUID stays permanent, while the displayed QR rotates when
      // the user reloads this screen. A short-lived signature limits copied
      // screenshots without changing badge ownership.
      { expiresIn: '15m' },
    );
    return {
      badge: {
        uniqueId: badge.id,
        earnedAt: badge.earnedAt,
        name: badge.landmark.badgeName || `${badge.landmark.name} Explorer`,
        image: badge.landmark.badgeImage,
        color: badge.landmark.badgeColor,
        landmark: {
          id: badge.landmark.id,
          name: badge.landmark.name,
          latitude: badge.landmark.latitude,
          longitude: badge.landmark.longitude,
        },
      },
      credential,
      partners: nearby.map((business) => ({
        ...business,
        claimed: redeemedByBusiness.has(business.id),
        claimedAt: redeemedByBusiness.get(business.id)?.redeemedAt ?? null,
      })),
    };
  }

  async partners() {
    return this.prisma.partnerBusiness.findMany({
      where: { isActive: true, approvalStatus: 'approved' },
      include: {
        offers: {
          where: { isActive: true },
          include: {
            badgeLandmark: {
              select: { id: true, name: true, badgeName: true },
            },
          },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  private async ownedBusiness(userId: string, role: string) {
    if (role !== 'partner') {
      throw new ForbiddenException('A partner account is required.');
    }
    const business = await this.prisma.partnerBusiness.findUnique({
      where: { ownerUserId: userId },
    });
    if (!business || !business.isActive || business.approvalStatus !== 'approved') {
      throw new ForbiddenException('Your partner profile must be approved before accepting badges.');
    }
    return business;
  }

  async dashboard(userId: string, role: string) {
    if (role !== 'partner') throw new ForbiddenException('A partner account is required.');
    const business = await this.prisma.partnerBusiness.findUnique({ where: { ownerUserId: userId } });
    if (!business || !business.isActive || business.approvalStatus !== 'approved') {
      return { business, applicationStatus: business?.approvalStatus ?? 'needs_profile', stats: { total: 0, today: 0 }, recent: [] };
    }
    const [total, today, recent] = await Promise.all([
      this.prisma.discountRedemption.count({ where: { businessId: business.id } }),
      this.prisma.discountRedemption.count({
        where: {
          businessId: business.id,
          redeemedAt: { gte: new Date(new Date().setHours(0, 0, 0, 0)) },
        },
      }),
      this.prisma.discountRedemption.findMany({
        where: { businessId: business.id },
        include: {
          offer: true,
          userBadge: { include: { landmark: true } },
        },
        orderBy: { redeemedAt: 'desc' },
        take: 12,
      }),
    ]);
    return { business, applicationStatus: 'approved', stats: { total, today }, recent };
  }

  async redemptionReport(userId: string, role: string, range: string, requestedPage: number) {
    const business = await this.ownedBusiness(userId, role);
    const now = new Date();
    const startOfDay = new Date(now); startOfDay.setHours(0, 0, 0, 0);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 86400000);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 86400000);
    const selectedStart = range === '7d' ? sevenDaysAgo : range === 'all' ? undefined : thirtyDaysAgo;
    const where = { businessId: business.id, ...(selectedStart ? { redeemedAt: { gte: selectedStart } } : {}) };
    const page = Math.max(1, Number.isFinite(requestedPage) ? Math.floor(requestedPage) : 1);
    const pageSize = 20;
    const [total, today, last7Days, last30Days, rows, grouped] = await Promise.all([
      this.prisma.discountRedemption.count({ where }),
      this.prisma.discountRedemption.count({ where: { businessId: business.id, redeemedAt: { gte: startOfDay } } }),
      this.prisma.discountRedemption.count({ where: { businessId: business.id, redeemedAt: { gte: sevenDaysAgo } } }),
      this.prisma.discountRedemption.count({ where: { businessId: business.id, redeemedAt: { gte: thirtyDaysAgo } } }),
      this.prisma.discountRedemption.findMany({
        where,
        include: {
          offer: { select: { title: true, discountLabel: true } },
          user: { select: { name: true } },
          userBadge: { include: { landmark: { select: { name: true, badgeName: true } } } },
        },
        orderBy: { redeemedAt: 'desc' }, skip: (page - 1) * pageSize, take: pageSize,
      }),
      this.prisma.discountRedemption.groupBy({ by: ['offerId'], where, _count: { _all: true } }),
    ]);
    const offerIds = grouped.map((item) => item.offerId);
    const offers = offerIds.length ? await this.prisma.discountOffer.findMany({ where: { id: { in: offerIds } }, select: { id: true, title: true, discountLabel: true } }) : [];
    const offerById = new Map(offers.map((offer) => [offer.id, offer]));
    return {
      range, page, pageSize, total, pages: Math.max(1, Math.ceil(total / pageSize)),
      summary: { today, last7Days, last30Days, allTime: await this.prisma.discountRedemption.count({ where: { businessId: business.id } }) },
      byOffer: grouped.map((item) => ({ ...offerById.get(item.offerId), count: item._count._all })).sort((a, b) => b.count - a.count),
      rows,
    };
  }

  private requirePartnerRole(role: string) {
    if (role !== 'partner') throw new ForbiddenException('A partner account is required.');
  }

  async application(userId: string, role: string) {
    this.requirePartnerRole(role);
    return this.prisma.partnerBusiness.findUnique({ where: { ownerUserId: userId } });
  }

  async savePartnerLogo(userId: string, role: string, image: string) {
    this.requirePartnerRole(role);
    const existing = await this.prisma.partnerBusiness.findUnique({
      where: { ownerUserId: userId },
      select: { id: true },
    });
    if (!existing) return { image };
    const business = await this.prisma.partnerBusiness.update({
      where: { id: existing.id },
      data: { image },
    });
    return { image: business.image, business };
  }

  async updatePartnerDiscount(userId: string, role: string, data: any) {
    this.requirePartnerRole(role);
    const business = await this.prisma.partnerBusiness.findUnique({
      where: { ownerUserId: userId },
    });
    if (!business || !business.isActive || business.approvalStatus !== 'approved') {
      throw new ForbiddenException('Your partner profile must be approved before editing its reward.');
    }
    const title = String(data.title || '').trim();
    const label = String(data.label || '').trim();
    const description = String(data.description || '').trim();
    if (!title || !label) {
      throw new BadRequestException('Discount title and label are required.');
    }
    if (title.length > 100 || label.length > 50 || description.length > 500) {
      throw new BadRequestException('Keep the title under 100 characters, label under 50, and conditions under 500.');
    }
    return this.prisma.$transaction(async (transaction) => {
      const updated = await transaction.partnerBusiness.update({
        where: { id: business.id },
        data: {
          proposedDiscountTitle: title,
          proposedDiscountLabel: label,
          proposedDiscountDescription: description || null,
        },
      });
      await transaction.discountOffer.updateMany({
        where: { businessId: business.id, isActive: true },
        data: {
          title,
          discountLabel: label,
          description: description || title,
        },
      });
      return updated;
    });
  }

  private applicationData(data: any) {
    const numberOrNull = (value: any) => value === '' || value == null ? null : Number(value);
    const latitude = numberOrNull(data.latitude);
    const longitude = numberOrNull(data.longitude);
    if ((latitude != null && !Number.isFinite(latitude)) || (longitude != null && !Number.isFinite(longitude))) {
      throw new BadRequestException('Choose a valid business location on the map.');
    }
    return {
      name: String(data.name || '').trim(),
      category: String(data.category || '').trim(),
      address: String(data.address || '').trim(),
      municipality: String(data.municipality || '').trim(),
      barangay: data.barangay ? String(data.barangay).trim() : null,
      latitude,
      longitude,
      contact: data.contact ? String(data.contact).trim() : null,
      description: data.description ? String(data.description).trim() : null,
      image: data.image ? String(data.image).trim() : null,
      operatingHours: data.operatingHours ? String(data.operatingHours).trim() : null,
      proposedDiscountTitle: data.proposedDiscountTitle ? String(data.proposedDiscountTitle).trim() : null,
      proposedDiscountDescription: data.proposedDiscountDescription ? String(data.proposedDiscountDescription).trim() : null,
      proposedDiscountLabel: data.proposedDiscountLabel ? String(data.proposedDiscountLabel).trim() : null,
      proposedBadgeLandmarkId: data.proposedBadgeLandmarkId ? String(data.proposedBadgeLandmarkId).trim() : null,
    };
  }

  private async nearbyBadgeLandmarks(latitude: number, longitude: number) {
    const landmarks = await this.prisma.landmark.findMany({
      select: { id: true, name: true, badgeName: true, latitude: true, longitude: true },
    });
    return landmarks
      .map((landmark) => ({
        ...landmark,
        distanceMeters: Math.round(this.distanceMeters(latitude, longitude, landmark.latitude, landmark.longitude)),
      }))
      .filter((landmark) => landmark.distanceMeters <= 2500)
      .sort((a, b) => a.distanceMeters - b.distanceMeters);
  }

  async saveApplication(userId: string, role: string, data: any) {
    this.requirePartnerRole(role);
    const normalized = this.applicationData(data);
    const existing = await this.prisma.partnerBusiness.findUnique({ where: { ownerUserId: userId } });
    const resubmitted = existing && ['approved', 'pending', 'changes_requested', 'rejected'].includes(existing.approvalStatus);
    return this.prisma.partnerBusiness.upsert({
      where: { ownerUserId: userId },
      create: { ...normalized, ownerUserId: userId, approvalStatus: 'draft', isActive: false },
      update: { ...normalized, ...(resubmitted ? { approvalStatus: 'draft', isActive: false, rejectionReason: null } : {}) },
    });
  }

  async submitApplication(userId: string, role: string) {
    this.requirePartnerRole(role);
    const business = await this.prisma.partnerBusiness.findUnique({ where: { ownerUserId: userId } });
    if (!business) throw new BadRequestException('Complete your business profile first.');
    const required = [business.name, business.category, business.address, business.municipality, business.contact, business.proposedDiscountTitle, business.proposedDiscountLabel];
    if (required.some((value) => !String(value || '').trim()) || business.latitude == null || business.longitude == null) {
      throw new BadRequestException('Complete the business, location, contact, and discount fields before submitting.');
    }
    const nearbyLandmarks = await this.nearbyBadgeLandmarks(business.latitude, business.longitude);
    if (!nearbyLandmarks.length) throw new BadRequestException('This business is not within 2.5 km of a landmark badge. Adjust the business pin before submitting.');
    return this.prisma.partnerBusiness.update({
      where: { id: business.id },
      data: { proposedBadgeLandmarkId: nearbyLandmarks[0].id, approvalStatus: 'pending', submittedAt: new Date(), isActive: false, rejectionReason: null },
    });
  }

  async scan(userId: string, role: string, input: { token: string; latitude?: number; longitude?: number; accuracy?: number }) {
    const business = await this.ownedBusiness(userId, role);
    const token = input.token;
    if (!token?.trim()) throw new BadRequestException('Scan a valid badge QR code.');
    let payload: any;
    try {
      payload = await this.jwt.verifyAsync(token.trim());
    } catch {
      throw new BadRequestException('This badge QR code is invalid or expired.');
    }
    if (payload.type !== 'badge-redemption' || !payload.userBadgeId) {
      throw new BadRequestException('This is not a Cavite Explorer badge QR code.');
    }
    const badge = await this.prisma.userBadge.findUnique({
      where: { id: payload.userBadgeId },
      include: { landmark: true },
    });
    if (!badge || badge.userId !== payload.userId) {
      throw new BadRequestException('The collected badge could not be verified.');
    }
    if (business.latitude == null || business.longitude == null) {
      throw new BadRequestException('The partner location must be pinned before accepting badges.');
    }
    const distance = this.distanceMeters(
      badge.landmark.latitude,
      badge.landmark.longitude,
      business.latitude,
      business.longitude,
    );
    if (distance > 2500) {
      throw new ForbiddenException('This approved partner is outside the badge landmark’s 2.5 km redemption area.');
    }
    const scanLatitude = Number(input.latitude);
    const scanLongitude = Number(input.longitude);
    if (!Number.isFinite(scanLatitude) || !Number.isFinite(scanLongitude)) {
      throw new BadRequestException('Enable precise location before scanning a badge.');
    }
    const liveDistance = this.distanceMeters(badge.landmark.latitude, badge.landmark.longitude, scanLatitude, scanLongitude);
    if (liveDistance > 2500) {
      throw new ForbiddenException('Badge scanning is only available within 2.5 km of its landmark.');
    }
    const businessDistance = this.distanceMeters(business.latitude, business.longitude, scanLatitude, scanLongitude);
    if (businessDistance > 300) {
      throw new ForbiddenException('Scan this badge at the approved partner location.');
    }
    let offer = await this.prisma.discountOffer.findFirst({
      where: {
        businessId: business.id,
        isActive: true,
        OR: [{ badgeLandmarkId: badge.landmarkId }, { badgeLandmarkId: null }],
        AND: [
          { OR: [{ startsAt: null }, { startsAt: { lte: new Date() } }] },
          { OR: [{ endsAt: null }, { endsAt: { gte: new Date() } }] },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
    // Partner badge eligibility is determined by the verified 2.5 km business
    // radius above. Older partner offers may still reference one legacy badge,
    // so use the active business offer when no badge-specific row exists.
    offer ??= await this.prisma.discountOffer.findFirst({
      where: {
        businessId: business.id,
        isActive: true,
        AND: [
          { OR: [{ startsAt: null }, { startsAt: { lte: new Date() } }] },
          { OR: [{ endsAt: null }, { endsAt: { gte: new Date() } }] },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!offer) throw new NotFoundException('No active reward accepts this badge.');

    try {
      const redemption = await this.prisma.discountRedemption.create({
        data: {
          offerId: offer.id,
          userId: badge.userId,
          userBadgeId: badge.id,
          businessId: business.id,
          code: randomUUID(),
          status: 'redeemed',
          redeemedAt: new Date(),
        },
      });
      return {
        accepted: true,
        message: `${offer.discountLabel} successfully redeemed.`,
        redemption,
        offer,
        landmark: badge.landmark.name,
      };
    } catch (error: any) {
      if (error?.code === 'P2002') {
        throw new ConflictException(
          'This badge reward has already been claimed at this partner.',
        );
      }
      throw error;
    }
  }
}
