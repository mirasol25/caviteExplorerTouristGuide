import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma.service'; // Adjust path if your PrismaService is located elsewhere

@Injectable()
export class TripsService {
  constructor(private prisma: PrismaService) {}

  // --- SAVE A NEW TRIP ---
  async saveTrip(userId: string, tripData: any) {
    return this.prisma.tripPlan.create({
      data: {
        userId: userId,
        landmarkId: tripData.landmarkId,
        title: tripData.title,
        startAddress: tripData.startAddress,
        itinerary: tripData.itinerary, // Prisma automatically handles this as JSON!
        commuteGuide: tripData.commuteGuide ?? undefined,
        routeGeometry: tripData.routeGeometry ?? undefined,
        plannedStartAt: tripData.plannedStartAt ? new Date(tripData.plannedStartAt) : undefined,
        plannedEndAt: tripData.plannedEndAt ? new Date(tripData.plannedEndAt) : undefined,
        tripMode: tripData.tripMode === 'NOW' ? 'NOW' : 'SCHEDULED',
        status: tripData.status === 'ACTIVE' ? 'ACTIVE' : 'PLANNED',
      },
      include: { landmark: true },
    });
  }

  async updateTripProgress(userId: string, tripId: string, data: any) {
    const allowedStatuses = ['PLANNED', 'ACTIVE', 'COMPLETED', 'CANCELLED'];
    if (data.status && !allowedStatuses.includes(data.status)) {
      throw new BadRequestException('Invalid trip status.');
    }

    const result = await this.prisma.tripPlan.updateMany({
      where: { id: tripId, userId },
      data: {
        ...(data.status ? { status: data.status } : {}),
        ...(Number.isInteger(data.currentStep) && data.currentStep >= 0
            ? { currentStep: data.currentStep }
            : {}),
      },
    });
    if (result.count === 0) {
      throw new NotFoundException('Trip not found or you do not have permission to update it.');
    }
    return { message: 'Trip progress updated successfully' };
  }

  // --- GET ALL TRIPS FOR A USER ---
  async getUserTrips(userId: string) {
    return this.prisma.tripPlan.findMany({
      where: { userId: userId },
      include: {
        landmark: {
          select: {
            id: true,
            name: true,
            images: true,
            municipality: true,
            latitude: true,
            longitude: true,
            badgeName: true,
            badgeImage: true,
            badgeRequiredMinutes: true,
            badgeRadiusMeters: true,
          },
        },
      },
      orderBy: { addedAt: 'desc' }, // Newest trips first
    });
  }

  // --- DELETE A SAVED TRIP ---
  async deleteTrip(tripId: string, userId: string) {
    // deleteMany ensures a user can ONLY delete a trip that belongs to them
    const result = await this.prisma.tripPlan.deleteMany({
      where: { 
        id: tripId, 
        userId: userId 
      },
    });

    if (result.count === 0) {
      throw new NotFoundException('Trip not found or you do not have permission to delete it.');
    }

    return { message: 'Trip deleted successfully' };
  }
}
