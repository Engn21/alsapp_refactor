import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

// The crop / livestock types are stored as English values ('wheat', 'cow',
// ...). This maps each to its translation key, so the name shows in the
// farmer's language everywhere instead of the raw value or a hard-coded
// Turkish label.
const _typeKeys = <String, String>{
  // crops
  'wheat': 'Wheat',
  'sugar beet': 'Sugar beet',
  'corn': 'Corn',
  'cotton': 'Cotton',
  'sunflower': 'Sunflower',
  'tomato': 'Tomato',
  'grape': 'Grape',
  'olive': 'Olive',
  'rice': 'Rice',
  'soybean': 'Soybean',
  // livestock
  'cow': 'Cow',
  'sheep': 'Sheep',
  'goat': 'Goat',
  'chicken': 'Chicken',
  'duck': 'Duck',
  'turkey': 'Turkey',
  'bee': 'Bee',
  'fish': 'Fish',
  'buffalo': 'Buffalo',
  'camel': 'Camel',
};

/// Translated name for a crop/livestock type value. Anything that isn't one
/// of the known types (a name the farmer typed, an id, ...) is returned as is.
String typeLabel(BuildContext context, String value) {
  final key = _typeKeys[value.trim().toLowerCase()];
  return key == null ? value : context.tr(key);
}
