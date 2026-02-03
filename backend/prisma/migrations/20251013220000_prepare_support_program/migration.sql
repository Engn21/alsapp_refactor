-- Ensure SupportProgram columns exist before altering defaults
DO $$
BEGIN
  IF to_regclass('public."SupportProgram"') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'SupportProgram'
        AND column_name = 'category'
    ) THEN
      ALTER TABLE "SupportProgram"
        ADD COLUMN "category" TEXT NOT NULL DEFAULT 'diger';
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'SupportProgram'
        AND column_name = 'updatedAt'
    ) THEN
      ALTER TABLE "SupportProgram"
        ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
    END IF;
  END IF;
END
$$;
