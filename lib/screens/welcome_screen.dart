import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/theme_service.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF050508),
                    Color(0xFF0B1024),
                    Color(0xFF050508),
                  ],
                ),
              ),
            ),
          ),
          // Subtle cyber grid + glow shapes
          const Positioned.fill(child: _CyberBackdrop()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top bar
                  Row(
                    children: [
                      _Brand(cs: cs),
                      const Spacer(),
                      _ModeBadge(colors: cs),
                    ],
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2),

                  const SizedBox(height: 28),

                  // Headline
                  Text(
                    'FITNESS\nHITS DIFFERENT\nTOGETHER.',
                    style: GoogleFonts.rajdhani(
                      fontSize: 44,
                      height: 0.96,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 150.ms)
                      .slideY(begin: 0.15),

                  const SizedBox(height: 12),

                  Text(
                    '1v1 workouts. Real competition.\nReal progress.',
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      color: cs.onSurface.withValues(alpha: 0.65),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                  const Spacer(),

                  // Hero illustration (abstract, no photography)
                  const SizedBox(
                    height: 230,
                    width: double.infinity,
                    child: _AthleteIllustration(),
                  ),

                  const SizedBox(height: 18),

                  // CTA
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: onGetStarted,
                      icon: const Icon(Icons.arrow_forward, color: Colors.black),
                      label: Text(
                        'Get Started',
                        style: GoogleFonts.rajdhani(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CyberpunkColors.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: CyberpunkColors.primary.withValues(alpha: 0.7)),
                        ),
                        elevation: 10,
                        shadowColor: CyberpunkColors.primary.withValues(alpha: 0.35),
                      ),
                    ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                  ),

                  const SizedBox(height: 14),

                  Center(
                    child: TextButton(
                      onPressed: onSignIn,
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.rajdhani(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Center(
                    child: Text(
                      'BETTER YOU.\nHIGHER YOU.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface.withValues(alpha: 0.35),
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final ColorScheme cs;
  const _Brand({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '⚡',
          style: GoogleFonts.rajdhani(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'FitBattle',
          style: GoogleFonts.rajdhani(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final ColorScheme colors;
  const _ModeBadge({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _badgeLine('SWEAT', Icons.local_fire_department, colors.primary.withValues(alpha: 0.8)),
        const SizedBox(height: 8),
        _badgeLine('COMPETE', Icons.sports_mma, const Color(0xFFFF2D55)),
        const SizedBox(height: 8),
        _badgeLine('GROW', Icons.trending_up, colors.secondary.withValues(alpha: 0.9)),
      ],
    );
  }

  Widget _badgeLine(String label, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.55),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _AthleteIllustration extends StatelessWidget {
  const _AthleteIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _NeonAthletesPainter(),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  const Color(0xFF00E5FF).withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NeonAthletesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const lime = CyberpunkColors.primary;
    const magenta = CyberpunkColors.competitive;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = lime
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final stroke2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = magenta
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    void fighter({required double x, required double scale, required Paint p}) {
      final head = Offset(x, size.height * 0.28) * scale;
      final bodyTop = Offset(x, size.height * 0.38) * scale;
      final bodyBottom = Offset(x, size.height * 0.66) * scale;

      // Head
      canvas.drawCircle(head, 18 * scale, p..style = PaintingStyle.stroke);
      // Torso
      canvas.drawLine(bodyTop, bodyBottom, p);
      // Arms (simple)
      canvas.drawLine(Offset(x - 40 * scale, size.height * 0.46) * scale,
          Offset(x - 20 * scale, size.height * 0.56) * scale, p);
      canvas.drawLine(Offset(x + 30 * scale, size.height * 0.46) * scale,
          Offset(x + 10 * scale, size.height * 0.58) * scale, p);
      // Legs
      canvas.drawLine(bodyBottom, Offset(x - 28 * scale, size.height * 0.78) * scale, p);
      canvas.drawLine(bodyBottom, Offset(x + 28 * scale, size.height * 0.78) * scale, p);

      // Ground line glow
      final baseY = size.height * 0.78;
      final ground = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = p.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawLine(
        Offset(x - 60 * scale, baseY) * scale,
        Offset(x + 60 * scale, baseY) * scale,
        ground,
      );
    }

    // Left neon fighter
    fighter(x: size.width * 0.25, scale: 1, p: stroke);
    // Right neon fighter
    fighter(x: size.width * 0.75, scale: 1, p: stroke2);

    // Neon rails
    final rails = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (var i = 0; i < 6; i++) {
      final t = i / 5;
      canvas.drawLine(
        Offset(size.width * t, size.height * 0.65),
        Offset(size.width * (t + 0.18), size.height * 0.98),
        rails,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CyberBackdrop extends StatelessWidget {
  const _CyberBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Grid
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(),
          ),
        ),
        // Corner glows
        const Positioned(
          left: -60,
          top: 120,
          child: _GlowBlob(color: Color(0xFFB6FF2B), size: 180),
        ),
        const Positioned(
          right: -80,
          top: 40,
          child: _GlowBlob(color: Color(0xFFFF2D55), size: 220),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
        ),
        child: SizedBox(width: size, height: size),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.05);

    const step = 26.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // A few horizontal scan lines
    final scan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.03);
    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.12 + i * 0.11);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
