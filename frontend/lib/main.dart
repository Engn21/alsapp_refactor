import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'l10n/app_localizations.dart';

void main() => runApp(const ALSApp());

class ALSApp extends StatefulWidget {
  const ALSApp({super.key});

  static _ALSAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_ALSAppState>();

  @override
  State<ALSApp> createState() => _ALSAppState();
}

class _ALSAppState extends State<ALSApp> {
  Locale? _locale;

  void setLocale(Locale locale) {
    if (!mounted) return;
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALSApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return supported.first;
        for (final candidate in supported) {
          if (candidate.languageCode == locale.languageCode) {
            return candidate;
          }
        }
        return supported.first;
      },
      home: const LoginScreen(),
    );
  }
}
