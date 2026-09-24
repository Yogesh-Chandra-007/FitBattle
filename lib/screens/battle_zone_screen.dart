import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../services/auth_service.dart';
import '../services/battle_service.dart';
import '../utils/fitbattle_goal_mapper.dart';
import '../widgets/cyberpunk_card.dart';
import '../widgets/cyberpunk_stat_tile.dart';

class BattleZoneScreen extends StatefulWidget {
  const BattleZoneScreen({super.key});

  @override
  State<BattleZoneScreen> createState() => _BattleZoneScreenState();
}

class _BattleZoneScreenState extends State<BattleZoneScreen> with TickerProviderStateMixin {
  Exercise _selectedExercise = availableExercises.first;

  /// Duration in seconds: 30, 60, or 90
  int _durationSeconds = FitBattleGoalMapper.defaultDuration;

  bool _creating = false;
  bool _joining = false;
  bool _matchmaking = false;

  final _roomCodeCtrl = TextEditingController();
  String? _error;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: 1200.ms)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _roomCodeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  bool get _isBusy => _creating || _joining || _matchmaking;

  Future<void> _createBattle() async {
    if (_isBusy) return;

    HapticFeedback.mediumImpact();
    final duration = await _promptDuration();
    if (!mounted || duration == null) return;
    _durationSeconds = duration;

    _setCreating(true);
    try {
      final battle = context.read<BattleService>();
      final roomId = await battle.createRoom(_selectedExercise.id, _durationSeconds);
      if (!mounted) return;
      Navigator.pushNamed(context, '/lobby', arguments: {
        'roomId': roomId,
        'exercise': _selectedExercise,
        'isHost': true,
      });
    } catch (e) {
      _setError('Failed to create room: $e');
    } finally {
      _setCreating(false);
    }
  }

  Future<void> _joinBattle() async {
    if (_isBusy) return;
    final code = _roomCodeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      _setError('Enter a room code.');
      return;
    }
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
      _setError('Invalid room code format. Use 6 characters (A–Z, 0–9).');
      return;
    }

    HapticFeedback.mediumImpact();
    _setJoining(true);
    _setError(null);

    try {
      final battle = context.read<BattleService>();
      final joined = await battle.joinRoom(code);
      if (!mounted) return;

      if (joined) {
        Navigator.pushNamed(context, '/lobby', arguments: {
          'roomId': code,
          'exercise': _selectedExercise,
          'isHost': false,
        });
      } else {
        _setError('Room not found or already full.');
      }
    } catch (e) {
      _setError('Failed to join room: $e');
    } finally {
      _setJoining(false);
    }
  }

  Future<void> _startMatchmaking() async {
    if (_isBusy) return;
    HapticFeedback.heavyImpact();

    final duration = await _promptDuration();
    if (!mounted || duration == null) return;
    _durationSeconds = duration;

    setState(() {
      _matchmaking = true;
      _error = null;
    });

    final battle = context.read<BattleService>();
    final myUid = context.read<AuthService>().currentUser?.uid ?? '';

    try {
      final roomId = await battle.findOrCreateMatchmakingRoom(_selectedExercise.id, _durationSeconds);
      if (!mounted) return;

      final room = battle.currentRoom;
      final isHost = room == null || room.hostId == myUid;

      Navigator.pushNamed(context, '/lobby', arguments: {
        'roomId': roomId,
        'exercise': _selectedExercise,
        'isHost': isHost,
      });
    } catch (e) {
      _setError('Matchmaking failed: $e');
    } finally {
      if (mounted) setState(() => _matchmaking = false);
    }
  }

  void _setCreating(bool v) {
    if (mounted) setState(() => _creating = v);
  }

  void _setJoining(bool v) {
    if (mounted) setState(() => _joining = v);
  }

  Future<int?> _promptDuration() {
    final cs = Theme.of(context).colorScheme;
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose battle duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final duration in FitBattleGoalMapper.availableDurations)
              ListTile(
                title: Text(FitBattleGoalMapper.durationLabel(duration)),
                subtitle: Text(FitBattleGoalMapper.difficultyFromDurationSeconds(duration)),
                selected: duration == _durationSeconds,
                selectedColor: cs.primary,
                onTap: () => Navigator.pop(context, duration),
              ),
          ],
        ),
      ),
    );
  }

  void _setError(String? v) {
    if (mounted) setState(() => _error = v);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profile = auth.profile;
    final cs = Theme.of(context).colorScheme;

    final dayStreak = profile?.currentStreak ?? 0;
    final battlesWon = profile?.totalWins ?? 0;
    final totalReps = profile?.totalReps ?? 0;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreeting(profile, cs),
                  const SizedBox(height: 16),

                  CyberpunkCard(
                    glow: false,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: CyberpunkStatTile(
                            label: 'Day Streak',
                            value: '$dayStreak',
                            icon: Icons.local_fire_department,
                            valueColor: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CyberpunkStatTile(
                            label: 'Battles Won',
                            value: '$battlesWon',
                            icon: Icons.emoji_events,
                            valueColor: Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CyberpunkStatTile(
                            label: 'Total Reps',
                            value: '$totalReps',
                            icon: Icons.fitness_center,
                            valueColor: cs.secondary,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 80.ms),

                  const SizedBox(height: 18),

                  _buildQuickBattleBlock(cs),
                  const SizedBox(height: 12),
                  _buildCreateRoomTile(cs),
                  const SizedBox(height: 12),
                  _buildTimerDurationSelector(cs),

                  const SizedBox(height: 16),


                  _buildJoinRoomBlock(cs),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorCard(_error!, cs),
                  ],

                  const SizedBox(height: 22),

                  _buildPopularExercises(cs),
                  const SizedBox(height: 20),

                  _buildQuoteCard(cs),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),

        if (_matchmaking) _MatchmakingOverlay(exercise: _selectedExercise, pulseCtrl: _pulseCtrl),
      ],
    );
  }

  Widget _buildGreeting(UserProfile? profile, ColorScheme cs) {
    final name = profile?.username.isNotEmpty == true ? profile!.username : 'Fighter';
    final rank = profile?.rank ?? 'Rookie';
    final rankBadge = rank.length >= 2 ? rank.substring(0, 2).toUpperCase() : rank.toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hey $name.',
                style: GoogleFonts.rajdhani(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ready to battle today?',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.secondary.withValues(alpha: 0.55)),
                color: cs.secondary.withValues(alpha: 0.12),
              ),
              child: Text(
                rankBadge,
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: cs.secondary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickBattleBlock(ColorScheme cs) {
    final isBusy = _isBusy && _matchmaking;

    return SizedBox(
      width: double.infinity,
      height: 76,
      child: ElevatedButton(
        onPressed: _isBusy ? null : _startMatchmaking,
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: Colors.black,
          elevation: 10,
          shadowColor: cs.primary.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: Colors.black, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Quick Battle',
                    style: GoogleFonts.rajdhani(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Find a random opponent',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isBusy)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            else
              const Icon(Icons.chevron_right, color: Colors.black, size: 28),
          ],
        ),
      ).animate().fadeIn(duration: 350.ms, delay: 80.ms).slideY(begin: 0.12),
    );
  }

  Widget _buildCreateRoomTile(ColorScheme cs) {
    final disabled = _isBusy;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: disabled ? null : _createBattle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: cs.onSurface.withValues(alpha: 0.06),
          border: Border.all(color: cs.primary.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.12),
              blurRadius: 14,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.group, color: cs.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create Room',
                    style: GoogleFonts.rajdhani(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Play with friends',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (_creating)
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              const Icon(Icons.chevron_right, color: Colors.white38, size: 24),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 350.ms, delay: 140.ms).slideY(begin: 0.12);
  }

  Widget _buildTimerDurationSelector(ColorScheme cs) {
    final selectedDuration = _durationSeconds;
    final competitive = Theme.of(context).colorScheme.error;

    final difficulty = FitBattleGoalMapper.difficultyFromDurationSeconds(_durationSeconds);
    final focus = FitBattleGoalMapper.bodyFocusFromExercise(_selectedExercise.id);

    Widget pill(int durationSeconds, String label, {required bool isSelected}) {
      return GestureDetector(
        onTap: _isBusy
            ? null
            : () {
                setState(() => _durationSeconds = durationSeconds);
              },
        child: AnimatedContainer(
          duration: 180.ms,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? competitive.withValues(alpha: 0.95) : cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? competitive : cs.primary.withValues(alpha: 0.18),
              width: isSelected ? 0 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isSelected ? Colors.black : cs.onSurface.withValues(alpha: 0.7),
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
    }

    return CyberpunkCard(
      padding: const EdgeInsets.all(16),
      glow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TIMER DURATION',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.timer, color: cs.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                FitBattleGoalMapper.durationLabel(_durationSeconds),
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
          const SizedBox(height: 6),
          Text(
            focus,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < FitBattleGoalMapper.availableDurations.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  pill(
                    FitBattleGoalMapper.availableDurations[i],
                    FitBattleGoalMapper.durationLabel(FitBattleGoalMapper.availableDurations[i]),
                    isSelected: selectedDuration == FitBattleGoalMapper.availableDurations[i],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinRoomBlock(ColorScheme cs) {
    return CyberpunkCard(
      padding: const EdgeInsets.all(16),
      glow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.login, color: cs.secondary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Join Room',
                style: GoogleFonts.rajdhani(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter a room code to join a battle',
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomCodeCtrl,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.rajdhani(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                    letterSpacing: 4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XXXXXX',
                    counterText: '',
                    hintStyle: GoogleFonts.rajdhani(
                      fontSize: 18,
                      color: cs.onSurface.withValues(alpha: 0.2),
                      letterSpacing: 4,
                      fontWeight: FontWeight.w800,
                    ),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isBusy ? null : _joinBattle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    elevation: 8,
                    shadowColor: cs.secondary.withValues(alpha: 0.25),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Join',
                          style: GoogleFonts.rajdhani(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error, ColorScheme cs) {
    return CyberpunkCard(
      padding: const EdgeInsets.all(14),
      glow: false,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ),
          Icon(Icons.shield_outlined, color: cs.onSurface.withValues(alpha: 0.35), size: 18),
        ],
      ),
    ).animate().shake(duration: 400.ms);
  }

  Widget _buildPopularExercises(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Popular Exercises',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: cs.onSurface.withValues(alpha: 0.45),
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            Text(
              'View All',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: availableExercises.map((ex) {
            final selected = ex.id == _selectedExercise.id;

            return Expanded(
              child: GestureDetector(
                onTap: _isBusy
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedExercise = ex);
                      },
                child: AnimatedContainer(
                  duration: 180.ms,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary.withValues(alpha: 0.12) : cs.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.12),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(ex.emoji, style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 8),
                      Text(
                        ex.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                          color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.55),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuoteCard(ColorScheme cs) {
    return CyberpunkCard(
      padding: const EdgeInsets.all(18),
      glow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"Discipline today,\nDominance tomorrow."',
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              color: cs.onSurface.withValues(alpha: 0.6),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 2,
            width: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: cs.primary,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 80.ms);
  }
}

class _MatchmakingOverlay extends StatelessWidget {
  final Exercise exercise;
  final AnimationController pulseCtrl;

  const _MatchmakingOverlay({required this.exercise, required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: pulseCtrl,
                    builder: (_, __) => Container(
                      width: 160 * (0.5 + pulseCtrl.value * 0.5),
                      height: 160 * (0.5 + pulseCtrl.value * 0.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.primary.withValues(alpha: (1 - pulseCtrl.value) * 0.6),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: pulseCtrl,
                    builder: (_, __) => Container(
                      width: 100 * (0.5 + pulseCtrl.value * 0.5),
                      height: 100 * (0.5 + pulseCtrl.value * 0.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.primary.withValues(alpha: (1 - pulseCtrl.value) * 0.8),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary.withValues(alpha: 0.15),
                      border: Border.all(color: cs.primary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        exercise.emoji,
                        style: GoogleFonts.rajdhani(fontSize: 32, fontWeight: FontWeight.w900, color: cs.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'FINDING OPPONENT',
              style: GoogleFonts.rajdhani(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: cs.primary,
                letterSpacing: 3,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms, color: cs.primary),

            const SizedBox(height: 8),

            Text(
              exercise.name,
              style: GoogleFonts.rajdhani(fontSize: 15, color: Colors.white54, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}
