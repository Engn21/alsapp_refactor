-- Align database schema with updated Prisma datamodel
-- Adds tracking auxiliary tables, new crop/livestock columns, notifications,
-- and refreshes the Role enum.

-- 1) Replace Role enum with the current set of values (farmer, ministry)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'Role') THEN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'Role_new') THEN
      DROP TYPE "Role_new";
    END IF;
    CREATE TYPE "Role_new" AS ENUM ('farmer', 'ministry');

    ALTER TABLE "User"
    ALTER COLUMN "role" DROP DEFAULT;

    ALTER TABLE "User"
    ALTER COLUMN "role"
    TYPE "Role_new"
    USING (
      CASE
        WHEN "role"::text IN ('farmer', 'ministry') THEN "role"::text
        WHEN "role"::text IN ('advisor', 'admin') THEN 'ministry'
        ELSE 'farmer'
      END::"Role_new"
    );

    ALTER TABLE "User"
    ALTER COLUMN "role" SET DEFAULT 'farmer';

    DROP TYPE "Role";
    ALTER TYPE "Role_new" RENAME TO "Role";
  ELSE
    CREATE TYPE "Role" AS ENUM ('farmer', 'ministry');
  END IF;
END
$$;

-- 2) Extend Crop table with new agronomy fields
ALTER TABLE "Crop"
  ADD COLUMN IF NOT EXISTS "notes" TEXT,
  ADD COLUMN IF NOT EXISTS "areaHectares" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "pesticide" TEXT,
  ADD COLUMN IF NOT EXISTS "nextSprayDueAt" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "lastSprayAlertAt" TIMESTAMP(3);

-- 3) Extend Livestock table with last alert tracking
ALTER TABLE "Livestock"
  ADD COLUMN IF NOT EXISTS "lastMilkAlertAt" TIMESTAMP(3);

-- 4) Create CropSpray table
CREATE TABLE IF NOT EXISTS "CropSpray" (
  "id" TEXT PRIMARY KEY,
  "cropId" TEXT NOT NULL,
  "sprayedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "pesticide" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'CropSpray_cropId_fkey'
  ) THEN
    ALTER TABLE "CropSpray"
      ADD CONSTRAINT "CropSpray_cropId_fkey"
        FOREIGN KEY ("cropId") REFERENCES "Crop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS "CropSpray_cropId_sprayedAt_idx"
  ON "CropSpray"("cropId", "sprayedAt");

-- 5) Create CropHarvest table
CREATE TABLE IF NOT EXISTS "CropHarvest" (
  "id" TEXT PRIMARY KEY,
  "cropId" TEXT NOT NULL,
  "harvestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "amountTon" DOUBLE PRECISION NOT NULL,
  "yieldTonPerHa" DOUBLE PRECISION,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'CropHarvest_cropId_fkey'
  ) THEN
    ALTER TABLE "CropHarvest"
      ADD CONSTRAINT "CropHarvest_cropId_fkey"
        FOREIGN KEY ("cropId") REFERENCES "Crop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS "CropHarvest_cropId_harvestedAt_idx"
  ON "CropHarvest"("cropId", "harvestedAt");

-- 6) Create MilkLog table
CREATE TABLE IF NOT EXISTS "MilkLog" (
  "id" TEXT PRIMARY KEY,
  "livestockId" TEXT NOT NULL,
  "measuredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "quantityL" DOUBLE PRECISION NOT NULL,
  "fatPercent" DOUBLE PRECISION,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'MilkLog_livestockId_fkey'
  ) THEN
    ALTER TABLE "MilkLog"
      ADD CONSTRAINT "MilkLog_livestockId_fkey"
        FOREIGN KEY ("livestockId") REFERENCES "Livestock"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS "MilkLog_livestockId_measuredAt_idx"
  ON "MilkLog"("livestockId", "measuredAt");

-- 7) Create Notification table
CREATE TABLE IF NOT EXISTS "Notification" (
  "id" TEXT PRIMARY KEY,
  "userId" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "category" TEXT,
  "metadata" JSONB,
  "read" BOOLEAN NOT NULL DEFAULT FALSE,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'Notification_userId_fkey'
  ) THEN
    ALTER TABLE "Notification"
      ADD CONSTRAINT "Notification_userId_fkey"
        FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END
$$;

CREATE INDEX IF NOT EXISTS "Notification_userId_createdAt_idx"
  ON "Notification"("userId", "createdAt");
