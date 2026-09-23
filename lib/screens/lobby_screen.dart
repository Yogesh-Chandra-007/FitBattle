import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/battle_room.dart';
import '../models/exercise.dart';
import '../services/auth_service.dart';
import '../services/battle_service.dart';
import '../services/theme_service.dart';
import '../utils/fitbattle_goal_mapper.dart';
import '../widgets/cyberpunk_button.dart';
import '../widgets/cyberpunk_card.dart';
import '../widgets/cyberpunk_section_header.dart';
import 'battle_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomId;
  final Exercise exercise;
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.roomId,
    required this.exercise,
    required this.isHost,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _navigating = false;
  bool _codeCopied = false;
  Timer? _copyResetTimer;

  bool _startingBattle = false;

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  Exercise _exerciseFromRoom(BattleRoom room) {
    return availableExercises.firstWhere(
      (e) => e.id == room.exercise,
      orElse: () => availableExercises.first,
    );
  }

  void _goToBattle(BuildContext context, Exercise exercise) {
    if (_navigating) return;
    _navigating = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          roomId: widget.roomId,
          exercise: exercise,
          isHost: widget.isHost,
        ),
      ),
    );
  }

  Future<void> _copyRoomCode() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.roomId));
    } catch (_) {
      // Clipboard can fail on some platforms; keep UI responsive.
    }

    if (!mounted) return;
    setState(() => _codeCopied = true);
    _copyResetTimer?.cancel();
    _copyResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _codeCopied = false);
    });
  }

  Future<void> _startPrivateBattle(BattleService battle) async {
    if (_startingBattle) return;
    setState(() => _startingBattle = true);
    try {
      await battle.startBattle(widget.roomId);
    } finally {
      if (mounted) {
        setState(() => _startingBattle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final battle = context.read<BattleService>();
    final auth = context.read<AuthService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'BATTLE LOBBY',
          style: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        leading: BackButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            await battle.leaveRoom(widget.roomId, widget.isHost);
            nav.pop();
          },
        ),
      ),
      body: StreamBuilder<BattleRoom?>(
        stream: battle.watchRoom(widget.roomId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CyberpunkCard(
                  padding: const EdgeInsets.all(16),
                  glow: false,
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Failed to load room.',
                          style: GoogleFonts.rajdhani(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final room = snapshot.data!;
          final cs = Theme.of(context).colorScheme;
          final exercise = _exerciseFromRoom(room);

          final targetReps = FitBattleGoalMapper.targetRepsFromDurationSeconds(room.durationSeconds);
          final difficulty = FitBattleGoalMapper.difficultyFromDurationSeconds(room.durationSeconds);
          final estTime = FitBattleGoalMapper.estimatedTimeFromDurationSeconds(room.durationSeconds);
          final focus = FitBattleGoalMapper.bodyFocusFromExercise(exercise.id);

          final youUsername = widget.isHost
              ? room.hostUsername
              : (room.guestUsername ?? auth.profile?.username ?? '???');
          final opponentUsername = widget.isHost
              ? (room.guestUsername ?? 'Waiting...')
              : room.hostUsername;
          final opponentReady = widget.isHost ? room.guestId != null : true;

          // Navigation is driven by the shared state, never a host-local route.
          if ((room.status == 'active' || room.status == 'countdown') && !_navigating) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _goToBattle(context, exercise));
          }

          // Matchmaking rooms begin the shared countdown once MATCHED.
          if (widget.isHost &&
              room.isMatchmaking &&
              room.guestId != null &&
              room.status == 'matched' &&
              !_navigating &&
              !_startingBattle) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _startPrivateBattle(battle);
            });
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CyberpunkSectionHeader(
                    title: room.isMatchmaking ? 'QUICK MATCH' : 'PRIVATE ROOM',
                    subtitle: '${exercise.emoji}  ${exercise.name}',
                    color: room.isMatchmaking ? cs.secondary : cs.primary,
                  ).animate().fadeIn(duration: 250.ms),

                  const SizedBox(height: 16),

                  CyberpunkCard(
                    glow: room.isMatchmaking,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$targetReps REPS',
                              style: GoogleFonts.rajdhani(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: cs.primary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: cs.primary.withValues(alpha: 0.35), width: 1),
                                color: cs.primary.withValues(alpha: 0.10),
                              ),
                              child: Text(
                                difficulty.toUpperCase(),
                                style: GoogleFonts.rajdhani(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: cs.onSurface.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.timer_outlined, color: cs.secondary.withValues(alpha: 0.95), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              estTime,
                              style: GoogleFonts.rajdhani(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Icon(Icons.local_fire_department_outlined, color: cs.primary.withValues(alpha: 0.95), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              focus,
                              style: GoogleFonts.rajdhani(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 80.ms, duration: 300.ms),

                  const SizedBox(height: 16),

                  if (!room.isMatchmaking) ...[
                    CyberpunkCard(
                      padding: const EdgeInsets.all(16),
                      glow: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ROOM CODE',
                            style: GoogleFonts.rajdhani(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: cs.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: cs.primary.withValues(alpha: 0.30), width: 1),
                                    color: Colors.transparent,
                                  ),
                                  child: Text(
                                    widget.roomId,
                                    style: GoogleFonts.rajdhani(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 6,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: _copyRoomCode,
                                    icon: Icon(
                                      _codeCopied ? Icons.check_circle : Icons.copy,
                                      color: _codeCopied ? cs.secondary : cs.primary,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _codeCopied ? 'COPIED' : 'COPY',
                                    style: GoogleFonts.rajdhani(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      color: cs.onSurface.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Icon(Icons.share_outlined, size: 18, color: cs.onSurface.withValues(alpha: 0.45)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Send this code to your opponent (or tap COPY to put it on your clipboard).',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface.withValues(alpha: 0.55),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          )
                                .animate()
                                .fadeIn(delay: 60.ms, duration: 250.ms),
                        ],
                      ),
                    ).animate().fadeIn(delay: 40.ms, duration: 250.ms),

                    const SizedBox(height: 16),
                  ] else ...[
                    CyberpunkCard(
                      padding: const EdgeInsets.all(16),
                      glow: true,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation(cs.secondary),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room.guestId == null ? 'FINDING OPPONENT...' : 'OPPONENT LOCKED...',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    color: room.guestId == null ? cs.secondary : cs.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  room.status == 'matched'
                                      ? 'Starting soon.'
                                      : 'Hold tight—matchmaking in progress.',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],

                  CyberpunkCard(
                    padding: const EdgeInsets.all(16),
                    glow: false,
                    child: Column(
                      children: [
                        _PlayerSlot(
                          label: 'YOU',
                          username: youUsername,
                          ready: true,
                          accent: cs.primary,
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'VS',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PlayerSlot(
                          label: 'OPPONENT',
                          username: opponentUsername,
                          ready: opponentReady,
                          accent: cs.secondary,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 60.ms, duration: 250.ms),

                  const SizedBox(height: 20),

                  if (widget.isHost && !room.isMatchmaking && room.guestId != null)
                    CyberpunkButton(
                      variant: CyberButtonVariant.battle,
                      label: 'START BATTLE',
                      onPressed: () => _startPrivateBattle(battle),
                      isBusy: _startingBattle,
                      leading: const Icon(Icons.flash_on, color: Colors.black),
                      height: 58,
                    ).animate().scale(duration: 250.ms, curve: Curves.easeOut)
                  else if (widget.isHost && !room.isMatchmaking)
                    CyberpunkCard(
                      padding: const EdgeInsets.all(14),
                      glow: false,
                      child: Text(
                        'Share the room code with your opponent.',
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface.withValues(alpha: 0.60),
                        ),
                      ),
                    )
                  else if (!widget.isHost && !room.isMatchmaking)
                    CyberpunkCard(
                      padding: const EdgeInsets.all(14),
                      glow: false,
                      child: Text(
                        'Waiting for host to start...',
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface.withValues(alpha: 0.60),
                        ),
                      ),
                    )
                  else if (widget.isHost && room.isMatchmaking)
                    CyberpunkCard(
                      padding: const EdgeInsets.all(14),
                      glow: false,
                      child: Text(
                        room.guestId != null ? 'Match found—starting soon.' : 'Searching for opponent...',
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: room.guestId != null ? cs.primary : cs.onSurface.withValues(alpha: 0.60),
                        ),
                      ),
                    )
                  else
                    CyberpunkCard(
                      padding: const EdgeInsets.all(14),
                      glow: false,
                      child: Text(
                        room.guestId != null ? 'Match found—starting soon.' : 'Finding host...',
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cs.secondary,
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  final String label;
  final String username;
  final bool ready;
  final Color accent;

  const _PlayerSlot({
    required this.label,
    required this.username,
    required this.ready,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: CyberpunkColors.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready ? accent.withValues(alpha: 0.40) : cs.onSurface.withValues(alpha: 0.10),
          width: 1.2,
        ),
        boxShadow: ready
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: ready ? accent : cs.onSurface.withValues(alpha: 0.35)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rajdhani(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (ready)
            Icon(Icons.check_circle, color: accent)
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
        ],
      ),
    );
  }
}
