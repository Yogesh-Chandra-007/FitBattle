import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../services/auth_service.dart';
import '../services/battle_service.dart';

class BattleZoneScreen extends StatefulWidget {
  const BattleZoneScreen({super.key});

  @override
  State<BattleZoneScreen> createState() => _BattleZoneScreenState();
}

class _BattleZoneScreenState extends State<BattleZoneScreen> with TickerProviderStateMixin {
  Exercise _selectedExercise = availableExercises.first;
  int _durationMinutes = 1;
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

  int get _durationSeconds => _durationMinutes * 60;
  bool get _isBusy => _creating || _joining || _matchmaking;

  Future<void> _createBattle() async {
    if (_isBusy) return;
    HapticFeedback.mediumImpact();
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
    setState(() { _matchmaking = true; _error = null; });
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

  void _setCreating(bool v) { if (mounted) setState(() => _creating = v); }
  void _setJoining(bool v) { if (mounted) setState(() => _joining = v); }
  void _setError(String? v) { if (mounted) setState(() => _error = v); }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 28),

                  _buildExerciseSelector(context)
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(begin: 0.2),

                  const SizedBox(height: 24),

                  _buildTimerSelector(context)
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms)
                      .slideY(begin: 0.2),

                  const SizedBox(height: 28),

                  _buildActionButtons(context)
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 400.ms)
                      .slideY(begin: 0.2),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: GoogleFonts.rajdhani(color: Colors.redAccent, fontSize: 13))),
                        ],
                      ),
                    ).animate().shake(duration: 400.ms).fadeIn(),
                  ],

                  const SizedBox(height: 28),

                  _buildJoinSection(context)
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 400.ms)
                      .slideY(begin: 0.2),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),

        // Matchmaking overlay
        if (_matchmaking) _MatchmakingOverlay(exercise: _selectedExercise, pulseCtrl: _pulseCtrl),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BATTLE ZONE',
          style: GoogleFonts.rajdhani(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: cs.primary,
            letterSpacing: 2,
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
        Text(
          'Choose your exercise and start a battle',
          style: GoogleFonts.rajdhani(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.4)),
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }

  Widget _buildExerciseSelector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT EXERCISE', style: GoogleFonts.rajdhani(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 2)),
        const SizedBox(height: 12),
        Row(
          children: availableExercises.map((ex) {
            final selected = ex.id == _selectedExercise.id;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedExercise = ex);
                },
                child: AnimatedContainer(
                  duration: 200.ms,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary.withValues(alpha: 0.15) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? cs.primary : Colors.white12,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: cs.primary.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(ex.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        ex.name,
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildTimerSelector(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BATTLE DURATION', style: GoogleFonts.rajdhani(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 2)),
        const SizedBox(height: 12),
        Row(
          children: [1, 2, 3].map((min) {
            final selected = _durationMinutes == min;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _durationMinutes = min);
                },
                child: AnimatedContainer(
                  duration: 200.ms,
                  margin: EdgeInsets.only(right: min < 3 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: selected ? cs.secondary.withValues(alpha: 0.15) : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? cs.secondary : Colors.white12,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: cs.secondary.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1)]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$min',
                        style: GoogleFonts.rajdhani(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: selected ? cs.secondary : cs.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      Text(
                        'MIN',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          color: selected ? cs.secondary : cs.onSurface.withValues(alpha: 0.2),
                          letterSpacing: 1,
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

  Widget _buildActionButtons(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isBusy ? null : _createBattle,
            icon: _creating
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black.withValues(alpha: 0.8)))
                : const Icon(Icons.add_circle_outline),
            label: Text('CREATE BATTLE', style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              shadowColor: cs.primary.withValues(alpha: 0.4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isBusy ? null : _startMatchmaking,
            icon: const Icon(Icons.search),
            label: Text('FIND MATCH', style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1)),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.secondary,
              side: BorderSide(color: cs.secondary, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJoinSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JOIN WITH CODE', style: GoogleFonts.rajdhani(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 2)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _roomCodeCtrl,
                style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: 4),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'XXXXXX',
                  hintStyle: GoogleFonts.rajdhani(fontSize: 18, color: cs.onSurface.withValues(alpha: 0.2), letterSpacing: 4),
                  counterText: '',
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isBusy ? null : _joinBattle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: _joining
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('JOIN', style: GoogleFonts.rajdhani(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
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
            // Pulsing radar rings
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
                      child: Text(exercise.emoji, style: const TextStyle(fontSize: 32)),
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
              style: GoogleFonts.rajdhani(fontSize: 15, color: Colors.white54),
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
