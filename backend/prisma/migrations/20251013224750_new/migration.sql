DO $$
BEGIN
  IF to_regclass('public."SupportProgram"') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'SupportProgram'
        AND column_name = 'category'
    ) THEN
      ALTER TABLE "SupportProgram"
        ALTER COLUMN "category" DROP DEFAULT;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'SupportProgram'
        AND column_name = 'updatedAt'
    ) THEN
      ALTER TABLE "SupportProgram"
        ALTER COLUMN "updatedAt" DROP DEFAULT;
    END IF;
  END IF;
END
$$;
