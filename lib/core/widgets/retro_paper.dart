import 'package:flutter/material.dart';

import 'nothing_widgets.dart';

export 'nothing_widgets.dart';

/// Backward-compatible alias for RetroPaperBackground -> NothingBackground.
class RetroPaperBackground extends StatelessWidget {
  final Widget child;

  const RetroPaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return NothingBackground(child: child);
  }
}

/// Backward-compatible alias for RetroStampBadge -> NothingBadge.
class RetroStampBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? backgroundColor;

  const RetroStampBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return NothingBadge(label: label, icon: icon, showRedDot: true);
  }
}

/// Backward-compatible alias for RetroLedgerDivider -> NothingDivider.
class RetroLedgerDivider extends StatelessWidget {
  final double verticalPadding;

  const RetroLedgerDivider({super.key, this.verticalPadding = 12.0});

  @override
  Widget build(BuildContext context) {
    return NothingDivider(verticalPadding: verticalPadding);
  }
}
