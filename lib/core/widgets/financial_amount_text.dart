import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/money.dart';

/// Presentation types for financial amounts to control semantic color, sign, and icon.
enum FinancialAmountType { income, expense, neutral, warning }

/// Accessible, responsive financial amount display widget.
///
/// Features:
/// - Semantic accessibility label describing amount and transaction type
///   (does not rely on color alone).
/// - Graceful handling of long values without RenderFlex overflow.
/// - Dark/light mode harmonious contrast.
class FinancialAmountText extends StatelessWidget {
  final Money amount;
  final String currencySymbol;
  final FinancialAmountType type;
  final TextStyle? style;
  final bool showSign;
  final bool showIcon;
  final bool isLarge;
  final AlignmentGeometry alignment;

  const FinancialAmountText({
    super.key,
    required this.amount,
    this.currencySymbol = '₹',
    this.type = FinancialAmountType.neutral,
    this.style,
    this.showSign = false,
    this.showIcon = false,
    this.isLarge = false,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    IconData? icon;
    String semanticType;

    switch (type) {
      case FinancialAmountType.income:
        color = isDark ? AppColors.incomeGreenDark : AppColors.incomeGreen;
        icon = Icons.arrow_downward_rounded;
        semanticType = 'Income';
        break;
      case FinancialAmountType.expense:
        color = isDark ? AppColors.expenseCoralDark : AppColors.expenseCoral;
        icon = Icons.arrow_upward_rounded;
        semanticType = 'Expense';
        break;
      case FinancialAmountType.warning:
        color = isDark ? AppColors.warningAmberDark : AppColors.warningAmber;
        icon = Icons.warning_amber_rounded;
        semanticType = 'Warning';
        break;
      case FinancialAmountType.neutral:
        color = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        icon = null;
        semanticType = 'Amount';
        break;
    }

    final formattedText = amount.format(
      symbol: currencySymbol,
      includeSign: showSign,
    );

    final defaultStyle = isLarge
        ? theme.textTheme.headlineSmall?.copyWith(
            fontFamily: 'NotoSansMono',
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: color,
          )
        : theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'NotoSansMono',
            fontWeight: FontWeight.w700,
            color: color,
          );

    final effectiveStyle = (style ?? defaultStyle)?.copyWith(
      color: color,
      fontFamily: style?.fontFamily ?? 'NotoSansMono',
    );

    final mainAxisAlign = alignment == Alignment.centerRight ||
            alignment == Alignment.topRight ||
            alignment == Alignment.bottomRight
        ? MainAxisAlignment.end
        : (alignment == Alignment.center
            ? MainAxisAlignment.center
            : MainAxisAlignment.start);

    final widgetContent = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlign,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showIcon && icon != null) ...[
          Icon(icon, size: isLarge ? 18 : 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Text(
              formattedText,
              style: effectiveStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      label: '$semanticType: $formattedText',
      child: widgetContent,
    );
  }
}
