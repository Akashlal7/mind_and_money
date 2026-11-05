import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Mind & Money — Nothing Phone / Nothing OS Inspired Components.
/// Provides authentic 5x7 Dot-Matrix rendering, geometric wireframe surfaces,
/// and Nothing Red status indicators.

/// High-performance, 100% offline 5x7 Dot-Matrix text generator.
/// Renders authentic LED/LCD circular matrix dots for uppercase alphanumeric glyphs and symbols.
class DotMatrixText extends StatelessWidget {
  final String text;
  final double dotSize;
  final double dotSpacing;
  final Color? color;
  final Color? inactiveColor;

  const DotMatrixText(
    this.text, {
    super.key,
    this.dotSize = 2.0,
    this.dotSpacing = 1.0,
    this.color,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor =
        color ??
        (isDark ? AppColors.primaryTextDark : AppColors.primaryTextLight);
    final unlitColor =
        inactiveColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04));

    return CustomPaint(
      size: Size(
        _calculateWidth(text, dotSize, dotSpacing),
        7 * dotSize + 6 * dotSpacing,
      ),
      painter: _DotMatrixPainter(
        text: text.toUpperCase(),
        dotSize: dotSize,
        dotSpacing: dotSpacing,
        activeColor: activeColor,
        inactiveColor: unlitColor,
      ),
    );
  }

  static double _calculateWidth(String str, double size, double spacing) {
    if (str.isEmpty) return 0;
    final charWidth = 5 * size + 4 * spacing;
    final interCharSpacing = size * 1.5;
    return str.length * charWidth + (str.length - 1) * interCharSpacing;
  }
}

class _DotMatrixPainter extends CustomPainter {
  final String text;
  final double dotSize;
  final double dotSpacing;
  final Color activeColor;
  final Color inactiveColor;

  _DotMatrixPainter({
    required this.text,
    required this.dotSize,
    required this.dotSpacing,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    double xOffset = 0;
    final charWidth = 5 * dotSize + 4 * dotSpacing;
    final interCharSpacing = dotSize * 1.5;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final matrix = _glyphPatterns[char] ?? _glyphPatterns[' ']!;

      for (int row = 0; row < 7; row++) {
        for (int col = 0; col < 5; col++) {
          final isLit = ((matrix[row] >> (4 - col)) & 1) == 1;
          final cx = xOffset + col * (dotSize + dotSpacing) + dotSize / 2;
          final cy = row * (dotSize + dotSpacing) + dotSize / 2;

          canvas.drawCircle(
            Offset(cx, cy),
            dotSize / 2,
            isLit ? activePaint : inactivePaint,
          );
        }
      }
      xOffset += charWidth + interCharSpacing;
    }
  }

  @override
  bool shouldRepaint(_DotMatrixPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.dotSize != dotSize;
  }

  // 5x7 bit patterns for standard uppercase ASCII & symbols
  static const Map<String, List<int>> _glyphPatterns = {
    ' ': [0, 0, 0, 0, 0, 0, 0],
    'A': [14, 17, 17, 31, 17, 17, 17],
    'B': [30, 17, 17, 30, 17, 17, 30],
    'C': [14, 17, 16, 16, 16, 17, 14],
    'D': [28, 18, 17, 17, 17, 18, 28],
    'E': [31, 16, 16, 30, 16, 16, 31],
    'F': [31, 16, 16, 30, 16, 16, 16],
    'G': [14, 17, 16, 23, 17, 17, 14],
    'H': [17, 17, 17, 31, 17, 17, 17],
    'I': [14, 4, 4, 4, 4, 4, 14],
    'J': [7, 2, 2, 2, 2, 18, 12],
    'K': [17, 18, 20, 24, 20, 18, 17],
    'L': [16, 16, 16, 16, 16, 16, 31],
    'M': [17, 27, 21, 21, 17, 17, 17],
    'N': [17, 19, 21, 25, 17, 17, 17],
    'O': [14, 17, 17, 17, 17, 17, 14],
    'P': [30, 17, 17, 30, 16, 16, 16],
    'Q': [14, 17, 17, 17, 21, 18, 13],
    'R': [30, 17, 17, 30, 20, 18, 17],
    'S': [14, 17, 16, 14, 1, 17, 14],
    'T': [31, 4, 4, 4, 4, 4, 4],
    'U': [17, 17, 17, 17, 17, 17, 14],
    'V': [17, 17, 17, 17, 17, 10, 4],
    'W': [17, 17, 17, 21, 21, 21, 10],
    'X': [17, 17, 10, 4, 10, 17, 17],
    'Y': [17, 17, 10, 4, 4, 4, 4],
    'Z': [31, 1, 2, 4, 8, 16, 31],
    '0': [14, 19, 21, 21, 25, 17, 14],
    '1': [4, 12, 4, 4, 4, 4, 14],
    '2': [14, 17, 1, 6, 8, 16, 31],
    '3': [31, 1, 2, 6, 1, 17, 14],
    '4': [2, 6, 10, 18, 31, 2, 2],
    '5': [31, 16, 30, 1, 1, 17, 14],
    '6': [14, 17, 16, 30, 17, 17, 14],
    '7': [31, 1, 2, 4, 8, 8, 8],
    '8': [14, 17, 17, 14, 17, 17, 14],
    '9': [14, 17, 17, 15, 1, 17, 14],
    '-': [0, 0, 0, 31, 0, 0, 0],
    '+': [0, 4, 4, 31, 4, 4, 0],
    '.': [0, 0, 0, 0, 0, 12, 12],
    ':': [0, 12, 12, 0, 12, 12, 0],
    '/': [1, 2, 2, 4, 8, 8, 16],
    '[': [14, 8, 8, 8, 8, 8, 14],
    ']': [14, 2, 2, 2, 2, 2, 14],
    '(': [6, 8, 8, 8, 8, 8, 6],
    ')': [12, 2, 2, 2, 2, 2, 12],
    '●': [0, 14, 31, 31, 31, 14, 0],
  };
}

/// Nothing OS-style geometric pill badge with optional Nothing Red status indicator dot.
class NothingBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool showRedDot;
  final VoidCallback? onTap;

  const NothingBadge({
    super.key,
    required this.label,
    this.icon,
    this.showRedDot = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppColors.borderDividerDark
        : AppColors.borderDividerLight;
    final textColor = isDark
        ? AppColors.primaryTextDark
        : AppColors.primaryTextLight;
    final bgColor = isDark
        ? AppColors.secondarySurfaceDark
        : AppColors.secondarySurfaceLight;

    return Semantics(
      button: onTap != null,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showRedDot) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.nothingRedDark
                        : AppColors.nothingRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (icon != null) ...[
                Icon(icon, size: 12, color: textColor),
                const SizedBox(width: 4),
              ],
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'NotoSansMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nothing OS geometric canvas with ultra-faint dot grid.
class NothingBackground extends StatelessWidget {
  final Widget child;

  const NothingBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: isDark
                ? AppColors.mainBackgroundDark
                : AppColors.mainBackgroundLight,
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _GeometricDotGridPainter(isDark: isDark),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GeometricDotGridPainter extends CustomPainter {
  final bool isDark;

  _GeometricDotGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(
        alpha: isDark ? 0.03 : 0.03,
      )
      ..style = PaintingStyle.fill;

    const double spacing = 28.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GeometricDotGridPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Thin Nothing OS geometric line divider.
class NothingDivider extends StatelessWidget {
  final double verticalPadding;

  const NothingDivider({super.key, this.verticalPadding = 12.0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? AppColors.borderDividerDark
        : AppColors.borderDividerLight;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Container(height: 1.0, color: color),
    );
  }
}
