import {
  CROP_TYPE_FIELDS,
  FieldType,
  LIVESTOCK_TYPE_FIELDS,
  TypeFieldConfig,
  TypeFieldsConfig,
} from "../config/type-fields";

export type TypeKind = "crop" | "livestock";

export interface Highlight {
  key: string;
  labelKey: string;
  value: string | number;
}

export interface ProcessedMetrics {
  metrics: Record<string, any>;
  highlights: Highlight[];
  config?: TypeFieldsConfig;
}

interface ProcessOptions {
  computeAutoNext?: boolean;
}

function isRecord(value: unknown): value is Record<string, any> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function normalizeDate(value: unknown): string | undefined {
  if (value == null) return undefined;
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return undefined;
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
      return trimmed;
    }
  }
  const date = new Date(value as any);
  if (Number.isNaN(date.valueOf())) return undefined;
  const iso = date.toISOString();
  return iso.split("T")[0];
}

function addDays(baseDate: string, days: number): string | undefined {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(baseDate)) return undefined;
  const [year, month, day] = baseDate.split("-").map((part) => Number(part));
  if ([year, month, day].some((part) => Number.isNaN(part))) return undefined;
  const date = new Date(Date.UTC(year, month - 1, day));
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().split("T")[0];
}

function coerceValue(field: TypeFieldConfig, raw: unknown) {
  if (raw == null) return undefined;
  switch (field.type) {
    case "text": {
      const val = String(raw).trim();
      return val.length > 0 ? val : undefined;
    }
    case "number": {
      const num = Number.parseFloat(String(raw));
      return Number.isFinite(num) ? num : undefined;
    }
    case "integer": {
      const num = Number.parseInt(String(raw), 10);
      return Number.isFinite(num) ? num : undefined;
    }
    case "date":
      return normalizeDate(raw);
    case "choice": {
      const val = String(raw).trim();
      if (!val) return undefined;
      if (!field.choices || field.choices.length === 0) return val;
      return field.choices.includes(val) ? val : undefined;
    }
    default:
      return raw;
  }
}

function getFieldConfig(
  kind: TypeKind,
  subtype: string,
): TypeFieldsConfig | undefined {
  const key = subtype.trim().toLowerCase();
  return kind === "crop"
    ? CROP_TYPE_FIELDS[key]
    : LIVESTOCK_TYPE_FIELDS[key];
}

function ensureMetricsObject(input: unknown): Record<string, any> {
  if (isRecord(input)) return { ...input };
  if (typeof input === "string") {
    try {
      const parsed = JSON.parse(input);
      return isRecord(parsed) ? { ...parsed } : {};
    } catch {
      return {};
    }
  }
  return {};
}

export function processTypeMetrics(
  kind: TypeKind,
  subtype: string,
  input: unknown,
  options: ProcessOptions = {},
): ProcessedMetrics {
  const config = getFieldConfig(kind, subtype);
  const computeAutoNext = options.computeAutoNext ?? true;
  const base = ensureMetricsObject(input);

  if (!config) {
    return {
      metrics: base,
      highlights: [],
    };
  }

  const metrics: Record<string, any> = {};
  const processedKeys = new Set<string>();

  for (const field of config.fields) {
    const rawValue = base[field.key];
    const coerced = coerceValue(field, rawValue);
    if (coerced !== undefined) {
      metrics[field.key] = coerced;
    }
    processedKeys.add(field.key);

    if (field.autoNext) {
      const nextKey = field.autoNext.key;
      const nextField = config.fields.find((f) => f.key === nextKey);
      const providedNext =
        nextField != null ? coerceValue(nextField, base[nextKey]) : undefined;
      if (providedNext !== undefined) {
        metrics[nextKey] = providedNext;
      }

      if (
        computeAutoNext &&
        coerced &&
        typeof coerced === "string" &&
        !metrics[nextKey]
      ) {
        const nextVal = addDays(coerced, field.autoNext.intervalDays);
        if (nextVal) {
          metrics[nextKey] = nextVal;
        }
      }
      processedKeys.add(nextKey);
    }
  }

  // Preserve unknown keys (forward compatibility)
  for (const [key, value] of Object.entries(base)) {
    if (!processedKeys.has(key) && value != null) {
      metrics[key] = value;
    }
  }

  const highlights: Highlight[] = [];
  const summaryKeys = config.summaryKeys ?? [];
  for (const key of summaryKeys) {
    const field = config.fields.find((f) => f.key === key);
    if (!field) continue;
    const value = metrics[key];
    if (
      value === undefined ||
      value === null ||
      (typeof value === "string" && value.trim() === "")
    ) {
      continue;
    }
    highlights.push({
      key,
      labelKey: field.labelKey,
      value: value,
    });
  }

  return { metrics, highlights, config };
}

export function mergeTypeMetrics(
  kind: TypeKind,
  subtype: string,
  previous: unknown,
  updates: unknown,
): ProcessedMetrics {
  const base = ensureMetricsObject(previous);
  const incoming = ensureMetricsObject(updates);
  const merged = { ...base, ...incoming };
  return processTypeMetrics(kind, subtype, merged);
}
