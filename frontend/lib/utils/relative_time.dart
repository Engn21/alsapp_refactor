import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

/// Formats [dt] as a short, localized relative time (e.g. "5m ago"),
/// falling back to an absolute date once it's more than a week old.
String relativeTime(BuildContext context, DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return context.tr('Just now');
  if (diff.inMinutes < 60) {
    return context.tr('{count}m ago', params: {'count': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return context.tr('{count}h ago', params: {'count': '${diff.inHours}'});
  }
  if (diff.inDays < 7) {
    return context.tr('{count}d ago', params: {'count': '${diff.inDays}'});
  }
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
