DO $$
BEGIN
  IF to_regclass('public."CropMetric"') IS NOT NULL THEN
    ALTER TABLE "CropMetric"
      ALTER COLUMN "updatedAt" DROP DEFAULT;
  END IF;

  IF to_regclass('public."LivestockMetric"') IS NOT NULL THEN
    ALTER TABLE "LivestockMetric"
      ALTER COLUMN "updatedAt" DROP DEFAULT;
  END IF;
END
$$;
