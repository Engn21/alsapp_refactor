enum FieldInputType { text, number, integer, date, choice }

class AutoNextConfig {
  final String key;
  final int intervalDays;

  const AutoNextConfig({
    required this.key,
    required this.intervalDays,
  });
}

class TypeFieldDefinition {
  final String key;
  final String labelKey;
  final FieldInputType type;
  final String group;
  final List<String>? choices;
  final AutoNextConfig? autoNext;
  final bool summary;

  const TypeFieldDefinition({
    required this.key,
    required this.labelKey,
    required this.type,
    required this.group,
    this.choices,
    this.autoNext,
    this.summary = false,
  });
}

class TypeFieldsConfig {
  final List<TypeFieldDefinition> fields;
  final List<String> summaryKeys;

  const TypeFieldsConfig({
    required this.fields,
    this.summaryKeys = const [],
  });
}

TypeFieldsConfig? getLivestockFields(String type) {
  final key = type.trim().toLowerCase();
  return livestockTypeFields[key];
}

TypeFieldsConfig? getCropFields(String type) {
  final key = type.trim().toLowerCase();
  return cropTypeFields[key];
}

const Map<String, TypeFieldsConfig> livestockTypeFields = {
  'cow': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'estrusStatus',
        labelKey: 'field.livestock.cow.estrusStatus',
        type: FieldInputType.choice,
        group: 'health',
        choices: ['inactive', 'in_heat', 'pregnant'],
      ),
      TypeFieldDefinition(
        key: 'lastEstrusDate',
        labelKey: 'field.livestock.cow.lastEstrusDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextEstrusCheckDate',
          intervalDays: 21,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextEstrusCheckDate',
        labelKey: 'field.livestock.cow.nextEstrusCheckDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'calvingCount',
        labelKey: 'field.livestock.cow.calvingCount',
        type: FieldInputType.integer,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'lastCalvingDate',
        labelKey: 'field.livestock.cow.lastCalvingDate',
        type: FieldInputType.date,
        group: 'production',
        autoNext: AutoNextConfig(
          key: 'expectedCalvingDate',
          intervalDays: 280,
        ),
      ),
      TypeFieldDefinition(
        key: 'expectedCalvingDate',
        labelKey: 'field.livestock.cow.expectedCalvingDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'lastVetVisit',
        labelKey: 'field.livestock.cow.lastVetVisit',
        type: FieldInputType.date,
        group: 'health',
        autoNext: AutoNextConfig(
          key: 'nextVetVisit',
          intervalDays: 180,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextVetVisit',
        labelKey: 'field.livestock.cow.nextVetVisit',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: [
      'nextEstrusCheckDate',
      'expectedCalvingDate',
      'nextVetVisit',
    ],
  ),
  'sheep': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'lambCount',
        labelKey: 'field.livestock.sheep.lambCount',
        type: FieldInputType.integer,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'lastShearingDate',
        labelKey: 'field.livestock.sheep.lastShearingDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextShearingDate',
          intervalDays: 180,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextShearingDate',
        labelKey: 'field.livestock.sheep.nextShearingDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'woolQuality',
        labelKey: 'field.livestock.sheep.woolQuality',
        type: FieldInputType.choice,
        group: 'production',
        choices: ['A', 'B', 'C'],
      ),
      TypeFieldDefinition(
        key: 'hoofTrimDate',
        labelKey: 'field.livestock.sheep.hoofTrimDate',
        type: FieldInputType.date,
        group: 'health',
        autoNext: AutoNextConfig(
          key: 'nextHoofTrimDate',
          intervalDays: 120,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextHoofTrimDate',
        labelKey: 'field.livestock.sheep.nextHoofTrimDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: ['nextShearingDate', 'nextHoofTrimDate'],
  ),
  'goat': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'kiddingCount',
        labelKey: 'field.livestock.goat.kiddingCount',
        type: FieldInputType.integer,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'lastDewormingDate',
        labelKey: 'field.livestock.goat.lastDewormingDate',
        type: FieldInputType.date,
        group: 'health',
        autoNext: AutoNextConfig(
          key: 'nextDewormingDate',
          intervalDays: 180,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextDewormingDate',
        labelKey: 'field.livestock.goat.nextDewormingDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'milkFatBenchmark',
        labelKey: 'field.livestock.goat.milkFatBenchmark',
        type: FieldInputType.number,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'hoofTrimDate',
        labelKey: 'field.livestock.goat.hoofTrimDate',
        type: FieldInputType.date,
        group: 'health',
        autoNext: AutoNextConfig(
          key: 'nextHoofTrimDate',
          intervalDays: 150,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextHoofTrimDate',
        labelKey: 'field.livestock.goat.nextHoofTrimDate',
        type: FieldInputType.date,
        group: 'schedule',
      ),
    ],
    summaryKeys: ['nextDewormingDate', 'nextHoofTrimDate'],
  ),
  'chicken': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'layingRate',
        labelKey: 'field.livestock.chicken.layingRate',
        type: FieldInputType.number,
        group: 'production',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'feedType',
        labelKey: 'field.livestock.chicken.feedType',
        type: FieldInputType.choice,
        group: 'general',
        choices: ['layer', 'mixed', 'organic'],
      ),
      TypeFieldDefinition(
        key: 'lastVaccinationDate',
        labelKey: 'field.livestock.chicken.lastVaccinationDate',
        type: FieldInputType.date,
        group: 'health',
        autoNext: AutoNextConfig(
          key: 'nextVaccinationDate',
          intervalDays: 180,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextVaccinationDate',
        labelKey: 'field.livestock.chicken.nextVaccinationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'coopTemperature',
        labelKey: 'field.livestock.chicken.coopTemperature',
        type: FieldInputType.number,
        group: 'environment',
      ),
    ],
    summaryKeys: ['layingRate', 'nextVaccinationDate'],
  ),
  'duck': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'averageEggsWeekly',
        labelKey: 'field.livestock.duck.averageEggsWeekly',
        type: FieldInputType.number,
        group: 'production',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'waterAccessHours',
        labelKey: 'field.livestock.duck.waterAccessHours',
        type: FieldInputType.number,
        group: 'environment',
      ),
      TypeFieldDefinition(
        key: 'pondCleanedAt',
        labelKey: 'field.livestock.duck.pondCleanedAt',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextPondCleaningDate',
          intervalDays: 30,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextPondCleaningDate',
        labelKey: 'field.livestock.duck.nextPondCleaningDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'feedType',
        labelKey: 'field.livestock.duck.feedType',
        type: FieldInputType.choice,
        group: 'general',
        choices: ['pellet', 'mixed', 'forage'],
      ),
    ],
    summaryKeys: ['averageEggsWeekly', 'nextPondCleaningDate'],
  ),
  'turkey': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'weightGainWeekly',
        labelKey: 'field.livestock.turkey.weightGainWeekly',
        type: FieldInputType.number,
        group: 'production',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'feedConversionRatio',
        labelKey: 'field.livestock.turkey.feedConversionRatio',
        type: FieldInputType.number,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'lastHealthCheckDate',
        labelKey: 'field.livestock.turkey.lastHealthCheckDate',
        type: FieldInputType.date,
        group: 'health',
        autoNext: AutoNextConfig(
          key: 'nextHealthCheckDate',
          intervalDays: 90,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextHealthCheckDate',
        labelKey: 'field.livestock.turkey.nextHealthCheckDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'lightingHours',
        labelKey: 'field.livestock.turkey.lightingHours',
        type: FieldInputType.number,
        group: 'environment',
      ),
    ],
    summaryKeys: ['weightGainWeekly', 'nextHealthCheckDate'],
  ),
  'bee': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'hiveHealthStatus',
        labelKey: 'field.livestock.bee.hiveHealthStatus',
        type: FieldInputType.choice,
        group: 'health',
        choices: ['strong', 'moderate', 'weak'],
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'queenStatus',
        labelKey: 'field.livestock.bee.queenStatus',
        type: FieldInputType.choice,
        group: 'health',
        choices: ['present', 'replaced', 'missing'],
      ),
      TypeFieldDefinition(
        key: 'lastInspectionDate',
        labelKey: 'field.livestock.bee.lastInspectionDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextInspectionDate',
          intervalDays: 21,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextInspectionDate',
        labelKey: 'field.livestock.bee.nextInspectionDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'honeySupersCount',
        labelKey: 'field.livestock.bee.honeySupersCount',
        type: FieldInputType.integer,
        group: 'production',
      ),
    ],
    summaryKeys: ['hiveHealthStatus', 'nextInspectionDate'],
  ),
  'fish': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'waterTemperature',
        labelKey: 'field.livestock.fish.waterTemperature',
        type: FieldInputType.number,
        group: 'environment',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'waterPh',
        labelKey: 'field.livestock.fish.waterPh',
        type: FieldInputType.number,
        group: 'environment',
      ),
      TypeFieldDefinition(
        key: 'lastFeedingDate',
        labelKey: 'field.livestock.fish.lastFeedingDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFeedingDate',
          intervalDays: 1,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFeedingDate',
        labelKey: 'field.livestock.fish.nextFeedingDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'avgWeightPerFish',
        labelKey: 'field.livestock.fish.avgWeightPerFish',
        type: FieldInputType.number,
        group: 'production',
      ),
    ],
    summaryKeys: ['waterTemperature', 'nextFeedingDate'],
  ),
  'buffalo': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'calvingCount',
        labelKey: 'field.livestock.buffalo.calvingCount',
        type: FieldInputType.integer,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'lastMudBathDate',
        labelKey: 'field.livestock.buffalo.lastMudBathDate',
        type: FieldInputType.date,
        group: 'environment',
        autoNext: AutoNextConfig(
          key: 'nextMudBathDate',
          intervalDays: 7,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextMudBathDate',
        labelKey: 'field.livestock.buffalo.nextMudBathDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'milkFatBenchmark',
        labelKey: 'field.livestock.buffalo.milkFatBenchmark',
        type: FieldInputType.number,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'lastVetVisit',
        labelKey: 'field.livestock.buffalo.lastVetVisit',
        type: FieldInputType.date,
        group: 'health',
        autoNext: AutoNextConfig(
          key: 'nextVetVisit',
          intervalDays: 150,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextVetVisit',
        labelKey: 'field.livestock.buffalo.nextVetVisit',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: ['nextMudBathDate', 'nextVetVisit'],
  ),
  'camel': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'lastTrekDate',
        labelKey: 'field.livestock.camel.lastTrekDate',
        type: FieldInputType.date,
        group: 'environment',
        autoNext: AutoNextConfig(
          key: 'nextHoofCareDate',
          intervalDays: 30,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextHoofCareDate',
        labelKey: 'field.livestock.camel.nextHoofCareDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'waterIntakeDaily',
        labelKey: 'field.livestock.camel.waterIntakeDaily',
        type: FieldInputType.number,
        group: 'health',
      ),
      TypeFieldDefinition(
        key: 'gestationStatus',
        labelKey: 'field.livestock.camel.gestationStatus',
        type: FieldInputType.choice,
        group: 'health',
        choices: ['open', 'mated', 'pregnant'],
      ),
      TypeFieldDefinition(
        key: 'expectedCalvingDate',
        labelKey: 'field.livestock.camel.expectedCalvingDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: ['nextHoofCareDate', 'expectedCalvingDate'],
  ),
};

const Map<String, TypeFieldsConfig> cropTypeFields = {
  'wheat': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'variety',
        labelKey: 'field.crop.wheat.variety',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'irrigationMethod',
        labelKey: 'field.crop.wheat.irrigationMethod',
        type: FieldInputType.choice,
        group: 'environment',
        choices: ['rainfed', 'sprinkler', 'drip'],
      ),
      TypeFieldDefinition(
        key: 'lastIrrigationDate',
        labelKey: 'field.crop.wheat.lastIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextIrrigationDate',
          intervalDays: 7,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextIrrigationDate',
        labelKey: 'field.crop.wheat.nextIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'fertilizerType',
        labelKey: 'field.crop.wheat.fertilizerType',
        type: FieldInputType.text,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'fertilizationMethod',
        labelKey: 'field.crop.wheat.fertilizationMethod',
        type: FieldInputType.choice,
        group: 'production',
        choices: ['broadcast', 'foliar', 'banded'],
      ),
      TypeFieldDefinition(
        key: 'lastFertilizationDate',
        labelKey: 'field.crop.wheat.lastFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFertilizationDate',
          intervalDays: 30,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFertilizationDate',
        labelKey: 'field.crop.wheat.nextFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'soilMoisture',
        labelKey: 'field.crop.wheat.soilMoisture',
        type: FieldInputType.number,
        group: 'environment',
      ),
    ],
    summaryKeys: ['nextIrrigationDate', 'nextFertilizationDate'],
  ),
  'sugar beet': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'variety',
        labelKey: 'field.crop.sugar_beet.variety',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'irrigationMethod',
        labelKey: 'field.crop.sugar_beet.irrigationMethod',
        type: FieldInputType.choice,
        group: 'environment',
        choices: ['furrow', 'sprinkler', 'drip'],
      ),
      TypeFieldDefinition(
        key: 'lastIrrigationDate',
        labelKey: 'field.crop.sugar_beet.lastIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextIrrigationDate',
          intervalDays: 5,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextIrrigationDate',
        labelKey: 'field.crop.sugar_beet.nextIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'lastFertilizationDate',
        labelKey: 'field.crop.sugar_beet.lastFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFertilizationDate',
          intervalDays: 25,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFertilizationDate',
        labelKey: 'field.crop.sugar_beet.nextFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'sugarPercentTarget',
        labelKey: 'field.crop.sugar_beet.sugarPercentTarget',
        type: FieldInputType.number,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'rootDiameter',
        labelKey: 'field.crop.sugar_beet.rootDiameter',
        type: FieldInputType.number,
        group: 'production',
      ),
    ],
    summaryKeys: ['nextIrrigationDate', 'nextFertilizationDate'],
  ),
  'corn': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'hybrid',
        labelKey: 'field.crop.corn.hybrid',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'lastIrrigationDate',
        labelKey: 'field.crop.corn.lastIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextIrrigationDate',
          intervalDays: 4,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextIrrigationDate',
        labelKey: 'field.crop.corn.nextIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'silkingDate',
        labelKey: 'field.crop.corn.silkingDate',
        type: FieldInputType.date,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'pollinationStatus',
        labelKey: 'field.crop.corn.pollinationStatus',
        type: FieldInputType.choice,
        group: 'production',
        choices: ['pending', 'in_progress', 'completed'],
      ),
      TypeFieldDefinition(
        key: 'lastFertilizationDate',
        labelKey: 'field.crop.corn.lastFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFertilizationDate',
          intervalDays: 20,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFertilizationDate',
        labelKey: 'field.crop.corn.nextFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: ['nextIrrigationDate', 'nextFertilizationDate'],
  ),
  'cotton': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'variety',
        labelKey: 'field.crop.cotton.variety',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'lastIrrigationDate',
        labelKey: 'field.crop.cotton.lastIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextIrrigationDate',
          intervalDays: 6,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextIrrigationDate',
        labelKey: 'field.crop.cotton.nextIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'bollCount',
        labelKey: 'field.crop.cotton.bollCount',
        type: FieldInputType.integer,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'growthStage',
        labelKey: 'field.crop.cotton.growthStage',
        type: FieldInputType.choice,
        group: 'production',
        choices: ['vegetative', 'squaring', 'flowering', 'boll'],
      ),
      TypeFieldDefinition(
        key: 'lastFertilizationDate',
        labelKey: 'field.crop.cotton.lastFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFertilizationDate',
          intervalDays: 18,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFertilizationDate',
        labelKey: 'field.crop.cotton.nextFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: ['nextIrrigationDate', 'nextFertilizationDate'],
  ),
  'sunflower': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'hybrid',
        labelKey: 'field.crop.sunflower.hybrid',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'lastIrrigationDate',
        labelKey: 'field.crop.sunflower.lastIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextIrrigationDate',
          intervalDays: 10,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextIrrigationDate',
        labelKey: 'field.crop.sunflower.nextIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'headDiameter',
        labelKey: 'field.crop.sunflower.headDiameter',
        type: FieldInputType.number,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'oilPercentTarget',
        labelKey: 'field.crop.sunflower.oilPercentTarget',
        type: FieldInputType.number,
        group: 'production',
      ),
      TypeFieldDefinition(
        key: 'lastFertilizationDate',
        labelKey: 'field.crop.sunflower.lastFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFertilizationDate',
          intervalDays: 28,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFertilizationDate',
        labelKey: 'field.crop.sunflower.nextFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: ['nextIrrigationDate', 'nextFertilizationDate'],
  ),
  'tomato': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'variety',
        labelKey: 'field.crop.tomato.variety',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'greenhouse',
        labelKey: 'field.crop.tomato.greenhouse',
        type: FieldInputType.choice,
        group: 'environment',
        choices: ['open_field', 'tunnel', 'glasshouse'],
      ),
      TypeFieldDefinition(
        key: 'lastIrrigationDate',
        labelKey: 'field.crop.tomato.lastIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextIrrigationDate',
          intervalDays: 2,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextIrrigationDate',
        labelKey: 'field.crop.tomato.nextIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'lastPruningDate',
        labelKey: 'field.crop.tomato.lastPruningDate',
        type: FieldInputType.date,
        group: 'production',
        autoNext: AutoNextConfig(
          key: 'nextPruningDate',
          intervalDays: 14,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextPruningDate',
        labelKey: 'field.crop.tomato.nextPruningDate',
        type: FieldInputType.date,
        group: 'schedule',
      ),
      TypeFieldDefinition(
        key: 'lastFertilizationDate',
        labelKey: 'field.crop.tomato.lastFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFertilizationDate',
          intervalDays: 10,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFertilizationDate',
        labelKey: 'field.crop.tomato.nextFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: ['nextIrrigationDate', 'nextFertilizationDate'],
  ),
  'grape': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'variety',
        labelKey: 'field.crop.grape.variety',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'trellisType',
        labelKey: 'field.crop.grape.trellisType',
        type: FieldInputType.choice,
        group: 'environment',
        choices: ['bush', 'vertical', 'guyot', 'pergola'],
      ),
      TypeFieldDefinition(
        key: 'lastIrrigationDate',
        labelKey: 'field.crop.grape.lastIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextIrrigationDate',
          intervalDays: 12,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextIrrigationDate',
        labelKey: 'field.crop.grape.nextIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'brixLevel',
        labelKey: 'field.crop.grape.brixLevel',
        type: FieldInputType.number,
        group: 'production',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'lastCanopyWorkDate',
        labelKey: 'field.crop.grape.lastCanopyWorkDate',
        type: FieldInputType.date,
        group: 'production',
        autoNext: AutoNextConfig(
          key: 'nextCanopyWorkDate',
          intervalDays: 20,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextCanopyWorkDate',
        labelKey: 'field.crop.grape.nextCanopyWorkDate',
        type: FieldInputType.date,
        group: 'schedule',
      ),
    ],
    summaryKeys: ['nextIrrigationDate', 'brixLevel'],
  ),
  'olive': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'variety',
        labelKey: 'field.crop.olive.variety',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'lastIrrigationDate',
        labelKey: 'field.crop.olive.lastIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextIrrigationDate',
          intervalDays: 14,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextIrrigationDate',
        labelKey: 'field.crop.olive.nextIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'lastPruningDate',
        labelKey: 'field.crop.olive.lastPruningDate',
        type: FieldInputType.date,
        group: 'production',
        autoNext: AutoNextConfig(
          key: 'nextPruningDate',
          intervalDays: 365,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextPruningDate',
        labelKey: 'field.crop.olive.nextPruningDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'oilExtractionMethod',
        labelKey: 'field.crop.olive.oilExtractionMethod',
        type: FieldInputType.choice,
        group: 'production',
        choices: ['cold_press', 'centrifuge', 'traditional'],
      ),
      TypeFieldDefinition(
        key: 'fruitLoadIndex',
        labelKey: 'field.crop.olive.fruitLoadIndex',
        type: FieldInputType.number,
        group: 'production',
      ),
    ],
    summaryKeys: ['nextIrrigationDate', 'nextPruningDate'],
  ),
  'rice': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'variety',
        labelKey: 'field.crop.rice.variety',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'waterDepth',
        labelKey: 'field.crop.rice.waterDepth',
        type: FieldInputType.number,
        group: 'environment',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'lastFloodDate',
        labelKey: 'field.crop.rice.lastFloodDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFloodDate',
          intervalDays: 3,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFloodDate',
        labelKey: 'field.crop.rice.nextFloodDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'lastFertilizationDate',
        labelKey: 'field.crop.rice.lastFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFertilizationDate',
          intervalDays: 15,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFertilizationDate',
        labelKey: 'field.crop.rice.nextFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: ['waterDepth', 'nextFloodDate', 'nextFertilizationDate'],
  ),
  'soybean': TypeFieldsConfig(
    fields: [
      TypeFieldDefinition(
        key: 'variety',
        labelKey: 'field.crop.soybean.variety',
        type: FieldInputType.text,
        group: 'general',
      ),
      TypeFieldDefinition(
        key: 'lastIrrigationDate',
        labelKey: 'field.crop.soybean.lastIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextIrrigationDate',
          intervalDays: 6,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextIrrigationDate',
        labelKey: 'field.crop.soybean.nextIrrigationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
      TypeFieldDefinition(
        key: 'nodulationScore',
        labelKey: 'field.crop.soybean.nodulationScore',
        type: FieldInputType.choice,
        group: 'production',
        choices: ['poor', 'moderate', 'good'],
      ),
      TypeFieldDefinition(
        key: 'lastInoculationDate',
        labelKey: 'field.crop.soybean.lastInoculationDate',
        type: FieldInputType.date,
        group: 'production',
        autoNext: AutoNextConfig(
          key: 'nextInoculationDate',
          intervalDays: 365,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextInoculationDate',
        labelKey: 'field.crop.soybean.nextInoculationDate',
        type: FieldInputType.date,
        group: 'schedule',
      ),
      TypeFieldDefinition(
        key: 'lastFertilizationDate',
        labelKey: 'field.crop.soybean.lastFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        autoNext: AutoNextConfig(
          key: 'nextFertilizationDate',
          intervalDays: 20,
        ),
      ),
      TypeFieldDefinition(
        key: 'nextFertilizationDate',
        labelKey: 'field.crop.soybean.nextFertilizationDate',
        type: FieldInputType.date,
        group: 'schedule',
        summary: true,
      ),
    ],
    summaryKeys: ['nextIrrigationDate', 'nextFertilizationDate'],
  ),
};
