import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'country_scope.dart';

// Country picker for Support Programs / Nearby Offices - independent of
// the language selector, since which country's support programs a user
// wants to browse is a separate choice from what language they read in.
class CountrySelector extends StatelessWidget {
  const CountrySelector({super.key});

  static const _countries = ['TR', 'CH', 'FR', 'ES'];

  static String flagFor(String code) {
    switch (code) {
      case 'TR':
        return '🇹🇷';
      case 'CH':
        return '🇨🇭';
      case 'FR':
        return '🇫🇷';
      case 'ES':
        return '🇪🇸';
      default:
        return '';
    }
  }

  static String _nameKeyFor(String code) => 'country.$code';

  @override
  Widget build(BuildContext context) {
    final scope = CountryScope.of(context);
    final current = scope.country;
    return PopupMenuButton<String>(
      tooltip: context.tr('Change country'),
      icon: Text(flagFor(current), style: const TextStyle(fontSize: 20)),
      onSelected: scope.onChanged,
      itemBuilder: (context) => _countries
          .map(
            (code) => PopupMenuItem<String>(
              value: code,
              child: Row(
                children: [
                  if (code == current)
                    const Icon(Icons.check, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(flagFor(code)),
                  const SizedBox(width: 8),
                  Text(context.tr(_nameKeyFor(code))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
