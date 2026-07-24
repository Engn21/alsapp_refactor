/**
 * Type-specific thresholds and ideal ranges for crops and livestock
 * These values are used for monitoring and alerting
 */

export interface CropThreshold {
  minYieldTonPerHa: number;
  idealProteinPercent?: { min: number; max: number };
  idealMoisturePercent?: { min: number; max: number };
  idealSugarPercent?: { min: number; max: number };
  idealOilPercent?: { min: number; max: number };
  sprayIntervalDays: number;
}

export interface LivestockThreshold {
  minDailyMilkL?: number;
  minMilkFatPercent?: number;
  minDailyEggs?: number;
  minWeightKg?: number;
  maxWeightKg?: number;
  idealWeightKg?: number;
  idealDailyFeedKg?: number;
  idealWaterTemperatureC?: { min: number; max: number };
  idealWaterPh?: { min: number; max: number };
  minHoneyKgPerYear?: number;
}

// 10 CROP TYPES WITH CRITICAL TRACKING FEATURES
export const CROP_THRESHOLDS: Record<string, CropThreshold> = {
  wheat: {
    minYieldTonPerHa: 3.0,
    idealProteinPercent: { min: 11, max: 15 },
    idealMoisturePercent: { min: 12, max: 14 },
    sprayIntervalDays: 14,
  },
  "sugar beet": {
    minYieldTonPerHa: 50.0,
    idealSugarPercent: { min: 16, max: 20 },
    idealMoisturePercent: { min: 70, max: 80 },
    sprayIntervalDays: 21,
  },
  corn: {
    minYieldTonPerHa: 7.5,
    idealMoisturePercent: { min: 13, max: 15 },
    idealProteinPercent: { min: 8, max: 11 },
    sprayIntervalDays: 14,
  },
  cotton: {
    minYieldTonPerHa: 3.0,
    idealMoisturePercent: { min: 7, max: 9 },
    sprayIntervalDays: 10,
  },
  sunflower: {
    minYieldTonPerHa: 2.2,
    idealOilPercent: { min: 40, max: 50 },
    idealMoisturePercent: { min: 8, max: 10 },
    sprayIntervalDays: 18,
  },
  tomato: {
    minYieldTonPerHa: 60.0,
    idealMoisturePercent: { min: 93, max: 95 },
    sprayIntervalDays: 7,
  },
  grape: {
    // Quality wine growers deliberately cap yield as low as 6 t/ha, so
    // this floor sits well below that rather than penalizing them.
    minYieldTonPerHa: 5.0,
    idealSugarPercent: { min: 17, max: 25 },
    idealMoisturePercent: { min: 75, max: 85 },
    sprayIntervalDays: 14,
  },
  olive: {
    // Olives alternate-bear (yield swings year to year naturally); a lower
    // floor reduces, though doesn't eliminate, false alerts in "off" years.
    minYieldTonPerHa: 2.5,
    idealOilPercent: { min: 15, max: 25 },
    idealMoisturePercent: { min: 45, max: 55 },
    sprayIntervalDays: 21,
  },
  rice: {
    minYieldTonPerHa: 4.0,
    idealMoisturePercent: { min: 12, max: 14 },
    idealProteinPercent: { min: 6, max: 8 },
    sprayIntervalDays: 14,
  },
  soybean: {
    minYieldTonPerHa: 2.5,
    idealProteinPercent: { min: 38, max: 42 },
    idealMoisturePercent: { min: 12, max: 14 },
    sprayIntervalDays: 18,
  },
};

// 10 LIVESTOCK TYPES WITH CRITICAL TRACKING FEATURES
export const LIVESTOCK_THRESHOLDS: Record<string, LivestockThreshold> = {
  cow: {
    minDailyMilkL: 15.0,
    minMilkFatPercent: 3.2,
    idealWeightKg: 550,
    minWeightKg: 400,
    maxWeightKg: 700,
    idealDailyFeedKg: 20,
  },
  sheep: {
    // Dairy breeds (e.g. Sakız, Awassi) are commonly milked in Turkey;
    // Awassi yields ~1-3 L/day, milk is notably higher-fat than cow/goat.
    minDailyMilkL: 1.0,
    minMilkFatPercent: 5.5,
    idealWeightKg: 70,
    minWeightKg: 40,
    maxWeightKg: 100,
    idealDailyFeedKg: 2,
  },
  goat: {
    minDailyMilkL: 2.5,
    minMilkFatPercent: 3.4,
    idealWeightKg: 55,
    minWeightKg: 30,
    maxWeightKg: 80,
    idealDailyFeedKg: 2.5,
  },
  chicken: {
    minDailyEggs: 0.7, // 70% laying rate per day
    idealWeightKg: 2.0,
    minWeightKg: 1.5,
    maxWeightKg: 2.5,
    idealDailyFeedKg: 0.12,
  },
  duck: {
    minDailyEggs: 0.8,
    idealWeightKg: 3.0,
    minWeightKg: 2.0,
    maxWeightKg: 4.0,
    idealDailyFeedKg: 0.15,
  },
  turkey: {
    idealWeightKg: 12,
    minWeightKg: 8,
    maxWeightKg: 16,
    idealDailyFeedKg: 0.35,
  },
  bee: {
    // Honey is harvested seasonally, not daily, so it's checked as a
    // rolling-365-day total rather than a daily minimum. 20-27 kg/hive/year
    // is a typical average; this floor sits comfortably below that.
    minHoneyKgPerYear: 15,
  },
  fish: {
    idealWeightKg: 1.0,
    minWeightKg: 0.2,
    maxWeightKg: 3.0,
    idealDailyFeedKg: 0.03,
    // Rainbow trout ranges (10-15C ideal growth, stress from ~20C) rather
    // than warm-water species like tilapia (needs >20C): trout farming is
    // by far the dominant freshwater aquaculture in Turkey. Revisit if the
    // app ever needs to support warm-water species too.
    idealWaterTemperatureC: { min: 8, max: 20 },
    idealWaterPh: { min: 6.5, max: 8.5 },
  },
  buffalo: {
    minDailyMilkL: 7.5,
    minMilkFatPercent: 6.5,
    idealWeightKg: 600,
    minWeightKg: 450,
    maxWeightKg: 800,
    idealDailyFeedKg: 25,
  },
  camel: {
    minDailyMilkL: 6.0,
    minMilkFatPercent: 3.5,
    idealWeightKg: 500,
    minWeightKg: 300,
    maxWeightKg: 700,
    idealDailyFeedKg: 15,
  },
};

// Helper function to normalize type names
export function normalizeType(type: string): string {
  return type.trim().toLowerCase();
}

// Get crop threshold by type
export function getCropThreshold(cropType: string): CropThreshold | undefined {
  return CROP_THRESHOLDS[normalizeType(cropType)];
}

// Get livestock threshold by type
export function getLivestockThreshold(
  animalType: string,
): LivestockThreshold | undefined {
  return LIVESTOCK_THRESHOLDS[normalizeType(animalType)];
}

// Check if value is within ideal range
export function isInRange(
  value: number,
  range: { min: number; max: number },
): boolean {
  return value >= range.min && value <= range.max;
}

// Get display names for types (Turkish)
export const CROP_DISPLAY_NAMES: Record<string, string> = {
  wheat: "Buğday",
  "sugar beet": "Pancar",
  corn: "Mısır",
  cotton: "Pamuk",
  sunflower: "Ayçiçeği",
  tomato: "Domates",
  grape: "Üzüm",
  olive: "Zeytin",
  rice: "Pirinç",
  soybean: "Soya",
};

export const LIVESTOCK_DISPLAY_NAMES: Record<string, string> = {
  cow: "İnek",
  sheep: "Koyun",
  goat: "Keçi",
  chicken: "Tavuk",
  duck: "Ördek",
  turkey: "Hindi",
  bee: "Arı",
  fish: "Balık",
  buffalo: "Manda",
  camel: "Deve",
};
