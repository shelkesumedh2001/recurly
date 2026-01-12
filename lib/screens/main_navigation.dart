import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Main navigation scaffold with bottom navigation bar
/// Inspired by modern expense tracking apps with warm, clean design
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Navigation screens
  static const List<Widget> _screens = [
    HomeScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      _animationController.reset();
      setState(() {
        _selectedIndex = index;
      });
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _screens[_selectedIndex],
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
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          elevation: 0,
          height: 70,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.home_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: theme.colorScheme.primary,
              ),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.pie_chart_outline_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              selectedIcon: Icon(
                Icons.pie_chart_rounded,
                color: theme.colorScheme.primary,
              ),
              label: 'Analytics',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.settings_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              selectedIcon: Icon(
                Icons.settings_rounded,
                color: theme.colorScheme.primary,
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
