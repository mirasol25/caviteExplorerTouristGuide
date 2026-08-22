import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

type Point = [number, number];

type DirectionalRoute = {
  route: any;
  direction: 'outbound' | 'inbound';
  geometry: Point[];
  canonicalGeometry: Point[];
  roads: string[];
  originName: string | null;
  originRoadName: string | null;
  destinationName: string | null;
  destinationRoadName: string | null;
  signboard: string;
  roadAnchors: Array<{ point: Point; name: string }>;
  accessPoints: Array<{ point: Point; name: string; roadName: string; type: 'boarding' | 'transfer' }>;
};

@Injectable()
export class TransportService {
  private readonly matchCache = new Map<string, { expiresAt: number; value: any[] }>();

  constructor(private readonly prisma: PrismaService) {}

  private matchCacheKey(start: Point, destination: Point) {
    const rounded = (value: number) => value.toFixed(4);
    return `${rounded(start[0])},${rounded(start[1])}:${rounded(destination[0])},${rounded(destination[1])}`;
  }

  private cacheMatch(key: string, value: any[]) {
    this.matchCache.set(key, { expiresAt: Date.now() + 60_000, value });
    if (this.matchCache.size <= 250) return value;
    const oldestKey = this.matchCache.keys().next().value;
    if (oldestKey) this.matchCache.delete(oldestKey);
    return value;
  }

  activeRoutes() {
    return this.prisma.transportRoute.findMany({
      where: { isActive: true },
      include: { stops: { include: { stop: true }, orderBy: { sequence: 'asc' } } },
      orderBy: { name: 'asc' },
    });
  }

  activeTricycleTerminals() { return this.prisma.tricycleTerminal.findMany({ where: { isActive: true }, orderBy: { name: 'asc' } }); }

  private distance(a: Point, b: Point) {
    const radians = (degrees: number) => degrees * Math.PI / 180;
    const earthRadius = 6371000;
    const dLat = radians(b[0] - a[0]);
    const dLng = radians(b[1] - a[1]);
    const lat1 = radians(a[0]);
    const lat2 = radians(b[0]);
    const value = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
    return 2 * earthRadius * Math.asin(Math.sqrt(value));
  }

  private nearestIndex(geometry: Point[], target: Point) {
    let index = 0;
    let distance = Number.POSITIVE_INFINITY;
    geometry.forEach((point, pointIndex) => {
      const candidate = this.distance(point, target);
      if (candidate < distance) { index = pointIndex; distance = candidate; }
    });
    return { index, distance };
  }

  private limit(name: string, fallback: number, maximum = Number.POSITIVE_INFINITY) {
    const value = Number(process.env[name]);
    const configured = Number.isFinite(value) && value > 0 ? value : fallback;
    return Math.min(configured, maximum);
  }

  private async motorScooterGeometry(from: Point, to: Point): Promise<Point[] | null> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3000);
    try {
      const response = await fetch('https://valhalla1.openstreetmap.de/route', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal,
        body: JSON.stringify({
          locations: [
            { lat: from[0], lon: from[1], type: 'break' },
            { lat: to[0], lon: to[1], type: 'break' },
          ],
          costing: 'motor_scooter',
          costing_options: {
            motor_scooter: {
              shortest: true,
              disable_hierarchy_pruning: true,
              top_speed: 40,
              use_primary: 0.05,
              use_highways: 0,
              use_tolls: 0,
            },
          },
          directions_options: { units: 'kilometers' },
          shape_format: 'geojson',
        }),
      });
      if (!response.ok) return null;
      const body: any = await response.json();
      const legs = Array.isArray(body?.trip?.legs) ? body.trip.legs : [];
      const coordinates = legs.flatMap((leg: any) => {
        const shape = leg?.shape;
        if (Array.isArray(shape?.coordinates)) return shape.coordinates;
        if (Array.isArray(shape)) return shape;
        return [];
      });
      const geometry = coordinates
        .map((point: any) => [Number(point?.[1]), Number(point?.[0])] as Point)
        .filter((point: Point) => point.every(Number.isFinite));
      return geometry.length >= 2 ? geometry : null;
    } catch {
      return null;
    } finally {
      clearTimeout(timeout);
    }
  }

  private async routedGeometry(from: Point, to: Point): Promise<Point[]> {
    const fallback = [from, to];
    const scooterGeometry = await this.motorScooterGeometry(from, to);
    if (scooterGeometry) return scooterGeometry;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4500);
    try {
      const coordinates = `${from[1]},${from[0]};${to[1]},${to[0]}`;
      const response = await fetch(
        `https://router.project-osrm.org/route/v1/driving/${coordinates}?alternatives=true&overview=full&geometries=geojson&steps=false`,
        { signal: controller.signal },
      );
      if (!response.ok) return fallback;
      const body: any = await response.json();
      const shortestRoute = Array.isArray(body?.routes)
        ? [...body.routes].sort(
            (first: any, second: any) => Number(first?.distance || Number.POSITIVE_INFINITY) - Number(second?.distance || Number.POSITIVE_INFINITY),
          )[0]
        : null;
      const coordinatesList = shortestRoute?.geometry?.coordinates;
      if (!Array.isArray(coordinatesList) || coordinatesList.length < 2) return fallback;
      const geometry = coordinatesList
        .map((point: any) => [Number(point?.[1]), Number(point?.[0])] as Point)
        .filter((point: Point) => point.every(Number.isFinite));
      return geometry.length >= 2 ? geometry : fallback;
    } catch {
      return fallback;
    } finally {
      clearTimeout(timeout);
    }
  }

  private tricycleAccessPaths(value: unknown): Point[][] {
    if (!Array.isArray(value)) return [];
    return value.slice(0, 25).map((path: any) => {
      if (!Array.isArray(path)) return [];
      return path.slice(0, 300)
        .map((point: any) => [Number(point?.[0]), Number(point?.[1])] as Point)
        .filter((point: Point) => point.every(Number.isFinite));
    }).filter((path: Point[]) => path.length >= 2);
  }

  private geometryDistance(geometry: Point[]) {
    return geometry.slice(1).reduce(
      (total, point, index) => total + this.distance(geometry[index], point),
      0,
    );
  }

  private joinGeometry(...sections: Point[][]) {
    const geometry: Point[] = [];
    for (const section of sections) {
      for (const point of section) {
        if (!geometry.length || this.distance(geometry[geometry.length - 1], point) > 1) geometry.push(point);
      }
    }
    return geometry;
  }

  private async routedTricycleGeometry(from: Point, to: Point, value: unknown) {
    const direct = await this.routedGeometry(from, to);
    let best = { geometry: direct, distance: this.geometryDistance(direct), usesAdminAccessPath: false };
    const accessPaths = this.tricycleAccessPaths(value);
    const alternatives = await Promise.all(accessPaths.map(async (savedPath) => {
      const first = savedPath[0];
      const last = savedPath[savedPath.length - 1];
      const forwardCost = this.distance(from, first) + this.distance(last, to);
      const reverseCost = this.distance(from, last) + this.distance(first, to);
      const connector = forwardCost <= reverseCost ? savedPath : [...savedPath].reverse();
      const before = await this.routedGeometry(from, connector[0]);
      const after = await this.routedGeometry(connector[connector.length - 1], to);
      const geometry = this.joinGeometry(before, connector, after);
      return { geometry, distance: this.geometryDistance(geometry), usesAdminAccessPath: true };
    }));
    for (const alternative of alternatives) {
      if (alternative.geometry.length >= 2 && alternative.distance < best.distance) best = alternative;
    }
    return best;
  }

  private sampledIndices(from: number, to: number, maximumSamples = 220) {
    if (to < from) return [];
    const step = Math.max(1, Math.ceil((to - from + 1) / maximumSamples));
    const indices: number[] = [];
    for (let index = from; index <= to; index += step) indices.push(index);
    if (indices[indices.length - 1] !== to) indices.push(to);
    return indices;
  }

  private nearestConnection(first: DirectionalRoute, firstFrom: number, second: DirectionalRoute, secondTo: number) {
    let result = { firstIndex: -1, secondIndex: -1, distance: Number.POSITIVE_INFINITY };
    const firstIndices = this.sampledIndices(firstFrom, first.geometry.length - 1);
    const secondIndices = this.sampledIndices(0, secondTo);
    for (const firstIndex of firstIndices) {
      for (const secondIndex of secondIndices) {
        const distance = this.distance(first.geometry[firstIndex], second.geometry[secondIndex]);
        if (distance < result.distance) result = { firstIndex, secondIndex, distance };
      }
    }
    return result;
  }

  private nearestMetadata<T extends { point: Point }>(items: T[], target: Point, maximumDistance = Number.POSITIVE_INFINITY) {
    let match: T | null = null;
    let matchDistance = Number.POSITIVE_INFINITY;
    for (const item of items) {
      const distance = this.distance(item.point, target);
      if (distance < matchDistance) { match = item; matchDistance = distance; }
    }
    return matchDistance <= maximumDistance ? match : null;
  }

  private roadAnchors(value: unknown): Array<{ point: Point; name: string }> {
    if (!Array.isArray(value)) return [];
    return value.filter((item: any) => Array.isArray(item?.point) && item.point.length >= 2 && item.name).map((item: any) => ({
      point: [Number(item.point[0]), Number(item.point[1])] as Point,
      name: String(item.name),
    })).filter((item) => item.point.every(Number.isFinite));
  }

  private accessPoints(value: unknown): Array<{ point: Point; name: string; roadName: string; type: 'boarding' | 'transfer' }> {
    if (!Array.isArray(value)) return [];
    return value.filter((item: any) => Array.isArray(item?.point) && item.point.length >= 2).map((item: any) => ({
      point: [Number(item.point[0]), Number(item.point[1])] as Point,
      name: String(item.name || ''),
      roadName: String(item.roadName || ''),
      type: item.type === 'transfer' ? 'transfer' as const : 'boarding' as const,
    })).filter((item) => item.point.every(Number.isFinite));
  }

  private orderedRoadAnchors(option: DirectionalRoute) {
    return option.roadAnchors.map((anchor) => ({
      ...anchor,
      routeIndex: this.nearestIndex(option.canonicalGeometry, anchor.point).index,
    })).sort((first, second) => first.routeIndex - second.routeIndex);
  }

  private roadNameAt(option: DirectionalRoute, point: Point) {
    const pointIndex = this.nearestIndex(option.canonicalGeometry, point).index;
    const anchors = this.orderedRoadAnchors(option);
    let match = anchors[0]?.name || null;
    for (const anchor of anchors) {
      if (anchor.routeIndex > pointIndex) break;
      match = anchor.name;
    }
    return match;
  }

  private roadNamesForLeg(option: DirectionalRoute, boardingPoint: Point, dropOffPoint: Point) {
    const boardingIndex = this.nearestIndex(option.canonicalGeometry, boardingPoint).index;
    const dropOffIndex = this.nearestIndex(option.canonicalGeometry, dropOffPoint).index;
    const ascending = boardingIndex <= dropOffIndex;
    const minimum = Math.min(boardingIndex, dropOffIndex);
    const maximum = Math.max(boardingIndex, dropOffIndex);
    const anchors = this.orderedRoadAnchors(option);
    const sections = anchors.map((anchor, index) => ({
      name: anchor.name,
      start: index === 0 ? 0 : anchor.routeIndex,
      end: anchors[index + 1]?.routeIndex ?? option.canonicalGeometry.length - 1,
    })).filter((section) => section.end >= minimum && section.start <= maximum)
      .sort((first, second) => ascending ? first.start - second.start : second.start - first.start)
      .map((section) => section.name);
    return [...new Set(sections)];
  }

  private leg(option: DirectionalRoute, boardingIndex: number, dropOffIndex: number) {
    const geometry = option.geometry.slice(boardingIndex, dropOffIndex + 1);
    const distanceMeters = geometry.slice(1).reduce(
      (total, point, index) => total + this.distance(geometry[index], point),
      0,
    );
    const distanceKm = distanceMeters / 1000;
    const baseFare = option.route.baseFare as number | null;
    const baseDistanceKm = Number(option.route.baseDistanceKm || 4);
    const additionalFarePerKm = option.route.additionalFarePerKm as number | null;
    const billableExtraKilometers = additionalFarePerKm === null
      ? 0
      : Math.max(0, Math.ceil(distanceKm - baseDistanceKm - 0.000001));
    const estimatedFare = baseFare === null
      ? null
      : Math.round((baseFare + billableExtraKilometers * Number(additionalFarePerKm || 0)) * 100) / 100;
    const boardingPoint = option.geometry[boardingIndex];
    const dropOffPoint = option.geometry[dropOffIndex];
    // Named access points are labels for the exact stop area, not mandatory
    // terminals. A broad match used to call an ordinary roadside boarding
    // point a terminal even when the passenger was hundreds of metres away.
    const boardingAccess = this.nearestMetadata(option.accessPoints, boardingPoint, 120);
    const dropOffAccess = this.nearestMetadata(option.accessPoints, dropOffPoint, 120);
    const boardingAtTerminal = this.distance(boardingPoint, option.geometry[0]) <= 300;
    const dropOffAtTerminal = this.distance(dropOffPoint, option.geometry[option.geometry.length - 1]) <= 300;
    const sectionRoadNames = this.roadNamesForLeg(option, boardingPoint, dropOffPoint);
    return {
      id: option.route.id,
      name: option.route.name,
      mode: option.route.mode,
      direction: option.direction,
      signboard: option.signboard,
      originName: option.originName,
      destinationName: option.destinationName,
      baseFare,
      baseDistanceKm,
      additionalFarePerKm,
      billableExtraKilometers,
      distanceKm: Math.round(distanceKm * 100) / 100,
      estimatedFare,
      fareNotes: option.route.fareNotes,
      notes: option.route.notes,
      roadNames: sectionRoadNames.length ? sectionRoadNames : option.roads,
      boardingName: boardingAccess?.name || null,
      boardingRoadName: boardingAccess?.roadName || (boardingAtTerminal ? option.originRoadName : null) || this.roadNameAt(option, boardingPoint),
      dropOffName: dropOffAccess?.name || null,
      dropOffRoadName: dropOffAccess?.roadName || (dropOffAtTerminal ? option.destinationRoadName : null) || this.roadNameAt(option, dropOffPoint),
      geometry,
      boardingPoint,
      dropOffPoint,
      lastVerifiedAt: option.route.lastVerifiedAt,
    };
  }

  private shortestVerifiedRoadPath(
    routes: DirectionalRoute[],
    from: Point,
    to: Point,
    maximumSnapDistance = 350,
  ): Point[] | null {
    let best: { geometry: Point[]; distance: number } | null = null;
    for (const route of routes) {
      const fromMatch = this.nearestIndex(route.geometry, from);
      const toMatch = this.nearestIndex(route.geometry, to);
      if (fromMatch.distance > maximumSnapDistance || toMatch.distance > maximumSnapDistance) continue;
      const minimum = Math.min(fromMatch.index, toMatch.index);
      const maximum = Math.max(fromMatch.index, toMatch.index);
      let geometry = route.geometry.slice(minimum, maximum + 1);
      if (fromMatch.index > toMatch.index) geometry = geometry.reverse();
      if (geometry.length < 2) continue;
      const distance = geometry.slice(1).reduce(
        (total, point, index) => total + this.distance(geometry[index], point),
        fromMatch.distance + toMatch.distance,
      );
      if (!best || distance < best.distance) best = { geometry, distance };
    }
    return best?.geometry || null;
  }

  async match(startLatitude: number, startLongitude: number, destinationLatitude: number, destinationLongitude: number) {
    const start: Point = [startLatitude, startLongitude];
    const destination: Point = [destinationLatitude, destinationLongitude];
    const cacheKey = this.matchCacheKey(start, destination);
    const cached = this.matchCache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) return cached.value;
    if (cached) this.matchCache.delete(cacheKey);

    const [routes, tricycleTerminals] = await Promise.all([
      this.activeRoutes(),
      this.activeTricycleTerminals(),
    ]);
    const candidates: any[] = [];
    const directionalRoutes: DirectionalRoute[] = [];
    // Fixed-route vehicles may be boarded at the nearest safe point anywhere
    // along their verified geometry. These are walking limits to that route,
    // not distances to its terminal. Hard ceilings also protect passengers if
    // an old deployment still has overly permissive environment values.
    const maxBoardingWalk = this.limit('TRANSPORT_MAX_BOARDING_WALK_METERS', 700, 700);
    const maxDestinationWalk = this.limit('TRANSPORT_MAX_DESTINATION_WALK_METERS', 700, 700);
    const maxTransferWalk = this.limit('TRANSPORT_MAX_TRANSFER_WALK_METERS', 250, 250);
    const maxTotalWalk = this.limit('TRANSPORT_MAX_TOTAL_WALK_METERS', 1200, 1500);
    // Convert every saved route into one or two directed paths. Route names,
    // terminals, and signboards all come from the database.
    for (const route of routes) {
      const outbound = Array.isArray(route.outboundGeometry) ? route.outboundGeometry as Point[] : [];
      const explicitInbound = Array.isArray(route.inboundGeometry) ? route.inboundGeometry as Point[] : [];
      directionalRoutes.push(...[
        {
          route, direction: 'outbound' as const, geometry: outbound, canonicalGeometry: outbound, roads: route.outboundRoads,
          originName: route.originName, originRoadName: route.originRoadName, destinationName: route.destinationName, destinationRoadName: route.destinationRoadName,
          signboard: route.outboundSignboard || route.destinationName || route.name,
          roadAnchors: this.roadAnchors(route.outboundRoadAnchors),
          accessPoints: this.accessPoints(route.outboundAccessPoints),
        },
        ...(route.isBidirectional && outbound.length ? [{
          route, direction: 'inbound' as const, geometry: explicitInbound.length ? explicitInbound : [...outbound].reverse(), canonicalGeometry: outbound, roads: route.inboundRoads.length ? route.inboundRoads : [...route.outboundRoads].reverse(),
          originName: route.destinationName, originRoadName: route.destinationRoadName, destinationName: route.originName, destinationRoadName: route.originRoadName,
          signboard: route.inboundSignboard || route.originName || route.name,
          roadAnchors: this.roadAnchors(route.inboundRoadAnchors),
          accessPoints: this.accessPoints(route.inboundAccessPoints),
        }] : []),
      ].filter((option) => option.geometry.length >= 2));
    }

    const tricycleGeometry = new Map<string, Point[]>();
    const verifiedTricycleGeometry = new Set<string>();
    const adminTricycleGeometry = new Set<string>();
    // Initial matching must remain database-only. Detailed road-following
    // geometry is loaded by the client only for the option the passenger
    // selects. This avoids several Valhalla/OSRM calls for unused options.
    for (const terminal of tricycleTerminals) {
      const terminalPoint: Point = [terminal.latitude, terminal.longitude];
      const coverageMeters = terminal.coverageRadiusKm * 1000;
      if (this.distance(terminalPoint, destination) <= coverageMeters) {
        tricycleGeometry.set(`${terminal.id}:outbound`, [terminalPoint, destination]);
      }
      if (this.distance(start, terminalPoint) <= coverageMeters) {
        tricycleGeometry.set(`${terminal.id}:return`, [start, terminalPoint]);
      }
    }

    // First prefer a route that can complete the journey without a transfer.
    for (const option of directionalRoutes) {
      const boarding = this.nearestIndex(option.geometry, start);
      const dropOff = this.nearestIndex(option.geometry, destination);
      if (boarding.index >= dropOff.index || boarding.distance > maxBoardingWalk || dropOff.distance > maxDestinationWalk) continue;
      const leg = this.leg(option, boarding.index, dropOff.index);
      candidates.push({
        ...leg,
        transferCount: 0,
        legs: [leg],
        transferPoints: [],
        distanceToBoardingMeters: Math.round(boarding.distance),
        distanceFromDropOffMeters: Math.round(dropOff.distance),
        score: boarding.distance * 2 + dropOff.distance * 2,
      });
    }

    // Search the saved-route network for journeys with several transfers. A
    // route crossing can be used anywhere after boarding and before the next
    // route ends; it does not have to be a terminal.
    const configuredMaximumLegs = Number(process.env.TRANSPORT_MAX_JOURNEY_LEGS || 4);
    const maximumLegs = Math.max(2, Math.min(6, Number.isFinite(configuredMaximumLegs) ? configuredMaximumLegs : 4));

    const addJourney = (legs: any[], transfers: any[], boardingDistance: number, destinationDistance: number) => {
      const baseFares = legs.map((leg) => leg.baseFare);
      const estimatedFares = legs.map((leg) => leg.estimatedFare);
      const baseFare = baseFares.every((fare) => fare !== null)
        ? baseFares.reduce<number>((sum, fare) => sum + Number(fare), 0)
        : null;
      const estimatedFare = estimatedFares.every((fare) => fare !== null)
        ? estimatedFares.reduce<number>((sum, fare) => sum + Number(fare), 0)
        : null;
      const transferWalkingDistance = transfers.reduce((total, transfer) => total + Number(transfer.walkMeters || 0), 0);
      candidates.push({
        id: legs.map((leg) => `${leg.id}:${leg.direction}`).join('>'),
        name: legs.map((leg) => leg.name).join(' → '),
        mode: 'Multiple rides',
        direction: legs.map((leg) => leg.direction).join('>'),
        signboard: legs[0].signboard,
        originName: legs[0].originName,
        destinationName: legs[legs.length - 1].destinationName,
        baseFare,
        estimatedFare,
        fareNotes: [...new Set(legs.map((leg) => leg.fareNotes).filter(Boolean))].join(' | ') || null,
        notes: [...new Set(legs.map((leg) => leg.notes).filter(Boolean))].join(' | ') || null,
        roadNames: legs.flatMap((leg) => leg.roadNames),
        geometry: legs.flatMap((leg) => leg.geometry),
        boardingPoint: legs[0].boardingPoint,
        dropOffPoint: legs[legs.length - 1].dropOffPoint,
        transferCount: transfers.length,
        legs,
        transferPoints: transfers,
        distanceToBoardingMeters: Math.round(boardingDistance),
        distanceFromDropOffMeters: Math.round(destinationDistance),
        score: boardingDistance * 2 + destinationDistance * 2 + transferWalkingDistance * 2 + transfers.length * 650,
        isOnDemand: legs.some((leg) => leg.isOnDemand === true),
      });
    };

    const explore = (
      current: DirectionalRoute,
      boardingIndex: number,
      completedLegs: any[],
      transfers: any[],
      usedRouteIds: Set<string>,
      usedSignboards: Set<string>,
      initialBoardingDistance: number,
    ) => {
      const destinationMatch = this.nearestIndex(current.geometry, destination);
      if (completedLegs.length > 0 && destinationMatch.distance <= maxDestinationWalk && destinationMatch.index > boardingIndex) {
        const finalLeg = this.leg(current, boardingIndex, destinationMatch.index);
        if (finalLeg.geometry.length >= 2) {
          addJourney([...completedLegs, finalLeg], transfers, initialBoardingDistance, destinationMatch.distance);
        }
      }

      if (completedLegs.length + 1 >= maximumLegs) return;
      for (const next of directionalRoutes) {
        if (usedRouteIds.has(next.route.id) || next.geometry.length < 2) continue;
        const nextSignboard = next.signboard
          .trim()
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, ' ')
          .trim();
        const repeatsDestination = nextSignboard && [...usedSignboards].some(
          (used) => used && (
            used === nextSignboard ||
            used.includes(nextSignboard) ||
            nextSignboard.includes(used)
          ),
        );
        if (repeatsDestination) continue;
        const connection = this.nearestConnection(current, boardingIndex + 1, next, next.geometry.length - 2);
        if (connection.firstIndex < 0 || connection.secondIndex < 0 || connection.distance > maxTransferWalk) continue;

        const currentLeg = this.leg(current, boardingIndex, connection.firstIndex);
        if (currentLeg.geometry.length < 2) continue;
        const nextProbe = this.leg(next, connection.secondIndex, connection.secondIndex + 1);
        const transfer = {
          fromRouteId: currentLeg.id,
          toRouteId: next.route.id,
          alightPoint: currentLeg.dropOffPoint,
          boardingPoint: next.geometry[connection.secondIndex],
          walkMeters: Math.round(connection.distance),
          name: nextProbe.boardingName || currentLeg.dropOffName || null,
          roadName: nextProbe.boardingRoadName || currentLeg.dropOffRoadName || null,
        };
        explore(
          next,
          connection.secondIndex,
          [...completedLegs, currentLeg],
          [...transfers, transfer],
          new Set([...usedRouteIds, next.route.id]),
          new Set([...usedSignboards, nextSignboard]),
          initialBoardingDistance,
        );
      }
    };

    for (const first of directionalRoutes) {
      const boarding = this.nearestIndex(first.geometry, start);
      if (boarding.distance > maxBoardingWalk || boarding.index >= first.geometry.length - 1) continue;
      explore(
        first,
        boarding.index,
        [],
        [],
        new Set([first.route.id]),
        new Set([
          first.signboard
            .trim()
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, ' ')
            .trim(),
        ]),
        boarding.distance,
      );
    }

    // Build a deliberate fixed-route -> terminal -> tricycle journey. The
    // ordinary fixed-route candidate may choose a later drop-off simply because
    // it is closest to the destination. For a useful tricycle option we instead
    // alight at the point on the route that is closest to the terminal.
    for (const terminal of tricycleTerminals) {
      const terminalPoint: Point = [terminal.latitude, terminal.longitude];
      const coverageMeters = terminal.coverageRadiusKm * 1000;
      if (this.distance(terminalPoint, destination) > coverageMeters) continue;

      for (const option of directionalRoutes) {
        const boarding = this.nearestIndex(option.geometry, start);
        const terminalConnection = this.nearestIndex(option.geometry, terminalPoint);
        if (
          boarding.distance > maxBoardingWalk ||
          terminalConnection.distance > maxTransferWalk ||
          boarding.index >= terminalConnection.index
        ) continue;

        const fixedLeg = this.leg(option, boarding.index, terminalConnection.index);
        if (fixedLeg.geometry.length < 2) continue;
        const tricycleFare = terminal.fareMin ?? terminal.fareMax ?? null;
        const geometryKey = `${terminal.id}:outbound`;
        const tricyclePath = tricycleGeometry.get(geometryKey) || [terminalPoint, destination];
        const usesVerifiedRoadPath = verifiedTricycleGeometry.has(geometryKey);
        const tricycleBoardingPoint = terminalPoint;
        const tricycleDropOffPoint = usesVerifiedRoadPath ? tricyclePath[tricyclePath.length - 1] : destination;
        const tricycleLeg = {
          id: terminal.id,
          name: terminal.name,
          mode: 'Tricycle',
          direction: 'outbound',
          signboard: terminal.name,
          originName: terminal.name,
          destinationName: 'Requested destination',
          baseFare: terminal.fareMin,
          baseDistanceKm: 0,
          additionalFarePerKm: null,
          estimatedFare: tricycleFare,
          fareNotes: terminal.operatingHours,
          notes: terminal.notes,
          roadNames: [],
          boardingName: terminal.name,
          boardingRoadName: null,
          dropOffName: 'Requested destination',
          dropOffRoadName: null,
          geometry: tricyclePath,
          boardingPoint: tricycleBoardingPoint,
          dropOffPoint: tricycleDropOffPoint,
          isOnDemand: true,
          usesVerifiedRoadPath,
          usesAdminAccessPath: adminTricycleGeometry.has(geometryKey),
          accessPaths: terminal.accessPaths,
          coverageRadiusKm: terminal.coverageRadiusKm,
        };
        addJourney(
          [fixedLeg, tricycleLeg],
          [{
            fromRouteId: fixedLeg.id,
            toRouteId: terminal.id,
            alightPoint: fixedLeg.dropOffPoint,
            boardingPoint: tricycleBoardingPoint,
            walkMeters: Math.round(this.distance(fixedLeg.dropOffPoint, tricycleBoardingPoint)),
            name: terminal.name,
            roadName: null,
            isOnDemand: true,
          }],
          boarding.distance,
          this.distance(tricycleDropOffPoint, destination),
        );
      }
    }

    // A tricycle may also be the final connection after an already-discovered
    // multi-route journey. For example:
    // Paliparan jeepney -> alight at Avenida Rizal -> terminal tricycle -> Eco-Park.
    // This is deliberately data-driven: any fixed-route drop-off close to an
    // active terminal can connect to a destination inside that terminal's radius.
    const fixedJourneySeeds = candidates.filter((candidate) =>
      Array.isArray(candidate.legs) && !candidate.isOnDemand,
    );
    for (const journey of fixedJourneySeeds) {
      const lastLeg = journey.legs[journey.legs.length - 1];
      const dropOffPoint = lastLeg?.dropOffPoint as Point | undefined;
      if (!dropOffPoint) continue;
      for (const terminal of tricycleTerminals) {
        const terminalPoint: Point = [terminal.latitude, terminal.longitude];
        const transferWalk = this.distance(dropOffPoint, terminalPoint);
        const coverageMeters = terminal.coverageRadiusKm * 1000;
        if (transferWalk > maxTransferWalk || this.distance(terminalPoint, destination) > coverageMeters) continue;
        const tricycleFare = terminal.fareMin ?? terminal.fareMax ?? null;
        const geometryKey = `${terminal.id}:outbound`;
        const tricyclePath = tricycleGeometry.get(geometryKey) || [terminalPoint, destination];
        const usesVerifiedRoadPath = verifiedTricycleGeometry.has(geometryKey);
        const tricycleBoardingPoint = terminalPoint;
        const tricycleDropOffPoint = usesVerifiedRoadPath ? tricyclePath[tricyclePath.length - 1] : destination;
        const tricycleLeg = {
          id: terminal.id,
          name: terminal.name,
          mode: 'Tricycle',
          direction: 'outbound',
          signboard: terminal.name,
          originName: terminal.name,
          destinationName: 'Requested destination',
          baseFare: terminal.fareMin,
          baseDistanceKm: 0,
          additionalFarePerKm: null,
          estimatedFare: tricycleFare,
          fareNotes: terminal.operatingHours,
          notes: terminal.notes,
          roadNames: [],
          boardingName: terminal.name,
          boardingRoadName: null,
          dropOffName: 'Requested destination',
          dropOffRoadName: null,
          geometry: tricyclePath,
          boardingPoint: tricycleBoardingPoint,
          dropOffPoint: tricycleDropOffPoint,
          isOnDemand: true,
          usesVerifiedRoadPath,
          usesAdminAccessPath: adminTricycleGeometry.has(geometryKey),
          accessPaths: terminal.accessPaths,
          coverageRadiusKm: terminal.coverageRadiusKm,
        };
        addJourney(
          [...journey.legs, tricycleLeg],
          [...(journey.transferPoints || []), {
            fromRouteId: lastLeg.id,
            toRouteId: terminal.id,
            alightPoint: dropOffPoint,
            boardingPoint: tricycleBoardingPoint,
            walkMeters: Math.round(this.distance(dropOffPoint, tricycleBoardingPoint)),
            name: terminal.name,
            roadName: null,
            isOnDemand: true,
          }],
          Number(journey.distanceToBoardingMeters || 0),
          this.distance(tricycleDropOffPoint, destination),
        );
      }
    }
    const walkingDistance = (candidate: any) =>
      Number(candidate.distanceToBoardingMeters || 0) +
      Number(candidate.distanceFromDropOffMeters || 0) +
      (candidate.transferPoints || []).reduce(
        (total: number, transfer: any) => total + Number(transfer.walkMeters || 0),
        0,
      );
    const fare = (candidate: any) => {
      if (candidate.estimatedFare === null || candidate.estimatedFare === undefined) {
        return Number.POSITIVE_INFINITY;
      }
      const value = Number(candidate.estimatedFare);
      return Number.isFinite(value) ? value : Number.POSITIVE_INFINITY;
    };
    // Keep one best instance of each route sequence, then remove every journey
    // that is worse than another journey on all important passenger costs.
    const uniqueCandidates = [...candidates
      .reduce((items, candidate) => {
        const existing = items.get(candidate.id);
        if (!existing || candidate.score < existing.score) items.set(candidate.id, candidate);
        return items;
      }, new Map<string, any>())
      .values()];
    const walkableCandidates = uniqueCandidates.filter(
      (candidate) => walkingDistance(candidate) <= maxTotalWalk,
    );
    const efficientCandidates = walkableCandidates.filter((candidate) =>
      !walkableCandidates.some((other) => {
        if (other === candidate) return false;
        const noWorse =
          walkingDistance(other) <= walkingDistance(candidate) &&
          fare(other) <= fare(candidate) &&
          Number(other.transferCount || 0) <= Number(candidate.transferCount || 0);
        const strictlyBetter =
          walkingDistance(other) < walkingDistance(candidate) ||
          fare(other) < fare(candidate) ||
          Number(other.transferCount || 0) < Number(candidate.transferCount || 0);
        return noWorse && strictlyBetter;
      }),
    );
    const practicalCandidates = efficientCandidates.filter((candidate) =>
      !efficientCandidates.some((other) => {
        if (other === candidate) return false;
        const candidateTransfers = Number(candidate.transferCount || 0);
        const otherTransfers = Number(other.transferCount || 0);
        if (otherTransfers >= candidateTransfers) return false;
        const comparableWalking =
          walkingDistance(other) <= walkingDistance(candidate) + 300;
        const comparableFare = fare(other) <= fare(candidate) + 5;
        return comparableWalking && comparableFare;
      }),
    );
    // A tricycle is an on-demand terminal service. Passengers must board at
    // the administrator-pinned terminal. The coverage radius only determines
    // which destinations that terminal can serve; it is never a boarding area.
    const tricycleCandidates = tricycleTerminals.flatMap((terminal) => {
      const terminalPoint: Point = [terminal.latitude, terminal.longitude];
      const startDistance = this.distance(start, terminalPoint);
      const destinationDistance = this.distance(destination, terminalPoint);
      const coverageMeters = terminal.coverageRadiusKm * 1000;
      const terminalToDestination = startDistance <= 350 && destinationDistance <= coverageMeters;
      if (!terminalToDestination) return [];
      const geometryKey = `${terminal.id}:outbound`;
      const geometry = tricycleGeometry.get(geometryKey) || [terminalPoint, destination];
      const usesVerifiedRoadPath = verifiedTricycleGeometry.has(geometryKey);
      // Always keep the boarding pin at the saved terminal even if the road
      // router snaps its first geometry point to a nearby road segment.
      const boardingPoint = terminalPoint;
      const dropOffPoint = usesVerifiedRoadPath ? geometry[geometry.length - 1] : destination;
      const accessWalk = this.distance(start, boardingPoint);
      const destinationWalk = this.distance(dropOffPoint, destination);
      const fare = terminal.fareMin ?? terminal.fareMax ?? null;
      const leg = { id: terminal.id, name: terminal.name, mode: 'Tricycle', direction: 'outbound', signboard: terminal.name, originName: terminal.name, destinationName: 'Requested destination', baseFare: terminal.fareMin, estimatedFare: fare, fareMin: terminal.fareMin, fareMax: terminal.fareMax, fareNotes: terminal.operatingHours, notes: terminal.notes, roadNames: [], boardingName: terminal.name, boardingRoadName: null, dropOffName: 'Requested destination', dropOffRoadName: null, geometry, boardingPoint, dropOffPoint, isOnDemand: true, usesVerifiedRoadPath, usesAdminAccessPath: adminTricycleGeometry.has(geometryKey), accessPaths: terminal.accessPaths, returnAvailabilityDependent: false, coverageRadiusKm: terminal.coverageRadiusKm };
      return [{ ...leg, transferCount: 0, legs: [leg], transferPoints: [], distanceToBoardingMeters: Math.round(accessWalk), distanceFromDropOffMeters: Math.round(destinationWalk), score: accessWalk * 2 + destinationWalk * 2 }];
    });
    const selectableCandidates = [
      ...practicalCandidates,
      ...uniqueCandidates.filter((candidate) => candidate.isOnDemand),
      ...tricycleCandidates,
    ].reduce((items, candidate) => {
      const existing = items.get(candidate.id);
      if (!existing || candidate.score < existing.score) items.set(candidate.id, candidate);
      return items;
    }, new Map<string, any>());

    const options = [...selectableCandidates.values()];
    if (!options.length) return this.cacheMatch(cacheKey, []);

    const rides = (candidate: any) => Math.max(1, Number(candidate.legs?.length || 1));
    const knownFare = (candidate: any) => {
      const value = fare(candidate);
      return Number.isFinite(value) ? value : 9999;
    };
    const routeSignature = (candidate: any) => (candidate.legs || [candidate])
      .map((leg: any) => `${leg.id}:${leg.direction}`)
      .join('>');

    // These three ranks intentionally answer different passenger needs:
    // - balanced: affordable without accepting a long walk;
    // - budget: lowest known fare, then the least walking among similar fares;
    // - convenient: least walking and fewest transfers, even when it costs more.
    const balancedRank = (candidate: any) =>
      knownFare(candidate) + walkingDistance(candidate) / 70 + Number(candidate.transferCount || 0) * 8;
    const budgetRank = (candidate: any) =>
      knownFare(candidate) * 1000 + walkingDistance(candidate) + Number(candidate.transferCount || 0) * 150;
    const convenientRank = (candidate: any) =>
      walkingDistance(candidate) + Number(candidate.transferCount || 0) * 350 + rides(candidate) * 100 + knownFare(candidate) * 2;

    const selected: any[] = [];
    const selectedBySignature = new Map<string, any>();
    const select = (profile: 'balanced' | 'budget' | 'convenient', rank: (candidate: any) => number) => {
      const candidate = [...options]
        .sort((first, second) => rank(first) - rank(second))[0];
      if (!candidate) return;
      const signature = routeSignature(candidate);
      const existing = selectedBySignature.get(signature);
      if (existing) {
        existing.recommendationProfiles.push(profile);
        return;
      }
      const recommendation = {
        ...candidate,
        recommendationProfile: profile,
        recommendationProfiles: [profile],
      };
      selectedBySignature.set(signature, recommendation);
      selected.push(recommendation);
    };

    select('balanced', balancedRank);
    select('budget', budgetRank);
    select('convenient', convenientRank);

    // If two profiles resolve to the same journey, fill the remaining cards
    // with the next best distinct balanced journeys instead of showing
    // repetitive suggestions.
    for (const candidate of [...options].sort((first, second) => balancedRank(first) - balancedRank(second))) {
      if (selected.length >= 3) break;
      const signature = routeSignature(candidate);
      if (selectedBySignature.has(signature)) continue;
      const recommendation = {
        ...candidate,
        recommendationProfile: 'alternative',
        recommendationProfiles: ['alternative'],
      };
      selectedBySignature.set(signature, recommendation);
      selected.push(recommendation);
    }
    return this.cacheMatch(cacheKey, selected);
  }
}
