-- Add the stable badge identity and future visit-verification settings.
-- Run with: npx prisma db execute --file prisma/badge-system.sql --schema prisma/schema.prisma
ALTER TABLE "Landmark"
  ADD COLUMN IF NOT EXISTS "badgeName" TEXT,
  ADD COLUMN IF NOT EXISTS "badgeDescription" TEXT,
  ADD COLUMN IF NOT EXISTS "badgeIcon" TEXT NOT NULL DEFAULT 'landmark',
  ADD COLUMN IF NOT EXISTS "badgeColor" TEXT NOT NULL DEFAULT '#176A50',
  ADD COLUMN IF NOT EXISTS "badgeRequiredMinutes" INTEGER NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS "badgeRadiusMeters" DOUBLE PRECISION NOT NULL DEFAULT 100;

UPDATE "Landmark"
SET
  "badgeName" = COALESCE(NULLIF("badgeName", ''), "name" || ' Explorer'),
  "badgeDescription" = COALESCE(NULLIF("badgeDescription", ''), 'Earned after a verified visit to ' || "name" || '.'),
  "badgeIcon" = CASE
    WHEN lower("category") LIKE '%church%' OR lower("category") LIKE '%religious%' THEN 'church'
    WHEN lower("category") LIKE '%museum%' THEN 'museum'
    WHEN lower("category") LIKE '%park%' OR lower("category") LIKE '%nature%' THEN 'nature'
    WHEN lower("category") LIKE '%monument%' OR lower("category") LIKE '%shrine%' THEN 'monument'
    WHEN lower("category") LIKE '%plaza%' THEN 'plaza'
    ELSE COALESCE(NULLIF("badgeIcon", ''), 'landmark')
  END;
