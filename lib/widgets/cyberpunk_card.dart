import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class CyberpunkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool glow;
  final BorderRadiusGeometry borderRadius;
  final Color? color;

  const CyberpunkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.glow = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: (color ?? CyberpunkColors.card).withValues(alpha: 0.96),
        borderRadius: borderRadius,
        border: Border.all(
          color: CyberpunkColors.border.withValues(alpha: 0.95),
          width: 1,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: child,
    );
  }
}
