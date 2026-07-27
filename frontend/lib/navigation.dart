import 'package:flutter/material.dart';
import 'screens/product_detail_screen.dart';

/// Root navigator key so non-widget code (e.g. ApiService) can redirect
/// to the login screen when a session becomes invalid (401 / expired JWT),
/// and so a push-notification tap can navigate without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Opens the crop/livestock detail screen a notification points at, if
/// any. Shared by the in-app notifications list (NotificationsScreen)
/// and push-notification taps (PushService) so both paths deep-link
/// identically instead of duplicating this logic.
Future<void> openRelatedRecord({String? cropId, String? livestockId}) async {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  if (cropId != null) {
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: {'id': cropId, 'type': 'crop'}),
      ),
    );
  } else if (livestockId != null) {
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: {'id': livestockId, 'type': 'livestock'}),
      ),
    );
  }
}
