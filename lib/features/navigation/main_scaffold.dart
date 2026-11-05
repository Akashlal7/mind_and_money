import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/responsive_layout.dart';
import '../../core/widgets/retro_paper.dart';
import '../finance/presentation/money_screen.dart';
import '../habits/presentation/habits_screen.dart';
import '../home/presentation/home_screen.dart';
import '../settings/presentation/settings_screen.dart';
import '../wellness/presentation/mind_screen.dart';
import 'navigation_provider.dart';

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    MoneyScreen(),
    MindScreen(),
    HabitsScreen(),
    SettingsScreen(),
  ];

  static const List<({IconData icon, IconData selectedIcon, String label})>
  _destinations = [
    (
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: 'Money',
    ),
    (icon: Icons.spa_outlined, selectedIcon: Icons.spa_rounded, label: 'Mind'),
    (
      icon: Icons.check_circle_outlined,
      selectedIcon: Icons.check_circle_rounded,
      label: 'Habits',
    ),
    (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = ref.watch(activeTabProvider);
    final isExpanded = AppBreakpoints.isExpanded(context);
    final isWearable = AppBreakpoints.isWearable(context);
    final theme = Theme.of(context);

    if (isExpanded) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: activeIndex,
              onDestinationSelected: (index) {
                ref.read(activeTabProvider.notifier).setTab(index);
              },
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.eco_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
              ),
              destinations: _destinations.map((d) {
                return NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: RetroPaperBackground(
                child: IndexedStack(index: activeIndex, children: _screens),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: RetroPaperBackground(
        child: IndexedStack(index: activeIndex, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        height: isWearable ? 52 : null,
        labelBehavior: isWearable
            ? NavigationDestinationLabelBehavior.alwaysHide
            : NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: activeIndex,
        onDestinationSelected: (index) {
          ref.read(activeTabProvider.notifier).setTab(index);
        },
        destinations: _destinations.map((d) {
          return NavigationDestination(
            icon: Icon(d.icon, size: isWearable ? 20 : 24),
            selectedIcon: Icon(d.selectedIcon, size: isWearable ? 20 : 24),
            label: d.label,
          );
        }).toList(),
      ),
    );
  }
}
