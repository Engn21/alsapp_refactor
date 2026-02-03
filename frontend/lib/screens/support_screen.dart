import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';

// Simple screen showing support API base URL.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Support'))),
      body: Center(
        child: Text(
          context.tr('Support API base: {value}',
              params: {'value': ApiService.baseUrl}),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
