import 'package:flutter/material.dart';

/// Mind & Money — Nothing Phone / Nothing OS-Inspired Monochrome & Red Design Palette.
///
/// Features minimalist monochrome shades, stark geometric surfaces,
/// restrained Nothing Red focal points (#D71920 / #FF333A), and accessible semantic status tokens.
class AppColors {
  AppColors._();

  // Nothing Light Theme Palette
  /// Main background: #F5F5F5
  static const Color mainBackgroundLight = Color(0xFFF5F5F5);

  /// Primary surface: #FFFFFF
  static const Color primarySurfaceLight = Color(0xFFFFFFFF);

  /// Secondary surface & subtle fills: #EBEBEB
  static const Color secondarySurfaceLight = Color(0xFFEBEBEB);

  /// Primary high-contrast text: #111111
  static const Color primaryTextLight = Color(0xFF111111);

  /// Secondary muted text: #666666
  static const Color secondaryTextLight = Color(0xFF666666);

  /// Tertiary subtle metadata text: #999999
  static const Color tertiaryTextLight = Color(0xFF999999);

  /// Borders and geometric dividers: #D4D4D4
  static const Color borderDividerLight = Color(0xFFD4D4D4);

  /// Primary Nothing Red accent: #D71920
  static const Color nothingRed = Color(0xFFD71920);

  // Nothing Dark Theme Palette
  /// Main background: #101010
  static const Color mainBackgroundDark = Color(0xFF101010);

  /// Primary surface: #1A1A1A
  static const Color primarySurfaceDark = Color(0xFF1A1A1A);

  /// Secondary surface & subtle fills: #242424
  static const Color secondarySurfaceDark = Color(0xFF242424);

  /// Primary high-contrast text: #F5F5F5
  static const Color primaryTextDark = Color(0xFFF5F5F5);

  /// Secondary muted text: #B0B0B0
  static const Color secondaryTextDark = Color(0xFFB0B0B0);

  /// Tertiary subtle metadata text: #707070
  static const Color tertiaryTextDark = Color(0xFF707070);

  /// Borders and geometric dividers: #383838
  static const Color borderDividerDark = Color(0xFF383838);

  /// Primary Nothing Red accent (Dark Mode): #FF333A
  static const Color nothingRedDark = Color(0xFFFF333A);

  // Semantic Status Colors
  /// Positive financial status (Income): #287A50 (Light) / #3EA870 (Dark)
  static const Color positiveGreen = Color(0xFF287A50);
  static const Color positiveGreenDark = Color(0xFF3EA870);
  static const Color positiveContainerLight = Color(0xFFE8F5EE);
  static const Color positiveContainerDark = Color(0xFF142E20);

  /// Negative financial status (Expense): #C62828 (Light) / #EF4444 (Dark)
  static const Color negativeRed = Color(0xFFC62828);
  static const Color negativeRedDark = Color(0xFFEF4444);
  static const Color negativeContainerLight = Color(0xFFFFEBEE);
  static const Color negativeContainerDark = Color(0xFF3B1818);

  /// Warning / Alert: #D97706 (Light) / #F59E0B (Dark)
  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningAmberDark = Color(0xFFF59E0B);
  static const Color warningContainerLight = Color(0xFFFEF3C7);
  static const Color warningContainerDark = Color(0xFF3D2708);

  /// Informational: #2563EB (Light) / #60A5FA (Dark)
  static const Color infoBlue = Color(0xFF2563EB);
  static const Color infoBlueDark = Color(0xFF60A5FA);
  static const Color infoContainerLight = Color(0xFFEFF6FF);
  static const Color infoContainerDark = Color(0xFF132A4D);

  // Theme Aliases & Backward Compatibility
  static const Color backgroundLight = mainBackgroundLight;
  static const Color surfaceLight = primarySurfaceLight;
  static const Color surfaceVariantLight = secondarySurfaceLight;
  static const Color borderLight = borderDividerLight;
  static const Color textPrimaryLight = primaryTextLight;
  static const Color textSecondaryLight = secondaryTextLight;
  static const Color textTertiaryLight = tertiaryTextLight;

  static const Color backgroundDark = mainBackgroundDark;
  static const Color surfaceDark = primarySurfaceDark;
  static const Color surfaceVariantDark = secondarySurfaceDark;
  static const Color borderDark = borderDividerDark;
  static const Color textPrimaryDark = primaryTextDark;
  static const Color textSecondaryDark = secondaryTextDark;
  static const Color textTertiaryDark = tertiaryTextDark;

  // Status mapping aliases
  static const Color incomeGreen = positiveGreen;
  static const Color incomeGreenDark = positiveGreenDark;
  static const Color incomeContainerLight = positiveContainerLight;
  static const Color incomeContainerDark = positiveContainerDark;
  static const Color onIncomeContainerLight = positiveGreen;
  static const Color onIncomeContainerDark = positiveGreenDark;

  static const Color expenseCoral = negativeRed;
  static const Color expenseCoralDark = negativeRedDark;
  static const Color expenseContainerLight = negativeContainerLight;
  static const Color expenseContainerDark = negativeContainerDark;
  static const Color onExpenseContainerLight = negativeRed;
  static const Color onExpenseContainerDark = negativeRedDark;

  static const Color onWarningContainerLight = warningAmber;
  static const Color onWarningContainerDark = warningAmberDark;
  static const Color onInfoContainerLight = infoBlue;
  static const Color onInfoContainerDark = infoBlueDark;

  // Module compatibility aliases
  static const Color sagePrimary = primaryTextLight;
  static const Color sagePrimaryDark = primaryTextDark;
  static const Color sageContainer = secondarySurfaceLight;
  static const Color sageDark = borderDividerLight;
  static const Color onSageContainer = primaryTextLight;
  static const Color tealSecondary = nothingRed;
  static const Color tealSecondaryDark = nothingRedDark;
  static const Color tealContainer = secondarySurfaceLight;
  static const Color onTealContainer = nothingRed;
}
