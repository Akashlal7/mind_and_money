import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Complete, centralized Nothing Phone / Nothing OS Material 3 Theme for Mind & Money.
/// Features stark monochrome surfaces, geometric 1px borders, Nothing Red accents (#D71920 / #FF333A),
/// and tabular monospace numerals.
class AppTheme {
  AppTheme._();

  static const String monoFontFamily = 'NotoSansMono';

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryTextLight,
      onPrimary: Colors.white,
      primaryContainer: AppColors.secondarySurfaceLight,
      onPrimaryContainer: AppColors.primaryTextLight,
      secondary: AppColors.nothingRed,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondarySurfaceLight,
      onSecondaryContainer: AppColors.primaryTextLight,
      tertiary: AppColors.secondaryTextLight,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.secondarySurfaceLight,
      onTertiaryContainer: AppColors.primaryTextLight,
      error: AppColors.negativeRed,
      onError: Colors.white,
      errorContainer: AppColors.negativeContainerLight,
      onErrorContainer: AppColors.negativeRed,
      surface: AppColors.primarySurfaceLight,
      onSurface: AppColors.primaryTextLight,
      onSurfaceVariant: AppColors.secondaryTextLight,
      outline: AppColors.borderDividerLight,
      outlineVariant: AppColors.secondarySurfaceLight,
      surfaceContainerHighest: AppColors.secondarySurfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.mainBackgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.mainBackgroundLight,
        foregroundColor: AppColors.primaryTextLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.primaryTextLight,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.primaryTextLight,
          letterSpacing: -0.8,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryTextLight,
          letterSpacing: -0.6,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryTextLight,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryTextLight,
          letterSpacing: -0.4,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextLight,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextLight,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextLight,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryTextLight,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextLight,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: AppColors.primaryTextLight,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.primaryTextLight,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AppColors.secondaryTextLight,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextLight,
          letterSpacing: 0.3,
        ),
        labelMedium: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryTextLight,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryTextLight,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.primarySurfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(
            color: AppColors.borderDividerLight,
            width: 1.0,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.primarySurfaceLight,
        elevation: 2,
        indicatorColor: AppColors.secondarySurfaceLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryTextLight,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryTextLight,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.primaryTextLight,
              size: 24,
            );
          }
          return const IconThemeData(
            color: AppColors.secondaryTextLight,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.primarySurfaceLight,
        elevation: 2,
        indicatorColor: AppColors.secondarySurfaceLight,
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextLight,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryTextLight,
        ),
        selectedIconTheme: const IconThemeData(
          color: AppColors.primaryTextLight,
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.secondaryTextLight,
          size: 24,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryTextLight,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryTextLight,
          side: const BorderSide(
            color: AppColors.borderDividerLight,
            width: 1.0,
          ),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.nothingRed,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryTextLight,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondarySurfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.borderDividerLight,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.borderDividerLight,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryTextLight,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.negativeRed,
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.negativeRed,
            width: 1.5,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.primarySurfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.borderDividerLight,
            width: 1.0,
          ),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.primaryTextLight,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.secondaryTextLight,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.primarySurfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: AppColors.borderDividerLight, width: 1.0),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondarySurfaceLight,
        side: const BorderSide(color: AppColors.borderDividerLight, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryTextLight,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primaryTextLight,
        unselectedLabelColor: AppColors.secondaryTextLight,
        indicatorColor: AppColors.primaryTextLight,
        labelStyle: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        dividerColor: AppColors.borderDividerLight,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDividerLight,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryTextLight,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryTextDark,
      onPrimary: Colors.black,
      primaryContainer: AppColors.secondarySurfaceDark,
      onPrimaryContainer: AppColors.primaryTextDark,
      secondary: AppColors.nothingRedDark,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondarySurfaceDark,
      onSecondaryContainer: AppColors.primaryTextDark,
      tertiary: AppColors.secondaryTextDark,
      onTertiary: Colors.black,
      tertiaryContainer: AppColors.secondarySurfaceDark,
      onTertiaryContainer: AppColors.primaryTextDark,
      error: AppColors.negativeRedDark,
      onError: Colors.black,
      errorContainer: AppColors.negativeContainerDark,
      onErrorContainer: AppColors.negativeRedDark,
      surface: AppColors.primarySurfaceDark,
      onSurface: AppColors.primaryTextDark,
      onSurfaceVariant: AppColors.secondaryTextDark,
      outline: AppColors.borderDividerDark,
      outlineVariant: AppColors.secondarySurfaceDark,
      surfaceContainerHighest: AppColors.secondarySurfaceDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.mainBackgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.mainBackgroundDark,
        foregroundColor: AppColors.primaryTextDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.primaryTextDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.primaryTextDark,
          letterSpacing: -0.8,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryTextDark,
          letterSpacing: -0.6,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryTextDark,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryTextDark,
          letterSpacing: -0.4,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextDark,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextDark,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextDark,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryTextDark,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          color: AppColors.primaryTextDark,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AppColors.primaryTextDark,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AppColors.secondaryTextDark,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextDark,
          letterSpacing: 0.3,
        ),
        labelMedium: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryTextDark,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryTextDark,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.primarySurfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(
            color: AppColors.borderDividerDark,
            width: 1.0,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.primarySurfaceDark,
        elevation: 2,
        indicatorColor: AppColors.secondarySurfaceDark,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryTextDark,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryTextDark,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.primaryTextDark,
              size: 24,
            );
          }
          return const IconThemeData(
            color: AppColors.secondaryTextDark,
            size: 24,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.primarySurfaceDark,
        elevation: 2,
        indicatorColor: AppColors.secondarySurfaceDark,
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryTextDark,
        ),
        unselectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryTextDark,
        ),
        selectedIconTheme: const IconThemeData(
          color: AppColors.primaryTextDark,
          size: 24,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.secondaryTextDark,
          size: 24,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryTextDark,
          foregroundColor: Colors.black,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryTextDark,
          side: const BorderSide(
            color: AppColors.borderDividerDark,
            width: 1.0,
          ),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.nothingRedDark,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryTextDark,
        foregroundColor: Colors.black,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondarySurfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.borderDividerDark,
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.borderDividerDark,
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryTextDark,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.negativeRedDark,
            width: 1.0,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.negativeRedDark,
            width: 1.5,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.primarySurfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.borderDividerDark,
            width: 1.0,
          ),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.primaryTextDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.secondaryTextDark,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.primarySurfaceDark,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: AppColors.borderDividerDark, width: 1.0),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondarySurfaceDark,
        side: const BorderSide(color: AppColors.borderDividerDark, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryTextDark,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primaryTextDark,
        unselectedLabelColor: AppColors.secondaryTextDark,
        indicatorColor: AppColors.primaryTextDark,
        labelStyle: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: monoFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        dividerColor: AppColors.borderDividerDark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDividerDark,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primarySurfaceDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: AppColors.borderDividerDark,
            width: 1.0,
          ),
        ),
      ),
    );
  }
}
