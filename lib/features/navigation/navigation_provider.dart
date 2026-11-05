import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigation tabs in the bottom bar
enum AppTab {
  home('Home'),
  money('Money'),
  mind('Mind'),
  habits('Habits'),
  settings('Settings');

  final String label;

  const AppTab(this.label);

  static AppTab fromIndex(int idx) {
    if (idx >= 0 && idx < AppTab.values.length) {
      return AppTab.values[idx];
    }
    return AppTab.home;
  }
}

/// Active tab index notifier
class ActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

/// Active tab index provider
final activeTabProvider = NotifierProvider<ActiveTabNotifier, int>(
  ActiveTabNotifier.new,
);
