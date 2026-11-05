import 'package:flutter/material.dart';

/// Centralized responsive breakpoints and layout utilities for Mind & Money.
class AppBreakpoints {
  AppBreakpoints._();

  /// Below 300 logical pixels: Wearable / Smartwatch devices.
  static const double wearableMaxWidth = 299.0;

  /// Below 360 logical pixels: Narrow / compact devices.
  static const double compactMaxWidth = 359.0;

  /// 360 to 599 logical pixels: Standard phone viewport.
  static const double standardMaxWidth = 599.0;

  /// 600 logical pixels and above: Expanded layouts (tablets, foldables, desktop).
  static const double expandedMinWidth = 600.0;

  /// Recommended maximum content width for readability and ergonomic touch targets.
  static const double maxContentWidth = 720.0;

  /// Helper to test if width is wearable / smartwatch (< 300)
  static bool isWearable(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 300.0;
  }

  /// Helper to test if width is narrow (< 360)
  static bool isNarrow(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 360.0;
  }

  /// Helper to test if width is standard phone (360 to 599)
  static bool isStandard(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 360.0 && w < expandedMinWidth;
  }

  /// Helper to test if width is expanded / tablet (>= 600)
  static bool isExpanded(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= expandedMinWidth;
  }

  /// Adaptive horizontal content padding based on screen width
  static EdgeInsets screenPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 300.0) {
      return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0);
    } else if (w < 360.0) {
      return const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0);
    } else if (w >= expandedMinWidth) {
      return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);
    }
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  }
}

/// A wrapper widget that constraints content width on expanded/tablet displays
/// while preserving fluid responsiveness on phone screens.
class ResponsiveContentWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return Align(alignment: alignment, child: content);
  }
}
