import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/battle_room.dart';
import '../services/auth_service.dart';
import '../services/battle_service.dart';
import 'home_screen.dart';

class ResultScreen extends StatefulWidget {
  final BattleRoom room;
  final bool isHost;

  const ResultScreen({super.key, required this.room, required this.isHost});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    _recordResult();
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerHaptic());
  }

  void _triggerHaptic() {
    final auth = context.read<AuthService>();
    final iWon = widget.room.winnerId == auth.currentUser?.uid;
    if (iWon) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _recordResult() async {
    final battle = context.read<BattleService>();
    final claimed = await battle.claimResultRecording(widget.room.id);
    if (!claimed || !mounted) return;
    final auth = context.read<AuthService>();
    final currentUid = auth.currentUser?.uid;
    final iWon = widget.room.winnerId == currentUid;
    final myReps = widget.isHost ? widget.room.hostReps : widget.room.guestReps;
    await auth.recordBattleResult(
      won: iWon,
      repsEarned: myReps,
      exercise: widget.room.exercise,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final currentUid = auth.currentUser?.uid;
    final iWon = widget.room.winnerId == currentUid;
    final isDraw = widget.room.winnerId == null;

    final myReps = widget.isHost ? widget.room.hostReps : widget.room.guestReps;
    final theirReps = widget.isHost ? widget.room.guestReps : widget.room.hostReps;
    final myName = widget.isHost ? widget.room.hostUsername : (widget.room.guestUsername ?? 'You');
    final theirName = widget.isHost ? (widget.room.guestUsername ?? 'Opponent') : widget.room.hostUsername;

    final color = isDraw ? Colors.amber : (iWon ? const Color(0xFF00E5FF) : Colors.redAccent);
    final headline = isDraw ? 'DRAW!' : (iWon ? 'YOU WIN!' : 'YOU LOSE');
    final emoji = isDraw ? '🤝' : (iWon ? '🏆' : '💀');

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          Positioned.fill(
            child: AnimatedContainer(
              duration: 1.seconds,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    color.withValues(alpha: 0.25),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    Text(emoji, style: const TextStyle(fontSize: 90))
                        .animate()
                        .scale(duration: 700.ms, curve: Curves.elasticOut)
                        .then()
                        .shimmer(duration: 1200.ms, color: color.withValues(alpha: 0.6)),

                    const SizedBox(height: 16),

                    Text(
                      headline,
                      style: GoogleFonts.rajdhani(
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        color: color,
                        shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 20)],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms, duration: 500.ms)
                        .slideY(begin: 0.3, curve: Curves.easeOut),

                    const SizedBox(height: 8),

                    Text(
                      iWon ? 'Incredible performance!' : isDraw ? 'Evenly matched!' : 'Better luck next time!',
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ).animate().fadeIn(delay: 500.ms),

                    const Spacer(),

                    // Score cards
                    _ScoreRow(name: myName, reps: myReps, isYou: true, highlight: color)
                        .animate()
                        .fadeIn(delay: 700.ms, duration: 400.ms)
                        .slideX(begin: -0.3),

                    const SizedBox(height: 12),

                    _ScoreRow(name: theirName, reps: theirReps, isYou: false, highlight: null)
                        .animate()
                        .fadeIn(delay: 900.ms, duration: 400.ms)
                        .slideX(begin: 0.3),

                    const SizedBox(height: 48),

                    // Action button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          await context.read<BattleService>().closeRoom(widget.room.id);
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                            (_) => false,
                          );
                        },
                        icon: const Icon(Icons.replay, size: 20),
                        label: Text('BATTLE AGAIN', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: color.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 1100.ms, duration: 400.ms)
                        .slideY(begin: 0.4),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String name;
  final int reps;
  final bool isYou;
  final Color? highlight;

  const _ScoreRow({required this.name, required this.reps, required this.isYou, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = highlight ?? cs.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isYou ? color.withValues(alpha: 0.5) : Colors.white10, width: isYou ? 2 : 1),
        boxShadow: isYou ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 2)] : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isYou ? 'YOU' : 'OPPONENT',
                  style: GoogleFonts.rajdhani(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 2)),
              Text(name, style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
            ],
          ),
          Row(
            children: [
              Text(
                '$reps',
                style: GoogleFonts.rajdhani(fontSize: 36, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(width: 4),
              Text('reps', style: GoogleFonts.rajdhani(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ],
      ),
    );
  }
}
