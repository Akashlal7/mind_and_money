import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported currencies
class AppCurrency {
  final String code;
  final String symbol;
  final String name;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  static const List<AppCurrency> supported = [
    AppCurrency(code: 'INR', symbol: '₹', name: 'Indian Rupee (₹)'),
    AppCurrency(code: 'USD', symbol: '\$', name: 'US Dollar (\$)'),
    AppCurrency(code: 'EUR', symbol: '€', name: 'Euro (€)'),
    AppCurrency(code: 'GBP', symbol: '£', name: 'British Pound (£)'),
  ];

  static AppCurrency get defaultCurrency => supported.first;
}

class SettingsState {
  final ThemeMode themeMode;
  final String currencyCode;
  final String currencySymbol;
  final int firstDayOfWeek; // 1 = Monday, 7 = Sunday

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.currencyCode = 'INR',
    this.currencySymbol = '₹',
    this.firstDayOfWeek = 1,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? currencyCode,
    String? currencySymbol,
    int? firstDayOfWeek,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _keyThemeMode = 'settings_theme_mode';
  static const String _keyCurrencyCode = 'settings_currency_code';
  static const String _keyFirstDay = 'settings_first_day';

  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_keyThemeMode);
      final currency = prefs.getString(_keyCurrencyCode) ?? 'INR';
      final firstDay = prefs.getInt(_keyFirstDay) ?? 1;

      ThemeMode mode = ThemeMode.system;
      if (themeIndex != null &&
          themeIndex >= 0 &&
          themeIndex < ThemeMode.values.length) {
        mode = ThemeMode.values[themeIndex];
      }

      final symbol = AppCurrency.supported
          .firstWhere(
            (c) => c.code == currency,
            orElse: () => AppCurrency.defaultCurrency,
          )
          .symbol;

      state = state.copyWith(
        themeMode: mode,
        currencyCode: currency,
        currencySymbol: symbol,
        firstDayOfWeek: firstDay,
      );
    } catch (_) {
      // Fallback gracefully
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
  }

  Future<void> setCurrency(String code) async {
    final currency = AppCurrency.supported.firstWhere(
      (c) => c.code == code,
      orElse: () => AppCurrency.defaultCurrency,
    );
    state = state.copyWith(
      currencyCode: currency.code,
      currencySymbol: currency.symbol,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrencyCode, currency.code);
  }

  Future<void> setFirstDayOfWeek(int day) async {
    state = state.copyWith(firstDayOfWeek: day);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFirstDay, day);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
