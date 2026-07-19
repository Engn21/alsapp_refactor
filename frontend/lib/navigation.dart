import 'package:flutter/material.dart';

/// Root navigator key so non-widget code (e.g. ApiService) can redirect
/// to the login screen when a session becomes invalid (401 / expired JWT).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
