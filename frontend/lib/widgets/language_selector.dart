import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLang = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<Locale>(
      tooltip: context.tr('Change language'),
      icon: const Icon(Icons.translate),
      onSelected: (locale) {
        ALSApp.of(context)?.setLocale(locale);
      },
      itemBuilder: (context) => AppLocalizations.supportedLocales
          .map(
            (locale) => PopupMenuItem<Locale>(
              value: locale,
              child: Row(
                children: [
                  if (locale.languageCode == currentLang)
                    const Icon(Icons.check, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(context.tr(_languageNameKey(locale.languageCode))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  // Maps a language code to the translation key for its display name.
  String _languageNameKey(String languageCode) {
    switch (languageCode) {
      case 'tr':
        return 'Turkish';
      case 'fr':
        return 'French';
      case 'es':
        return 'Spanish';
      case 'en':
      default:
        return 'English';
    }
  }
}
