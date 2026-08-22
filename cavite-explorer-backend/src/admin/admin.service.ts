import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { createHash, randomBytes } from 'crypto';
import * as https from 'https';
import * as nodemailer from 'nodemailer';
import { PrismaService } from '../prisma.service';

@Injectable()
export class AdminService {
  private readonly osmRoadCache = new Map<string, { expiresAt: number; roads: any[] }>();
  constructor(private readonly prisma: PrismaService) {}

  private getJson(url: string, timeoutMs = 22000): Promise<any | null> {
    return new Promise((resolve) => {
      let settled = false;
      const finish = (value: any | null) => { if (!settled) { settled = true; resolve(value); } };
      const request = https.get(url, {
        family: 4,
        headers: { Accept: 'application/json', 'User-Agent': 'CaviteExplorerAdmin/1.0' },
      }, (response) => {
        if (response.statusCode !== 200) { response.resume(); finish(null); return; }
        const chunks: Buffer[] = [];
        let size = 0;
        response.on('data', (chunk: Buffer) => {
          size += chunk.length;
          if (size > 50 * 1024 * 1024) request.destroy();
          else chunks.push(chunk);
        });
        response.on('end', () => {
          try { finish(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
          catch { finish(null); }
        });
      });
      request.setTimeout(timeoutMs, () => request.destroy());
      request.on('error', () => finish(null));
    });
  }

  private async audit(actorId: string, action: string, entity: string, entityId: string, details?: unknown) {
    await this.prisma.auditLog.create({ data: { actorId, action, entity, entityId, details: details as any } });
  }

  users() {
    return this.prisma.user.findMany({
      select: { id: true, name: true, email: true, role: true, isActive: true, createdAt: true, _count: { select: { trips: true, badges: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async analytics() {
    const staleBefore = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const [
      visitors, activeVisitors, landmarks, badges, completedTrips, routes,
      staleRoutes, partners, redemptions, recentRedemptions, reviews,
      topLandmarks, topPartners,
    ] = await Promise.all([
      this.prisma.user.count({ where: { role: 'user' } }),
      this.prisma.user.count({ where: { role: 'user', isActive: true } }),
      this.prisma.landmark.count({ where: { publicationStatus: 'published' } }),
      this.prisma.userBadge.count(),
      this.prisma.tripPlan.count({ where: { status: 'COMPLETED' } }),
      this.prisma.transportRoute.count({ where: { isActive: true } }),
      this.prisma.transportRoute.findMany({
        where: { isActive: true, OR: [{ lastVerifiedAt: null }, { lastVerifiedAt: { lt: staleBefore } }] },
        select: { id: true, name: true, mode: true, lastVerifiedAt: true, updatedAt: true },
        orderBy: { lastVerifiedAt: 'asc' }, take: 20,
      }),
      this.prisma.partnerBusiness.count({ where: { isActive: true, approvalStatus: 'approved' } }),
      this.prisma.discountRedemption.count(),
      this.prisma.discountRedemption.count({ where: { redeemedAt: { gte: thirtyDaysAgo } } }),
      this.prisma.landmarkCommunityPost.count(),
      this.prisma.landmark.findMany({
        where: { publicationStatus: 'published' },
        select: { id: true, name: true, _count: { select: { earnedBy: true, communityPosts: true } } },
        orderBy: { earnedBy: { _count: 'desc' } }, take: 5,
      }),
      this.prisma.partnerBusiness.findMany({
        where: { approvalStatus: 'approved' },
        select: { id: true, name: true, _count: { select: { redemptions: true } } },
        orderBy: { redemptions: { _count: 'desc' } }, take: 5,
      }),
    ]);
    return {
      generatedAt: new Date(), staleAfterDays: 90,
      totals: { visitors, activeVisitors, landmarks, badges, completedTrips, routes, partners, redemptions, recentRedemptions, reviews },
      staleRoutes,
      topLandmarks: topLandmarks.map((item) => ({ id: item.id, name: item.name, badges: item._count.earnedBy, reviews: item._count.communityPosts })),
      topPartners: topPartners.map((item) => ({ id: item.id, name: item.name, redemptions: item._count.redemptions })),
    };
  }

  async updateUser(actorId: string, userId: string, data: { role?: string; isActive?: boolean }) {
    if (actorId === userId && data.role !== undefined) {
      throw new ForbiddenException('You cannot change your own account role. Ask another administrator.');
    }
    if (actorId === userId && data.isActive === false) {
      throw new ForbiddenException('You cannot disable your own account. Ask another administrator.');
    }
    const user = await this.prisma.user.update({ where: { id: userId }, data: { role: data.role, isActive: data.isActive } });
    await this.audit(actorId, 'update', 'user', userId, data);
    return user;
  }

  invites() {
    return this.prisma.adminInvite.findMany({
      select: { id: true, email: true, name: true, role: true, expiresAt: true, acceptedAt: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createInvite(actorId: string, data: { email: string; name?: string; role: string }) {
    const email = data.email.trim().toLowerCase();
    if (!email || !['admin', 'editor', 'partner'].includes(data.role)) {
      throw new BadRequestException('An email and a valid invited role are required.');
    }
    const token = randomBytes(32).toString('base64url');
    const tokenHash = createHash('sha256').update(token).digest('hex');
    const invite = await this.prisma.adminInvite.upsert({
      where: { email },
      update: { name: data.name?.trim() || null, role: data.role, tokenHash, expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), acceptedAt: null, invitedById: actorId },
      create: { email, name: data.name?.trim() || null, role: data.role, tokenHash, expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), invitedById: actorId },
    });
    await this.audit(actorId, 'invite', 'admin_invite', invite.id, { email, role: data.role });
    const adminUrl = process.env.ADMIN_INVITE_WEB_URL || process.env.ADMIN_WEB_URL || process.env.FRONTEND_URL || 'http://localhost:3001';
    const partnerUrl = process.env.PARTNER_INVITE_WEB_URL || `${process.env.MOBILE_BACKEND_URL || process.env.BACKEND_URL || 'http://10.0.2.2:3000'}/auth/partner-invite`;
    const inviteBaseUrl = data.role === 'partner' ? partnerUrl : `${adminUrl.replace(/\/$/, '')}/accept-invite`;
    const inviteUrl = `${inviteBaseUrl}${inviteBaseUrl.includes('?') ? '&' : '?'}token=${encodeURIComponent(token)}`;
    const smtpHost = process.env.SMTP_HOST;
    const smtpUser = process.env.SMTP_USER;
    const smtpPassword = process.env.SMTP_PASSWORD;
    const smtpFrom = process.env.SMTP_FROM || smtpUser;
    if (!smtpHost || !smtpUser || !smtpPassword || !smtpFrom) {
      throw new BadRequestException('Invitation was created, but email delivery is not configured. Add SMTP settings to the backend .env.');
    }
    const transporter = nodemailer.createTransport({ host: smtpHost, port: Number(process.env.SMTP_PORT || 465), secure: (process.env.SMTP_SECURE || 'true') === 'true', auth: { user: smtpUser, pass: smtpPassword } });
    const delivery = await transporter.sendMail({
      from: smtpFrom,
      to: email,
      subject: `You are invited to Cavite Explorer as ${data.role}`,
      text: `You have been invited to Cavite Explorer as ${data.role}. Open this secure invitation link to continue. It expires in 7 days:\n\n${inviteUrl}`,
      html: `<div style="font-family:Arial,sans-serif;color:#202520;line-height:1.5;max-width:560px"><p>You have been invited to <strong>Cavite Explorer</strong> as <strong>${data.role}</strong>.</p><p style="margin:24px 0"><a href="${inviteUrl}" style="display:inline-block;background:#176a50;color:#ffffff;text-decoration:none;font-weight:700;padding:13px 20px;border-radius:10px">Open secure invitation</a></p><p style="font-size:13px;color:#66706a">If the button does not open, use this link:<br><a href="${inviteUrl}" style="color:#176a50;word-break:break-all">${inviteUrl}</a></p><p>This secure invitation expires in 7 days.</p></div>`,
    });
    const accepted = (delivery.accepted || []).map(String);
    const rejected = (delivery.rejected || []).map(String);
    if (!accepted.some((recipient) => recipient.toLowerCase() === email)) {
      throw new BadRequestException(`The invitation was created, but the email provider did not accept delivery to ${email}.`);
    }
    console.log(`Invitation email accepted by SMTP: role=${data.role}; recipient=${email}; messageId=${delivery.messageId}`);
    return {
      invite,
      inviteUrl,
      emailed: true,
      delivery: { accepted, rejected, messageId: delivery.messageId },
    };
  }

  places() { return this.prisma.landmark.findMany({ orderBy: { name: 'asc' } }); }
  private badgeDefaults(name: unknown, category: unknown) {
    const landmarkName = String(name || 'Landmark').trim() || 'Landmark';
    const placeType = String(category || '').toLowerCase();
    const icon = placeType.includes('church') || placeType.includes('religious')
      ? 'church'
      : placeType.includes('museum')
        ? 'museum'
        : placeType.includes('park') || placeType.includes('nature')
          ? 'nature'
          : placeType.includes('monument') || placeType.includes('shrine')
            ? 'monument'
            : placeType.includes('plaza')
              ? 'plaza'
              : 'landmark';
    const palette = ['#176A50', '#1D5B8F', '#9A5A20', '#7A3E8E', '#B5473A', '#2F7A63'];
    let hash = 0;
    for (const character of landmarkName) hash = ((hash << 5) - hash + character.charCodeAt(0)) | 0;
    return {
      name: `${landmarkName} Explorer`,
      description: `Earned after a verified visit to ${landmarkName}.`,
      icon,
      color: palette[Math.abs(hash) % palette.length],
    };
  }
  private landmarkData(data: any) {
    const list = (value: unknown) => Array.isArray(value) ? value.map(String).filter(Boolean) : String(value || '').split('\n').map((item) => item.trim()).filter(Boolean);
    const normalized: any = { ...data };
    if (data.latitude !== undefined) normalized.latitude = Number(data.latitude);
    if (data.longitude !== undefined) normalized.longitude = Number(data.longitude);
    if (data.images !== undefined) normalized.images = Array.isArray(data.images) ? data.images : [];
    if (data.isAlwaysOpen !== undefined) normalized.isAlwaysOpen = data.isAlwaysOpen === true || data.isAlwaysOpen === 'true';
    if (data.isFreeEntrance !== undefined) normalized.isFreeEntrance = data.isFreeEntrance === true || data.isFreeEntrance === 'true';
    if (data.badgeRequiredMinutes !== undefined) normalized.badgeRequiredMinutes = Math.max(1, Math.round(Number(data.badgeRequiredMinutes) || 30));
    if (data.badgeRadiusMeters !== undefined) normalized.badgeRadiusMeters = Math.max(20, Number(data.badgeRadiusMeters) || 100);
    if (data.badgeColor !== undefined && !/^#[0-9a-f]{6}$/i.test(String(data.badgeColor))) delete normalized.badgeColor;
    const badge = this.badgeDefaults(data.name, data.category);
    if (data.badgeName !== undefined) normalized.badgeName = String(data.badgeName || badge.name).trim();
    else if (data.name !== undefined) normalized.badgeName = badge.name;
    if (data.badgeDescription !== undefined) normalized.badgeDescription = String(data.badgeDescription || badge.description).trim();
    else if (data.name !== undefined) normalized.badgeDescription = badge.description;
    if (data.badgeIcon !== undefined) normalized.badgeIcon = String(data.badgeIcon || badge.icon);
    else if (data.name !== undefined) normalized.badgeIcon = badge.icon;
    if (data.badgeColor === undefined && data.name !== undefined) normalized.badgeColor = badge.color;
    for (const field of ['importantPeople', 'importantEvents', 'interestingFacts', 'informationSources']) if (data[field] !== undefined) normalized[field] = list(data[field]);
    return normalized;
  }
  async createPlace(actorId: string, actorRole: string, actorEmail: string, data: any) {
    const requestedStatus = String(data.publicationStatus || 'draft');
    const publicationStatus = actorRole === 'admin' && ['draft', 'for_review', 'published'].includes(requestedStatus) ? requestedStatus : requestedStatus === 'for_review' ? 'for_review' : 'draft';
    const placeData = this.landmarkData({ ...data, publicationStatus });
    if (publicationStatus === 'published') Object.assign(placeData, { verifiedBy: actorEmail, lastVerifiedAt: new Date(), publishedAt: new Date() });
    const place = await this.prisma.landmark.create({ data: placeData });
    await this.audit(actorId, 'create', 'landmark', place.id, data);
    return place;
  }
  async updatePlace(actorId: string, actorEmail: string, id: string, data: any) {
    const placeData = this.landmarkData(data);
    if (data.publicationStatus === 'published') Object.assign(placeData, { verifiedBy: actorEmail, lastVerifiedAt: new Date(), publishedAt: new Date() });
    const place = await this.prisma.landmark.update({ where: { id }, data: placeData });
    await this.audit(actorId, 'update', 'landmark', id, data);
    return place;
  }
  async removePlace(actorId: string, id: string) {
    const dependencies = await this.prisma.landmark.findUnique({
      where: { id },
      select: {
        _count: { select: { trips: true, earnedBy: true, offers: true } },
      },
    });
    if (!dependencies) throw new BadRequestException('Landmark not found.');

    const usage = dependencies._count;
    const isReferenced = usage.trips > 0 || usage.earnedBy > 0 || usage.offers > 0;
    if (isReferenced) {
      const place = await this.prisma.landmark.update({
        where: { id },
        data: { publicationStatus: 'archived' },
      });
      await this.audit(actorId, 'archive', 'landmark', id, usage);
      return { deleted: false, archived: true, place, usage };
    }

    await this.prisma.landmark.delete({ where: { id } });
    await this.audit(actorId, 'delete', 'landmark', id);
    return { deleted: true, archived: false, usage };
  }

  stops() { return this.prisma.transportStop.findMany({ orderBy: { name: 'asc' } }); }
  async saveStop(actorId: string, data: any, id?: string) {
    const stop = id
      ? await this.prisma.transportStop.update({ where: { id }, data: { ...data, latitude: Number(data.latitude), longitude: Number(data.longitude) } })
      : await this.prisma.transportStop.create({ data: { ...data, latitude: Number(data.latitude), longitude: Number(data.longitude) } });
    await this.audit(actorId, id ? 'update' : 'create', 'transport_stop', stop.id, data);
    return stop;
  }

  routes() { return this.prisma.transportRoute.findMany({ include: { stops: { include: { stop: true }, orderBy: { sequence: 'asc' } } }, orderBy: { name: 'asc' } }); }
  async verifyRoute(actorId: string, id: string) {
    const route = await this.prisma.transportRoute.update({ where: { id }, data: { lastVerifiedAt: new Date() } });
    await this.audit(actorId, 'verify', 'transport_route', id, { lastVerifiedAt: route.lastVerifiedAt });
    return route;
  }
  async saveRoute(actorId: string, data: any, id?: string) {
    const numberOrNull = (value: unknown) => value === '' || value === undefined || value === null ? null : Number(value);
    const normalizeGeometry = (value: unknown) => {
      if (!Array.isArray(value)) return null;
      const points = value
        .filter((point) => Array.isArray(point) && point.length >= 2)
        .map((point) => [Number(point[0]), Number(point[1])])
        .filter((point) => Number.isFinite(point[0]) && Number.isFinite(point[1]));
      return points.length >= 2 ? points : null;
    };
    const normalizeMapItems = (value: unknown, kind: 'road' | 'access') => {
      if (!Array.isArray(value)) return null;
      return value.map((item: any) => ({
        point: Array.isArray(item?.point) ? [Number(item.point[0]), Number(item.point[1])] : null,
        name: String(item?.name || '').trim(),
        ...(kind === 'access' ? { roadName: String(item?.roadName || '').trim(), type: item?.type === 'transfer' ? 'transfer' : 'boarding' } : {}),
      })).filter((item) => item.point && item.point.every(Number.isFinite) && (kind === 'access' || item.name));
    };
    const outboundGeometry = normalizeGeometry(data.outboundGeometry);
    const inboundGeometry = normalizeGeometry(data.inboundGeometry);
    const hasMappedRoute = data.originName || data.destinationName || outboundGeometry || inboundGeometry;
    if (hasMappedRoute && (!data.originName || !data.destinationName || !outboundGeometry)) {
      throw new BadRequestException('Route name, both terminal names, and a selected outbound map path are required.');
    }
    const coordinates = [data.originLatitude, data.originLongitude, data.destinationLatitude, data.destinationLongitude].map(numberOrNull);
    if (hasMappedRoute && coordinates.some((value) => value === null || !Number.isFinite(value))) {
      throw new BadRequestException('Place both the starting and ending pins on the map.');
    }
    const baseFare = numberOrNull(data.baseFare);
    if (baseFare === null || baseFare < 0) throw new BadRequestException('Enter a valid base fare for this route.');
    const baseDistanceKm = numberOrNull(data.baseDistanceKm);
    const additionalFarePerKm = numberOrNull(data.additionalFarePerKm);
    if (baseDistanceKm === null || baseDistanceKm <= 0) throw new BadRequestException('Enter a valid included distance.');
    if (additionalFarePerKm === null || additionalFarePerKm < 0) throw new BadRequestException('Enter a valid additional fare per kilometer.');
    const routeData = {
      name: String(data.name || '').trim(),
      mode: String(data.mode || '').trim(),
      outboundSignboard: data.outboundSignboard ? String(data.outboundSignboard).trim() : null,
      inboundSignboard: data.inboundSignboard ? String(data.inboundSignboard).trim() : null,
      originName: data.originName ? String(data.originName).trim() : null,
      originMunicipality: data.originMunicipality ? String(data.originMunicipality).trim() : null,
      originRoadName: data.originRoadName ? String(data.originRoadName).trim() : null,
      originLatitude: coordinates[0], originLongitude: coordinates[1],
      destinationName: data.destinationName ? String(data.destinationName).trim() : null,
      destinationMunicipality: data.destinationMunicipality ? String(data.destinationMunicipality).trim() : null,
      destinationRoadName: data.destinationRoadName ? String(data.destinationRoadName).trim() : null,
      destinationLatitude: coordinates[2], destinationLongitude: coordinates[3],
      outboundGeometry: outboundGeometry ?? Prisma.DbNull,
      inboundGeometry: inboundGeometry ?? Prisma.DbNull,
      outboundRoads: Array.isArray(data.outboundRoads) ? data.outboundRoads.map(String).filter(Boolean) : [],
      inboundRoads: Array.isArray(data.inboundRoads) ? data.inboundRoads.map(String).filter(Boolean) : [],
      outboundRoadAnchors: normalizeMapItems(data.outboundRoadAnchors, 'road') ?? Prisma.DbNull,
      inboundRoadAnchors: normalizeMapItems(data.inboundRoadAnchors, 'road') ?? Prisma.DbNull,
      outboundAccessPoints: normalizeMapItems(data.outboundAccessPoints, 'access') ?? Prisma.DbNull,
      inboundAccessPoints: normalizeMapItems(data.inboundAccessPoints, 'access') ?? Prisma.DbNull,
      isBidirectional: data.isBidirectional !== false,
      baseFare,
      baseDistanceKm,
      additionalFarePerKm,
      fareNotes: data.fareNotes ? String(data.fareNotes).trim() : null,
      notes: data.notes ? String(data.notes).trim() : null,
      isActive: data.isActive !== false,
      lastVerifiedAt: hasMappedRoute ? new Date() : null,
    };
    if (!routeData.name || !routeData.mode) throw new BadRequestException('Route name and transport type are required.');
    const route = id ? await this.prisma.transportRoute.update({ where: { id }, data: routeData }) : await this.prisma.transportRoute.create({ data: routeData });
    await this.audit(actorId, id ? 'update' : 'create', 'transport_route', route.id, routeData);
    return route;
  }

  async removeRoute(actorId: string, id: string) {
    const route = await this.prisma.transportRoute.findUnique({ where: { id }, select: { id: true, name: true } });
    if (!route) throw new BadRequestException('Transport route not found.');
    await this.prisma.transportRoute.delete({ where: { id } });
    await this.audit(actorId, 'delete', 'transport_route', id, { name: route.name });
    return { deleted: true, route };
  }

  tricycleTerminals() { return this.prisma.tricycleTerminal.findMany({ orderBy: { name: 'asc' } }); }
  async osmRoads(latitudeValue: unknown, longitudeValue: unknown, radiusValue: unknown) {
    const latitude = Number(latitudeValue);
    const longitude = Number(longitudeValue);
    const radius = Math.max(100, Math.min(5000, Number(radiusValue)));
    if (![latitude, longitude, radius].every(Number.isFinite) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) throw new BadRequestException('Enter a valid terminal location and coverage radius.');
    const cacheKey = `${latitude.toFixed(4)}:${longitude.toFixed(4)}:${Math.round(radius / 100)}`;
    const cached = this.osmRoadCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) return { roads: cached.roads, provider: 'cache' };
    const providers = [
      'https://overpass-api.de/api/interpreter',
      'https://lz4.overpass-api.de/api/interpreter',
      'https://z.overpass-api.de/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ];
    const tileRadius = radius;
    const tileCenters = [{ latitude, longitude }];
    const fetchTile = async (center: { latitude: number; longitude: number }) => {
      const query = `[out:json][timeout:18];way(around:${Math.round(tileRadius)},${center.latitude},${center.longitude})["highway"]["highway"!~"footway|path|cycleway|steps|pedestrian|bridleway|construction|proposed|motorway|motorway_link"]["access"!="no"];out geom qt;`;
      for (const provider of providers) {
        try {
          const result = await this.getJson(`${provider}?data=${encodeURIComponent(query)}`);
          if (!result) continue;
          return (Array.isArray(result?.elements) ? result.elements : []).map((way: any) => ({
            id: way.id,
            name: String(way?.tags?.name || ''),
            highway: String(way?.tags?.highway || ''),
            geometry: (Array.isArray(way?.geometry) ? way.geometry : [])
              .map((point: any) => [Number(point?.lat), Number(point?.lon)])
              .filter((point: number[]) => point.length >= 2 && point.every(Number.isFinite)),
          })).filter((road: any) => road.geometry.length >= 2);
        } catch {
          // Try the next provider when one public Overpass instance is busy.
        }
      }
      return [];
    };
    const roadsById = new Map<number, any>();
    // Keep concurrency low to respect public Overpass capacity while ensuring
    // a dense municipality does not become one oversized, timeout-prone query.
    for (let index = 0; index < tileCenters.length; index += 3) {
      const tileRoads = await Promise.all(tileCenters.slice(index, index + 3).map(fetchTile));
      tileRoads.flat().forEach((road) => roadsById.set(road.id, road));
    }
    const roads = [...roadsById.values()];
    if (roads.length) {
      this.osmRoadCache.set(cacheKey, { expiresAt: Date.now() + 5 * 60 * 1000, roads });
      return { roads, provider: tileCenters.length === 1 ? 'overpass' : `${tileCenters.length} overpass tiles` };
    }
    throw new BadRequestException('OpenStreetMap road data is temporarily unavailable. Try reloading the roads in a moment.');
  }
  async saveTricycleTerminal(actorId: string, data: any, id?: string) {
    const numberOrNull = (value: unknown) => value === '' || value === undefined || value === null ? null : Number(value);
    const latitude = numberOrNull(data.latitude); const longitude = numberOrNull(data.longitude);
    const coverageRadiusKm = numberOrNull(data.coverageRadiusKm);
    if (!String(data.name || '').trim() || !String(data.municipality || '').trim()) throw new BadRequestException('Terminal name and municipality are required.');
    if (![latitude, longitude, coverageRadiusKm].every((value) => value !== null && Number.isFinite(value)) || Number(coverageRadiusKm) <= 0) throw new BadRequestException('Pin the terminal and enter a valid coverage radius.');
    const fareMin = numberOrNull(data.fareMin); const fareMax = numberOrNull(data.fareMax);
    if ((fareMin !== null && fareMin < 0) || (fareMax !== null && fareMax < 0) || (fareMin !== null && fareMax !== null && fareMax < fareMin)) throw new BadRequestException('Enter a valid estimated fare range.');
    let rawAccessPaths: unknown = data.accessPaths ?? [];
    if (typeof rawAccessPaths === 'string') {
      try { rawAccessPaths = JSON.parse(rawAccessPaths); }
      catch { throw new BadRequestException('The verified tricycle connectors are invalid.'); }
    }
    if (!Array.isArray(rawAccessPaths) || rawAccessPaths.length > 25) throw new BadRequestException('Add no more than 25 verified connectors per terminal.');
    const terminalPoint: [number, number] = [Number(latitude), Number(longitude)];
    const distance = (first: [number, number], second: [number, number]) => {
      const radians = (degrees: number) => degrees * Math.PI / 180;
      const earthRadius = 6371000;
      const deltaLatitude = radians(second[0] - first[0]);
      const deltaLongitude = radians(second[1] - first[1]);
      const value = Math.sin(deltaLatitude / 2) ** 2 + Math.cos(radians(first[0])) * Math.cos(radians(second[0])) * Math.sin(deltaLongitude / 2) ** 2;
      return 2 * earthRadius * Math.asin(Math.sqrt(value));
    };
    const accessPaths = rawAccessPaths.map((rawPath: any) => {
      if (!Array.isArray(rawPath) || rawPath.length < 2 || rawPath.length > 300) throw new BadRequestException('Every connector needs between 2 and 300 map points.');
      return rawPath.map((rawPoint: any) => {
        if (!Array.isArray(rawPoint) || rawPoint.length < 2) throw new BadRequestException('A connector contains an invalid point.');
        const point: [number, number] = [Number(rawPoint[0]), Number(rawPoint[1])];
        if (!point.every(Number.isFinite)) throw new BadRequestException('A connector contains invalid coordinates.');
        if (distance(terminalPoint, point) > Number(coverageRadiusKm) * 1000 + 100) throw new BadRequestException('Verified connectors must remain inside the terminal coverage radius.');
        return point;
      });
    });
    const operatingHours = data.operatingHours ? String(data.operatingHours).trim() : (data.operatingStart && data.operatingEnd ? `${String(data.operatingStart)}–${String(data.operatingEnd)}` : null);
    const terminalData = { name: String(data.name).trim(), municipality: String(data.municipality).trim(), barangay: data.barangay ? String(data.barangay).trim() : null, latitude: Number(latitude), longitude: Number(longitude), coverageRadiusKm: Number(coverageRadiusKm), accessPaths, fareMin, fareMax, operatingHours, notes: data.notes ? String(data.notes).trim() : null, returnAvailabilityNotice: data.returnAvailabilityNotice ? String(data.returnAvailabilityNotice).trim() : 'Return trips depend on an available passing tricycle.', isActive: data.isActive !== false };
    const terminal = id ? await this.prisma.tricycleTerminal.update({ where: { id }, data: terminalData }) : await this.prisma.tricycleTerminal.create({ data: terminalData });
    await this.audit(actorId, id ? 'update' : 'create', 'tricycle_terminal', terminal.id, terminalData);
    return terminal;
  }
  async removeTricycleTerminal(actorId: string, id: string) {
    const terminal = await this.prisma.tricycleTerminal.findUnique({ where: { id }, select: { id: true, name: true } });
    if (!terminal) throw new BadRequestException('Tricycle terminal not found.');
    await this.prisma.tricycleTerminal.delete({ where: { id } });
    await this.audit(actorId, 'delete', 'tricycle_terminal', id, { name: terminal.name });
    return { deleted: true, terminal };
  }

  businesses() { return this.prisma.partnerBusiness.findMany({ include: { owner: { select: { id: true, name: true, email: true } }, offers: true }, orderBy: [{ approvalStatus: 'asc' }, { name: 'asc' }] }); }

  async reviewBusiness(actorId: string, id: string, input: { decision: string; reason?: string }) {
    const business = await this.prisma.partnerBusiness.findUnique({ where: { id } });
    if (!business) throw new BadRequestException('Partner application not found.');
    if (!['approve', 'changes', 'reject'].includes(input.decision)) throw new BadRequestException('Choose approve, request changes, or reject.');
    if (input.decision === 'approve') {
      if (!business.ownerUserId || business.latitude == null || business.longitude == null || !business.proposedDiscountTitle || !business.proposedDiscountLabel) {
        throw new BadRequestException('The partner must complete the location and discount proposal before approval.');
      }
      const radians = (value: number) => (value * Math.PI) / 180;
      const distanceMeters = (latitude: number, longitude: number) => {
        const dLat = radians(latitude - business.latitude!);
        const dLng = radians(longitude - business.longitude!);
        const value = Math.sin(dLat / 2) ** 2 + Math.cos(radians(business.latitude!)) * Math.cos(radians(latitude)) * Math.sin(dLng / 2) ** 2;
        return 6371000 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
      };
      const landmarks = await this.prisma.landmark.findMany({ select: { id: true, latitude: true, longitude: true } });
      const nearbyLandmarkIds = landmarks.filter((landmark) => distanceMeters(landmark.latitude, landmark.longitude) <= 2500).map((landmark) => landmark.id);
      if (!nearbyLandmarkIds.length) throw new BadRequestException('This business is not within 2.5 km of a landmark badge.');
      const approved = await this.prisma.$transaction(async (transaction) => {
        const updated = await transaction.partnerBusiness.update({
          where: { id },
          data: { proposedBadgeLandmarkId: nearbyLandmarkIds[0], approvalStatus: 'approved', isActive: true, approvedAt: new Date(), approvedById: actorId, rejectionReason: null },
        });
        await transaction.discountOffer.updateMany({ where: { businessId: id, OR: [{ badgeLandmarkId: { notIn: nearbyLandmarkIds } }, { badgeLandmarkId: null }] }, data: { isActive: false } });
        for (const finalLandmarkId of nearbyLandmarkIds) {
          const existingOffer = await transaction.discountOffer.findFirst({ where: { businessId: id, badgeLandmarkId: finalLandmarkId } });
          const offerData = {
            badgeLandmarkId: finalLandmarkId,
            title: business.proposedDiscountTitle,
            description: business.proposedDiscountDescription || business.proposedDiscountTitle,
            discountLabel: business.proposedDiscountLabel,
            isActive: true,
          };
          if (existingOffer) await transaction.discountOffer.update({ where: { id: existingOffer.id }, data: offerData });
          else await transaction.discountOffer.create({ data: { businessId: id, ...offerData } });
        }
        return updated;
      });
      await this.audit(actorId, 'approve', 'partner_business', id);
      return approved;
    }
    const status = input.decision === 'changes' ? 'changes_requested' : 'rejected';
    const reviewed = await this.prisma.partnerBusiness.update({
      where: { id },
      data: { approvalStatus: status, isActive: false, rejectionReason: String(input.reason || '').trim() || (status === 'changes_requested' ? 'Please update the requested information.' : 'Application was not approved.') },
    });
    await this.prisma.discountOffer.updateMany({ where: { businessId: id }, data: { isActive: false } });
    await this.audit(actorId, status, 'partner_business', id, { reason: reviewed.rejectionReason });
    return reviewed;
  }
  async saveBusiness(actorId: string, data: any, id?: string) {
    const partnerEmail = String(data.partnerEmail || '').trim().toLowerCase();
    const owner = partnerEmail
      ? await this.prisma.user.findUnique({ where: { email: partnerEmail } })
      : null;
    if (partnerEmail && !owner) {
      throw new BadRequestException('The partner email must belong to an existing Cavite Explorer account. Ask the partner to register first.');
    }
    const latitude = data.latitude === '' || data.latitude == null ? null : Number(data.latitude);
    const longitude = data.longitude === '' || data.longitude == null ? null : Number(data.longitude);
    if ((latitude != null && !Number.isFinite(latitude)) || (longitude != null && !Number.isFinite(longitude))) {
      throw new BadRequestException('Partner coordinates are invalid.');
    }
    const businessData = {
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
      ownerUserId: owner?.id ?? null,
      isActive: data.isActive !== false,
    };
    if (!businessData.name || !businessData.category || !businessData.address || !businessData.municipality) {
      throw new BadRequestException('Name, category, address, and municipality are required.');
    }
    const business = await this.prisma.$transaction(async (transaction) => {
      if (owner && owner.role !== 'partner') {
        await transaction.user.update({ where: { id: owner.id }, data: { role: 'partner' } });
      }
      return id
        ? transaction.partnerBusiness.update({ where: { id }, data: businessData })
        : transaction.partnerBusiness.create({ data: businessData });
    });
    await this.audit(actorId, id ? 'update' : 'create', 'partner_business', business.id, { ...businessData, partnerEmail });
    return business;
  }

  offers() { return this.prisma.discountOffer.findMany({ include: { business: true, badgeLandmark: true, _count: { select: { redemptions: true } } }, orderBy: { createdAt: 'desc' } }); }
  async saveOffer(actorId: string, data: any, id?: string) {
    const offer = id ? await this.prisma.discountOffer.update({ where: { id }, data }) : await this.prisma.discountOffer.create({ data });
    await this.audit(actorId, id ? 'update' : 'create', 'discount_offer', offer.id, data);
    return offer;
  }
}
