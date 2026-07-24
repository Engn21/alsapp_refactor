-- AlterTable
ALTER TABLE "CropMetric" ALTER COLUMN "updatedAt" DROP DEFAULT;

-- AlterTable
ALTER TABLE "Livestock" ADD COLUMN     "lastWaterQualityAlertAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "LivestockMetric" ALTER COLUMN "updatedAt" DROP DEFAULT;
