export type FieldType = "text" | "number" | "integer" | "date" | "choice";

export type FieldGroup =
  | "general"
  | "health"
  | "production"
  | "schedule"
  | "environment";

export interface AutoNextConfig {
  key: string;
  intervalDays: number;
}

export interface TypeFieldConfig {
  key: string;
  labelKey: string;
  type: FieldType;
  group: FieldGroup;
  choices?: string[];
  autoNext?: AutoNextConfig;
  summary?: boolean;
}

export interface TypeFieldsConfig {
  fields: TypeFieldConfig[];
  summaryKeys?: string[];
}

type TypeFieldDictionary = Record<string, TypeFieldsConfig>;

const COMMON_CHOICES = {
  estrusStatus: ["inactive", "in_heat", "pregnant"],
  woolQuality: ["A", "B", "C"],
  feedType: ["layer", "mixed", "organic"],
  duckFeedType: ["pellet", "mixed", "forage"],
  turkeyLighting: [],
  hiveHealthStatus: ["strong", "moderate", "weak"],
  queenStatus: ["present", "replaced", "missing"],
  pollinationStatus: ["pending", "in_progress", "completed"],
  growthStage: ["vegetative", "squaring", "flowering", "boll"],
  irrigationMethod: ["rainfed", "sprinkler", "drip"],
  beetIrrigationMethod: ["furrow", "sprinkler", "drip"],
  tomatoGreenhouse: ["open_field", "tunnel", "glasshouse"],
  grapeTrellis: ["bush", "vertical", "guyot", "pergola"],
  oliveOilExtraction: ["cold_press", "centrifuge", "traditional"],
  fertilizationMethod: ["broadcast", "foliar", "banded"],
  nodulationScore: ["poor", "moderate", "good"],
};

export const LIVESTOCK_TYPE_FIELDS: TypeFieldDictionary = {
  cow: {
    fields: [
      {
        key: "estrusStatus",
        labelKey: "field.livestock.cow.estrusStatus",
        type: "choice",
        group: "health",
        choices: COMMON_CHOICES.estrusStatus,
      },
      {
        key: "lastEstrusDate",
        labelKey: "field.livestock.cow.lastEstrusDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextEstrusCheckDate", intervalDays: 21 },
      },
      {
        key: "nextEstrusCheckDate",
        labelKey: "field.livestock.cow.nextEstrusCheckDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "calvingCount",
        labelKey: "field.livestock.cow.calvingCount",
        type: "integer",
        group: "production",
      },
      {
        key: "lastCalvingDate",
        labelKey: "field.livestock.cow.lastCalvingDate",
        type: "date",
        group: "production",
        autoNext: { key: "expectedCalvingDate", intervalDays: 280 },
      },
      {
        key: "expectedCalvingDate",
        labelKey: "field.livestock.cow.expectedCalvingDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "lastVetVisit",
        labelKey: "field.livestock.cow.lastVetVisit",
        type: "date",
        group: "health",
        autoNext: { key: "nextVetVisit", intervalDays: 180 },
      },
      {
        key: "nextVetVisit",
        labelKey: "field.livestock.cow.nextVetVisit",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["nextEstrusCheckDate", "expectedCalvingDate", "nextVetVisit"],
  },
  sheep: {
    fields: [
      {
        key: "lambCount",
        labelKey: "field.livestock.sheep.lambCount",
        type: "integer",
        group: "production",
      },
      {
        key: "lastShearingDate",
        labelKey: "field.livestock.sheep.lastShearingDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextShearingDate", intervalDays: 180 },
      },
      {
        key: "nextShearingDate",
        labelKey: "field.livestock.sheep.nextShearingDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "woolQuality",
        labelKey: "field.livestock.sheep.woolQuality",
        type: "choice",
        group: "production",
        choices: COMMON_CHOICES.woolQuality,
      },
      {
        key: "hoofTrimDate",
        labelKey: "field.livestock.sheep.hoofTrimDate",
        type: "date",
        group: "health",
        autoNext: { key: "nextHoofTrimDate", intervalDays: 120 },
      },
      {
        key: "nextHoofTrimDate",
        labelKey: "field.livestock.sheep.nextHoofTrimDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["nextShearingDate", "nextHoofTrimDate"],
  },
  goat: {
    fields: [
      {
        key: "kiddingCount",
        labelKey: "field.livestock.goat.kiddingCount",
        type: "integer",
        group: "production",
      },
      {
        key: "lastDewormingDate",
        labelKey: "field.livestock.goat.lastDewormingDate",
        type: "date",
        group: "health",
        autoNext: { key: "nextDewormingDate", intervalDays: 180 },
      },
      {
        key: "nextDewormingDate",
        labelKey: "field.livestock.goat.nextDewormingDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "milkFatBenchmark",
        labelKey: "field.livestock.goat.milkFatBenchmark",
        type: "number",
        group: "production",
      },
      {
        key: "hoofTrimDate",
        labelKey: "field.livestock.goat.hoofTrimDate",
        type: "date",
        group: "health",
        autoNext: { key: "nextHoofTrimDate", intervalDays: 150 },
      },
      {
        key: "nextHoofTrimDate",
        labelKey: "field.livestock.goat.nextHoofTrimDate",
        type: "date",
        group: "schedule",
      },
    ],
    summaryKeys: ["nextDewormingDate", "nextHoofTrimDate"],
  },
  chicken: {
    fields: [
      {
        key: "layingRate",
        labelKey: "field.livestock.chicken.layingRate",
        type: "number",
        group: "production",
        summary: true,
      },
      {
        key: "feedType",
        labelKey: "field.livestock.chicken.feedType",
        type: "choice",
        group: "general",
        choices: COMMON_CHOICES.feedType,
      },
      {
        key: "lastVaccinationDate",
        labelKey: "field.livestock.chicken.lastVaccinationDate",
        type: "date",
        group: "health",
        autoNext: { key: "nextVaccinationDate", intervalDays: 180 },
      },
      {
        key: "nextVaccinationDate",
        labelKey: "field.livestock.chicken.nextVaccinationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "coopTemperature",
        labelKey: "field.livestock.chicken.coopTemperature",
        type: "number",
        group: "environment",
      },
    ],
    summaryKeys: ["layingRate", "nextVaccinationDate"],
  },
  duck: {
    fields: [
      {
        key: "averageEggsWeekly",
        labelKey: "field.livestock.duck.averageEggsWeekly",
        type: "number",
        group: "production",
        summary: true,
      },
      {
        key: "waterAccessHours",
        labelKey: "field.livestock.duck.waterAccessHours",
        type: "number",
        group: "environment",
      },
      {
        key: "pondCleanedAt",
        labelKey: "field.livestock.duck.pondCleanedAt",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextPondCleaningDate", intervalDays: 30 },
      },
      {
        key: "nextPondCleaningDate",
        labelKey: "field.livestock.duck.nextPondCleaningDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "feedType",
        labelKey: "field.livestock.duck.feedType",
        type: "choice",
        group: "general",
        choices: COMMON_CHOICES.duckFeedType,
      },
    ],
    summaryKeys: ["averageEggsWeekly", "nextPondCleaningDate"],
  },
  turkey: {
    fields: [
      {
        key: "weightGainWeekly",
        labelKey: "field.livestock.turkey.weightGainWeekly",
        type: "number",
        group: "production",
        summary: true,
      },
      {
        key: "feedConversionRatio",
        labelKey: "field.livestock.turkey.feedConversionRatio",
        type: "number",
        group: "production",
      },
      {
        key: "lastHealthCheckDate",
        labelKey: "field.livestock.turkey.lastHealthCheckDate",
        type: "date",
        group: "health",
        autoNext: { key: "nextHealthCheckDate", intervalDays: 90 },
      },
      {
        key: "nextHealthCheckDate",
        labelKey: "field.livestock.turkey.nextHealthCheckDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "lightingHours",
        labelKey: "field.livestock.turkey.lightingHours",
        type: "number",
        group: "environment",
      },
    ],
    summaryKeys: ["weightGainWeekly", "nextHealthCheckDate"],
  },
  bee: {
    fields: [
      {
        key: "hiveHealthStatus",
        labelKey: "field.livestock.bee.hiveHealthStatus",
        type: "choice",
        group: "health",
        choices: COMMON_CHOICES.hiveHealthStatus,
        summary: true,
      },
      {
        key: "queenStatus",
        labelKey: "field.livestock.bee.queenStatus",
        type: "choice",
        group: "health",
        choices: COMMON_CHOICES.queenStatus,
      },
      {
        key: "lastInspectionDate",
        labelKey: "field.livestock.bee.lastInspectionDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextInspectionDate", intervalDays: 21 },
      },
      {
        key: "nextInspectionDate",
        labelKey: "field.livestock.bee.nextInspectionDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "honeySupersCount",
        labelKey: "field.livestock.bee.honeySupersCount",
        type: "integer",
        group: "production",
      },
    ],
    summaryKeys: ["hiveHealthStatus", "nextInspectionDate"],
  },
  fish: {
    fields: [
      {
        key: "waterTemperature",
        labelKey: "field.livestock.fish.waterTemperature",
        type: "number",
        group: "environment",
        summary: true,
      },
      {
        key: "waterPh",
        labelKey: "field.livestock.fish.waterPh",
        type: "number",
        group: "environment",
      },
      {
        key: "lastFeedingDate",
        labelKey: "field.livestock.fish.lastFeedingDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFeedingDate", intervalDays: 1 },
      },
      {
        key: "nextFeedingDate",
        labelKey: "field.livestock.fish.nextFeedingDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "avgWeightPerFish",
        labelKey: "field.livestock.fish.avgWeightPerFish",
        type: "number",
        group: "production",
      },
    ],
    summaryKeys: ["waterTemperature", "nextFeedingDate"],
  },
  buffalo: {
    fields: [
      {
        key: "calvingCount",
        labelKey: "field.livestock.buffalo.calvingCount",
        type: "integer",
        group: "production",
      },
      {
        key: "lastMudBathDate",
        labelKey: "field.livestock.buffalo.lastMudBathDate",
        type: "date",
        group: "environment",
        autoNext: { key: "nextMudBathDate", intervalDays: 7 },
      },
      {
        key: "nextMudBathDate",
        labelKey: "field.livestock.buffalo.nextMudBathDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "milkFatBenchmark",
        labelKey: "field.livestock.buffalo.milkFatBenchmark",
        type: "number",
        group: "production",
      },
      {
        key: "lastVetVisit",
        labelKey: "field.livestock.buffalo.lastVetVisit",
        type: "date",
        group: "health",
        autoNext: { key: "nextVetVisit", intervalDays: 150 },
      },
      {
        key: "nextVetVisit",
        labelKey: "field.livestock.buffalo.nextVetVisit",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["nextMudBathDate", "nextVetVisit"],
  },
  camel: {
    fields: [
      {
        key: "lastTrekDate",
        labelKey: "field.livestock.camel.lastTrekDate",
        type: "date",
        group: "environment",
        autoNext: { key: "nextHoofCareDate", intervalDays: 30 },
      },
      {
        key: "nextHoofCareDate",
        labelKey: "field.livestock.camel.nextHoofCareDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "waterIntakeDaily",
        labelKey: "field.livestock.camel.waterIntakeDaily",
        type: "number",
        group: "health",
      },
      {
        key: "gestationStatus",
        labelKey: "field.livestock.camel.gestationStatus",
        type: "choice",
        group: "health",
        choices: ["open", "mated", "pregnant"],
      },
      {
        key: "expectedCalvingDate",
        labelKey: "field.livestock.camel.expectedCalvingDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["nextHoofCareDate", "expectedCalvingDate"],
  },
};

export const CROP_TYPE_FIELDS: TypeFieldDictionary = {
  wheat: {
    fields: [
      {
        key: "variety",
        labelKey: "field.crop.wheat.variety",
        type: "text",
        group: "general",
      },
      {
        key: "irrigationMethod",
        labelKey: "field.crop.wheat.irrigationMethod",
        type: "choice",
        group: "environment",
        choices: COMMON_CHOICES.irrigationMethod,
      },
      {
        key: "lastIrrigationDate",
        labelKey: "field.crop.wheat.lastIrrigationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextIrrigationDate", intervalDays: 7 },
      },
      {
        key: "nextIrrigationDate",
        labelKey: "field.crop.wheat.nextIrrigationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "fertilizerType",
        labelKey: "field.crop.wheat.fertilizerType",
        type: "text",
        group: "production",
      },
      {
        key: "fertilizationMethod",
        labelKey: "field.crop.wheat.fertilizationMethod",
        type: "choice",
        group: "production",
        choices: COMMON_CHOICES.fertilizationMethod,
      },
      {
        key: "lastFertilizationDate",
        labelKey: "field.crop.wheat.lastFertilizationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFertilizationDate", intervalDays: 30 },
      },
      {
        key: "nextFertilizationDate",
        labelKey: "field.crop.wheat.nextFertilizationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "soilMoisture",
        labelKey: "field.crop.wheat.soilMoisture",
        type: "number",
        group: "environment",
      },
    ],
    summaryKeys: ["nextIrrigationDate", "nextFertilizationDate"],
  },
  "sugar beet": {
    fields: [
      {
        key: "variety",
        labelKey: "field.crop.sugar_beet.variety",
        type: "text",
        group: "general",
      },
      {
        key: "irrigationMethod",
        labelKey: "field.crop.sugar_beet.irrigationMethod",
        type: "choice",
        group: "environment",
        choices: COMMON_CHOICES.beetIrrigationMethod,
      },
      {
        key: "lastIrrigationDate",
        labelKey: "field.crop.sugar_beet.lastIrrigationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextIrrigationDate", intervalDays: 5 },
      },
      {
        key: "nextIrrigationDate",
        labelKey: "field.crop.sugar_beet.nextIrrigationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "lastFertilizationDate",
        labelKey: "field.crop.sugar_beet.lastFertilizationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFertilizationDate", intervalDays: 25 },
      },
      {
        key: "nextFertilizationDate",
        labelKey: "field.crop.sugar_beet.nextFertilizationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "sugarPercentTarget",
        labelKey: "field.crop.sugar_beet.sugarPercentTarget",
        type: "number",
        group: "production",
      },
      {
        key: "rootDiameter",
        labelKey: "field.crop.sugar_beet.rootDiameter",
        type: "number",
        group: "production",
      },
    ],
    summaryKeys: ["nextIrrigationDate", "nextFertilizationDate"],
  },
  corn: {
    fields: [
      {
        key: "hybrid",
        labelKey: "field.crop.corn.hybrid",
        type: "text",
        group: "general",
      },
      {
        key: "lastIrrigationDate",
        labelKey: "field.crop.corn.lastIrrigationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextIrrigationDate", intervalDays: 4 },
      },
      {
        key: "nextIrrigationDate",
        labelKey: "field.crop.corn.nextIrrigationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "silkingDate",
        labelKey: "field.crop.corn.silkingDate",
        type: "date",
        group: "production",
      },
      {
        key: "pollinationStatus",
        labelKey: "field.crop.corn.pollinationStatus",
        type: "choice",
        group: "production",
        choices: COMMON_CHOICES.pollinationStatus,
      },
      {
        key: "lastFertilizationDate",
        labelKey: "field.crop.corn.lastFertilizationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFertilizationDate", intervalDays: 20 },
      },
      {
        key: "nextFertilizationDate",
        labelKey: "field.crop.corn.nextFertilizationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["nextIrrigationDate", "nextFertilizationDate"],
  },
  cotton: {
    fields: [
      {
        key: "variety",
        labelKey: "field.crop.cotton.variety",
        type: "text",
        group: "general",
      },
      {
        key: "lastIrrigationDate",
        labelKey: "field.crop.cotton.lastIrrigationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextIrrigationDate", intervalDays: 6 },
      },
      {
        key: "nextIrrigationDate",
        labelKey: "field.crop.cotton.nextIrrigationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "bollCount",
        labelKey: "field.crop.cotton.bollCount",
        type: "integer",
        group: "production",
      },
      {
        key: "growthStage",
        labelKey: "field.crop.cotton.growthStage",
        type: "choice",
        group: "production",
        choices: COMMON_CHOICES.growthStage,
      },
      {
        key: "lastFertilizationDate",
        labelKey: "field.crop.cotton.lastFertilizationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFertilizationDate", intervalDays: 18 },
      },
      {
        key: "nextFertilizationDate",
        labelKey: "field.crop.cotton.nextFertilizationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["nextIrrigationDate", "nextFertilizationDate"],
  },
  sunflower: {
    fields: [
      {
        key: "hybrid",
        labelKey: "field.crop.sunflower.hybrid",
        type: "text",
        group: "general",
      },
      {
        key: "lastIrrigationDate",
        labelKey: "field.crop.sunflower.lastIrrigationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextIrrigationDate", intervalDays: 10 },
      },
      {
        key: "nextIrrigationDate",
        labelKey: "field.crop.sunflower.nextIrrigationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "headDiameter",
        labelKey: "field.crop.sunflower.headDiameter",
        type: "number",
        group: "production",
      },
      {
        key: "oilPercentTarget",
        labelKey: "field.crop.sunflower.oilPercentTarget",
        type: "number",
        group: "production",
      },
      {
        key: "lastFertilizationDate",
        labelKey: "field.crop.sunflower.lastFertilizationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFertilizationDate", intervalDays: 28 },
      },
      {
        key: "nextFertilizationDate",
        labelKey: "field.crop.sunflower.nextFertilizationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["nextIrrigationDate", "nextFertilizationDate"],
  },
  tomato: {
    fields: [
      {
        key: "variety",
        labelKey: "field.crop.tomato.variety",
        type: "text",
        group: "general",
      },
      {
        key: "greenhouse",
        labelKey: "field.crop.tomato.greenhouse",
        type: "choice",
        group: "environment",
        choices: COMMON_CHOICES.tomatoGreenhouse,
      },
      {
        key: "lastIrrigationDate",
        labelKey: "field.crop.tomato.lastIrrigationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextIrrigationDate", intervalDays: 2 },
      },
      {
        key: "nextIrrigationDate",
        labelKey: "field.crop.tomato.nextIrrigationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "lastPruningDate",
        labelKey: "field.crop.tomato.lastPruningDate",
        type: "date",
        group: "production",
        autoNext: { key: "nextPruningDate", intervalDays: 14 },
      },
      {
        key: "nextPruningDate",
        labelKey: "field.crop.tomato.nextPruningDate",
        type: "date",
        group: "schedule",
      },
      {
        key: "lastFertilizationDate",
        labelKey: "field.crop.tomato.lastFertilizationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFertilizationDate", intervalDays: 10 },
      },
      {
        key: "nextFertilizationDate",
        labelKey: "field.crop.tomato.nextFertilizationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["nextIrrigationDate", "nextFertilizationDate"],
  },
  grape: {
    fields: [
      {
        key: "variety",
        labelKey: "field.crop.grape.variety",
        type: "text",
        group: "general",
      },
      {
        key: "trellisType",
        labelKey: "field.crop.grape.trellisType",
        type: "choice",
        group: "environment",
        choices: COMMON_CHOICES.grapeTrellis,
      },
      {
        key: "lastIrrigationDate",
        labelKey: "field.crop.grape.lastIrrigationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextIrrigationDate", intervalDays: 12 },
      },
      {
        key: "nextIrrigationDate",
        labelKey: "field.crop.grape.nextIrrigationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "brixLevel",
        labelKey: "field.crop.grape.brixLevel",
        type: "number",
        group: "production",
        summary: true,
      },
      {
        key: "lastCanopyWorkDate",
        labelKey: "field.crop.grape.lastCanopyWorkDate",
        type: "date",
        group: "production",
        autoNext: { key: "nextCanopyWorkDate", intervalDays: 20 },
      },
      {
        key: "nextCanopyWorkDate",
        labelKey: "field.crop.grape.nextCanopyWorkDate",
        type: "date",
        group: "schedule",
      },
    ],
    summaryKeys: ["nextIrrigationDate", "brixLevel"],
  },
  olive: {
    fields: [
      {
        key: "variety",
        labelKey: "field.crop.olive.variety",
        type: "text",
        group: "general",
      },
      {
        key: "lastIrrigationDate",
        labelKey: "field.crop.olive.lastIrrigationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextIrrigationDate", intervalDays: 14 },
      },
      {
        key: "nextIrrigationDate",
        labelKey: "field.crop.olive.nextIrrigationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "lastPruningDate",
        labelKey: "field.crop.olive.lastPruningDate",
        type: "date",
        group: "production",
        autoNext: { key: "nextPruningDate", intervalDays: 365 },
      },
      {
        key: "nextPruningDate",
        labelKey: "field.crop.olive.nextPruningDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "oilExtractionMethod",
        labelKey: "field.crop.olive.oilExtractionMethod",
        type: "choice",
        group: "production",
        choices: COMMON_CHOICES.oliveOilExtraction,
      },
      {
        key: "fruitLoadIndex",
        labelKey: "field.crop.olive.fruitLoadIndex",
        type: "number",
        group: "production",
      },
    ],
    summaryKeys: ["nextIrrigationDate", "nextPruningDate"],
  },
  rice: {
    fields: [
      {
        key: "variety",
        labelKey: "field.crop.rice.variety",
        type: "text",
        group: "general",
      },
      {
        key: "waterDepth",
        labelKey: "field.crop.rice.waterDepth",
        type: "number",
        group: "environment",
        summary: true,
      },
      {
        key: "lastFloodDate",
        labelKey: "field.crop.rice.lastFloodDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFloodDate", intervalDays: 3 },
      },
      {
        key: "nextFloodDate",
        labelKey: "field.crop.rice.nextFloodDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "lastFertilizationDate",
        labelKey: "field.crop.rice.lastFertilizationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFertilizationDate", intervalDays: 15 },
      },
      {
        key: "nextFertilizationDate",
        labelKey: "field.crop.rice.nextFertilizationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["waterDepth", "nextFloodDate", "nextFertilizationDate"],
  },
  soybean: {
    fields: [
      {
        key: "variety",
        labelKey: "field.crop.soybean.variety",
        type: "text",
        group: "general",
      },
      {
        key: "lastIrrigationDate",
        labelKey: "field.crop.soybean.lastIrrigationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextIrrigationDate", intervalDays: 6 },
      },
      {
        key: "nextIrrigationDate",
        labelKey: "field.crop.soybean.nextIrrigationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
      {
        key: "nodulationScore",
        labelKey: "field.crop.soybean.nodulationScore",
        type: "choice",
        group: "production",
        choices: COMMON_CHOICES.nodulationScore,
      },
      {
        key: "lastInoculationDate",
        labelKey: "field.crop.soybean.lastInoculationDate",
        type: "date",
        group: "production",
        autoNext: { key: "nextInoculationDate", intervalDays: 365 },
      },
      {
        key: "nextInoculationDate",
        labelKey: "field.crop.soybean.nextInoculationDate",
        type: "date",
        group: "schedule",
      },
      {
        key: "lastFertilizationDate",
        labelKey: "field.crop.soybean.lastFertilizationDate",
        type: "date",
        group: "schedule",
        autoNext: { key: "nextFertilizationDate", intervalDays: 20 },
      },
      {
        key: "nextFertilizationDate",
        labelKey: "field.crop.soybean.nextFertilizationDate",
        type: "date",
        group: "schedule",
        summary: true,
      },
    ],
    summaryKeys: ["nextIrrigationDate", "nextFertilizationDate"],
  },
};

export function getLivestockFieldConfig(type: string): TypeFieldsConfig | undefined {
  return LIVESTOCK_TYPE_FIELDS[type.trim().toLowerCase()];
}

export function getCropFieldConfig(type: string): TypeFieldsConfig | undefined {
  return CROP_TYPE_FIELDS[type.trim().toLowerCase()];
}
