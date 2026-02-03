-- Add type-specific fields for crops
ALTER TABLE "Crop" ADD COLUMN IF NOT EXISTS "specificType" VARCHAR(50);
ALTER TABLE "Crop" ADD COLUMN IF NOT EXISTS "proteinPercent" DOUBLE PRECISION;
ALTER TABLE "Crop" ADD COLUMN IF NOT EXISTS "moisturePercent" DOUBLE PRECISION;
ALTER TABLE "Crop" ADD COLUMN IF NOT EXISTS "sugarPercent" DOUBLE PRECISION;
ALTER TABLE "Crop" ADD COLUMN IF NOT EXISTS "oilPercent" DOUBLE PRECISION;
ALTER TABLE "Crop" ADD COLUMN IF NOT EXISTS "healthStatus" VARCHAR(100);
ALTER TABLE "Crop" ADD COLUMN IF NOT EXISTS "diseaseNotes" TEXT;
ALTER TABLE "Crop" ADD COLUMN IF NOT EXISTS "qualityScore" INTEGER;
ALTER TABLE "Crop" ADD COLUMN IF NOT EXISTS "customMetrics" JSONB;

-- Add type-specific fields for livestock
ALTER TABLE "Livestock" ADD COLUMN IF NOT EXISTS "specificType" VARCHAR(50);
ALTER TABLE "Livestock" ADD COLUMN IF NOT EXISTS "weightKg" DOUBLE PRECISION;
ALTER TABLE "Livestock" ADD COLUMN IF NOT EXISTS "healthStatus" VARCHAR(100);
ALTER TABLE "Livestock" ADD COLUMN IF NOT EXISTS "dailyFeedKg" DOUBLE PRECISION;
ALTER TABLE "Livestock" ADD COLUMN IF NOT EXISTS "vaccineStatus" VARCHAR(200);
ALTER TABLE "Livestock" ADD COLUMN IF NOT EXISTS "lastCheckupDate" TIMESTAMP(3);
ALTER TABLE "Livestock" ADD COLUMN IF NOT EXISTS "customMetrics" JSONB;

-- Add egg production tracking
CREATE TABLE IF NOT EXISTS "EggLog" (
    "id" TEXT NOT NULL,
    "livestockId" TEXT NOT NULL,
    "measuredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "eggCount" INTEGER NOT NULL,
    "avgWeightGram" DOUBLE PRECISION,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EggLog_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "EggLog_livestockId_measuredAt_idx" ON "EggLog"("livestockId", "measuredAt");

ALTER TABLE "EggLog" ADD CONSTRAINT "EggLog_livestockId_fkey"
    FOREIGN KEY ("livestockId") REFERENCES "Livestock"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Add honey production tracking
CREATE TABLE IF NOT EXISTS "HoneyLog" (
    "id" TEXT NOT NULL,
    "livestockId" TEXT NOT NULL,
    "measuredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "amountKg" DOUBLE PRECISION NOT NULL,
    "qualityGrade" VARCHAR(50),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "HoneyLog_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "HoneyLog_livestockId_measuredAt_idx" ON "HoneyLog"("livestockId", "measuredAt");

ALTER TABLE "HoneyLog" ADD CONSTRAINT "HoneyLog_livestockId_fkey"
    FOREIGN KEY ("livestockId") REFERENCES "Livestock"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Add wool shearing tracking
CREATE TABLE IF NOT EXISTS "WoolLog" (
    "id" TEXT NOT NULL,
    "livestockId" TEXT NOT NULL,
    "shearedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "amountKg" DOUBLE PRECISION NOT NULL,
    "qualityGrade" VARCHAR(50),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WoolLog_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "WoolLog_livestockId_shearedAt_idx" ON "WoolLog"("livestockId", "shearedAt");

ALTER TABLE "WoolLog" ADD CONSTRAINT "WoolLog_livestockId_fkey"
    FOREIGN KEY ("livestockId") REFERENCES "Livestock"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Add weight tracking logs
CREATE TABLE IF NOT EXISTS "WeightLog" (
    "id" TEXT NOT NULL,
    "livestockId" TEXT NOT NULL,
    "measuredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "weightKg" DOUBLE PRECISION NOT NULL,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WeightLog_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "WeightLog_livestockId_measuredAt_idx" ON "WeightLog"("livestockId", "measuredAt");

ALTER TABLE "WeightLog" ADD CONSTRAINT "WeightLog_livestockId_fkey"
    FOREIGN KEY ("livestockId") REFERENCES "Livestock"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Add crop quality measurements
CREATE TABLE IF NOT EXISTS "CropQualityLog" (
    "id" TEXT NOT NULL,
    "cropId" TEXT NOT NULL,
    "measuredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "proteinPercent" DOUBLE PRECISION,
    "moisturePercent" DOUBLE PRECISION,
    "sugarPercent" DOUBLE PRECISION,
    "oilPercent" DOUBLE PRECISION,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CropQualityLog_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "CropQualityLog_cropId_measuredAt_idx" ON "CropQualityLog"("cropId", "measuredAt");

ALTER TABLE "CropQualityLog" ADD CONSTRAINT "CropQualityLog_cropId_fkey"
    FOREIGN KEY ("cropId") REFERENCES "Crop"("id") ON DELETE CASCADE ON UPDATE CASCADE;
