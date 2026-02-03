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
                  Text(locale.languageCode == 'en'
                      ? context.tr('English')
                      : locale.languageCode == 'tr'
                          ? context.tr('Turkish')
                          : context.tr('French')),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
