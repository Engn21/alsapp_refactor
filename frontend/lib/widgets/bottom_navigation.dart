import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/supports_list_screen.dart';
import '../screens/weather_screen.dart';
import '../screens/product_list_screen.dart';
import '../l10n/app_localizations.dart';

class BottomNavigation extends StatefulWidget {
  final int currentIndex;
  final String userId;
  final int notifications;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.userId,
    this.notifications = 0,
  });

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  late int _selectedIndex = widget.currentIndex;

  // Collapses the stack back down to the root (Dashboard) before pushing
  // the target tab screen, so the system back button always returns to
  // Dashboard instead of exiting the app (each tab used to replace the
  // previous one via pushReplacement, leaving only one route on the stack).
  void _goTo(Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => route.isFirst,
    );
  }

  void _go(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        _goTo(ProductListScreen(userId: widget.userId));
        break;
      case 1:
        _goTo(SupportsListScreen(userId: widget.userId));
        break;
      case 2:
        _goTo(WeatherScreen(userId: widget.userId));
        break;
      default:
        _goTo(DashboardScreen(userId: widget.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _go,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.list_alt),
          label: context.tr('Tracking'),
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.support_agent),
              if (widget.notifications > 0)
                Positioned(
                  right: -6, top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red, borderRadius: BorderRadius.circular(12)),
                    child: Text('${widget.notifications}',
                        style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
            ],
          ),
          label: context.tr('Supports'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.cloud),
          label: context.tr('Weather'),
        ),
      ],
    );
  }
}
