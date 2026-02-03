-- Create tables to persist type-specific metrics per key
CREATE TABLE "CropMetric" (
    "id" TEXT NOT NULL,
    "cropId" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CropMetric_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "LivestockMetric" (
    "id" TEXT NOT NULL,
    "livestockId" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "LivestockMetric_pkey" PRIMARY KEY ("id")
);

-- Foreign keys
ALTER TABLE "CropMetric"
  ADD CONSTRAINT "CropMetric_cropId_fkey"
  FOREIGN KEY ("cropId") REFERENCES "Crop"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "LivestockMetric"
  ADD CONSTRAINT "LivestockMetric_livestockId_fkey"
  FOREIGN KEY ("livestockId") REFERENCES "Livestock"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- Indexes for efficient lookups
CREATE INDEX "CropMetric_cropId_key_idx" ON "CropMetric"("cropId", "key");
CREATE INDEX "LivestockMetric_livestockId_key_idx" ON "LivestockMetric"("livestockId", "key");
