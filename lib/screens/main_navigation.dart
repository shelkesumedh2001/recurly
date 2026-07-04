import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/navigation_providers.dart';
import '../services/notification_service.dart';
import 'analytics_screen.dart';
import 'credit_cards_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Main navigation scaffold with bottom navigation bar
/// Inspired by modern expense tracking apps with warm, clean design
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _selectedIndex = 0;

  // Navigation screens
  static const List<Widget> _screens = [
    HomeScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Route notification taps: card reminders open the Cards screen, sub
    // reminders land on Home. Post-frame pass handles a payload that
    // arrived before this listener existed (cold start).
    NotificationService().tappedPayload.addListener(_handleNotificationTap);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _handleNotificationTap());
  }

  void _handleNotificationTap() {
    final payload = NotificationService().tappedPayload.value;
    if (payload == null || !mounted) return;
    NotificationService().tappedPayload.value = null; // consume

    if (payload.startsWith('card:')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreditCardsScreen()),
      );
    } else {
      // Subscription reminder — Home lists subs by upcoming renewal.
      _onItemTapped(0);
    }
  }

  @override
  void dispose() {
    NotificationService()
        .tappedPayload
        .removeListener(_handleNotificationTap);
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      // Let tab content react to becoming visible (entrance animations).
      ref.read(selectedTabProvider.notifier).state = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // IndexedStack keeps every tab alive: switching is instant and
      // scroll position / search state survive the round trip.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          height: 70,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          // Icon/label colors come from the theme's navigationBarTheme so
          // every preset styles the bar consistently.
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: Icon(Icons.pie_chart_rounded),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
