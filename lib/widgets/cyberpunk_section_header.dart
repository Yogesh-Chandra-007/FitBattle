import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class CyberpunkSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color? color;

  const CyberpunkSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: (color ?? cs.onSurface.withValues(alpha: 0.45)),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}
