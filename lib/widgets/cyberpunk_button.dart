import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/theme_service.dart';

enum CyberButtonVariant {
  primary,
  secondary,
  battle,
}

class CyberpunkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CyberButtonVariant variant;
  final bool isBusy;
  final Widget? leading;
  final double height;

  const CyberpunkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CyberButtonVariant.primary,
    this.isBusy = false,
    this.leading,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color bg;
    final Color fg;
    final Color? border;

    switch (variant) {
      case CyberButtonVariant.secondary:
        bg = CyberpunkColors.card;
        fg = CyberpunkColors.textPrimary;
        border = CyberpunkColors.primary.withValues(alpha: 0.35);
        break;
      case CyberButtonVariant.battle:
        bg = CyberpunkColors.competitive;
        fg = Colors.black;
        border = null;
        break;
      case CyberButtonVariant.primary:
        bg = scheme.primary;
        fg = Colors.black;
        border = null;
        break;
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isBusy ? null : onPressed,
        icon: isBusy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: fg,
                ),
              )
            : (leading ?? const SizedBox.shrink()),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: fg,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: variant == CyberButtonVariant.secondary ? 0 : 8,
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: border == null
                ? BorderSide.none
                : BorderSide(color: border, width: 1.5),
          ),
          shadowColor: bg.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
      ),
    );
  }
}
