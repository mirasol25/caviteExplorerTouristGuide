-- Persistent, server-verified landmark visit countdowns.
CREATE TABLE IF NOT EXISTS "BadgeVisit" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "landmarkId" TEXT NOT NULL,
  "accumulatedSeconds" INTEGER NOT NULL DEFAULT 0,
  "status" TEXT NOT NULL DEFAULT 'ACTIVE',
  "lastCheckInAt" TIMESTAMP(3),
  "leftAt" TIMESTAMP(3),
  "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BadgeVisit_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "BadgeVisit_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "BadgeVisit_landmarkId_fkey" FOREIGN KEY ("landmarkId") REFERENCES "Landmark"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "BadgeVisit_userId_landmarkId_key"
  ON "BadgeVisit"("userId", "landmarkId");
CREATE INDEX IF NOT EXISTS "BadgeVisit_landmarkId_idx"
  ON "BadgeVisit"("landmarkId");
