-- Align legacy SupportProgram rows with current defaults while keeping guards
DO $$
BEGIN
  IF to_regclass('public."SupportProgram"') IS NOT NULL THEN
    -- Ensure mandatory status fields never stay NULL
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'SupportProgram'
        AND column_name = 'status'
    ) THEN
      UPDATE "SupportProgram"
        SET "status" = 'active'
        WHERE "status" IS NULL;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'SupportProgram'
        AND column_name = 'category'
    ) THEN
      UPDATE "SupportProgram"
        SET "category" = 'diger'
        WHERE "category" IS NULL;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'SupportProgram'
        AND column_name = 'priority'
    ) THEN
      UPDATE "SupportProgram"
        SET "priority" = 0
        WHERE "priority" IS NULL;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'SupportProgram'
        AND column_name = 'updatedAt'
    ) THEN
      -- Backfill updatedAt so triggers relying on it do not fail
      UPDATE "SupportProgram"
        SET "updatedAt" = COALESCE("updatedAt", NOW());
    END IF;
  END IF;
END
$$;
