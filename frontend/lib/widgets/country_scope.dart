import 'package:flutter/material.dart';

// Propagates the selected country ('TR', 'CH', 'FR', 'ES') down the widget
// tree, the same way Flutter's own Localizations propagates the current
// Locale - screens read it with CountryScope.of(context).country and get
// rebuilt automatically (via didChangeDependencies) when it changes,
// without needing a plain ancestor-state lookup that a deep Navigator
// route wouldn't otherwise notice.
class CountryScope extends InheritedWidget {
  const CountryScope({
    super.key,
    required this.country,
    required this.onChanged,
    required super.child,
  });

  final String country;
  final ValueChanged<String> onChanged;

  static CountryScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CountryScope>();
    assert(scope != null, 'CountryScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(CountryScope oldWidget) =>
      country != oldWidget.country;
}
