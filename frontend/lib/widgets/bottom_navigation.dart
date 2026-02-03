import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/supports_list_screen.dart';
import '../screens/weather_screen.dart';
import '../screens/product_list_screen.dart';
import '../l10n/app_localizations.dart';

class BottomNavigation extends StatefulWidget {
  final int currentIndex;
  final String userId;
  final String password;
  final int notifications;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.userId,
    required this.password,
    this.notifications = 0,
  });

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  late int _selectedIndex = widget.currentIndex;

  void _go(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProductListScreen(
              userId: widget.userId, password: widget.password),
          ),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SupportsListScreen(
              userId: widget.userId, password: widget.password),
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                WeatherScreen(userId: widget.userId, password: widget.password),
          ),
        );
        break;
      default:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              userId: widget.userId, password: widget.password),
          ),
        );
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
