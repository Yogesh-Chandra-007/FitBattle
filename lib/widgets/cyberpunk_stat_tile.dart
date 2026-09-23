import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/theme_service.dart';

class CyberpunkStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData icon;

  const CyberpunkStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CyberpunkColors.card.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: CyberpunkColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: valueColor ?? cs.primary.withValues(alpha: 0.9)),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: valueColor ?? cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
