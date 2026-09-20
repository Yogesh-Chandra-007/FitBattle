import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/battle_room.dart';
import '../models/exercise.dart';
import '../services/auth_service.dart';
import '../services/battle_service.dart';
import 'battle_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomId;
  final Exercise exercise;
  final bool isHost;

  const LobbyScreen({super.key, required this.roomId, required this.exercise, required this.isHost});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _navigating = false;

  void _goToBattle(BuildContext context) {
    if (_navigating) return;
    _navigating = true;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => BattleScreen(
        roomId: widget.roomId,
        exercise: widget.exercise,
        isHost: widget.isHost,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final battle = context.read<BattleService>();
    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Room: ${widget.roomId}', style: GoogleFonts.rajdhani(fontSize: 20, letterSpacing: 4, color: const Color(0xFF00E5FF))),
        centerTitle: true,
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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final room = snapshot.data!;

          // Navigation is driven by the shared state, never a host-local route.
          if ((room.status == 'active' || room.status == 'countdown') && !_navigating) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _goToBattle(context));
          }

          // Matchmaking rooms begin the shared countdown once MATCHED.
          if (widget.isHost && room.isMatchmaking && room.guestId != null && room.status == 'matched' && !_navigating) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await battle.startBattle(widget.roomId);
            });
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(widget.exercise.emoji, style: const TextStyle(fontSize: 80)),
                const SizedBox(height: 8),
                Text(widget.exercise.name, style: GoogleFonts.rajdhani(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                _DurationBadge(seconds: room.durationSeconds),
                const SizedBox(height: 32),

                if (!room.isMatchmaking) ...[
                  Text('ROOM CODE', style: GoogleFonts.rajdhani(fontSize: 13, color: Colors.white38, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00E5FF), width: 2),
                    ),
                    child: Text(widget.roomId,
                        style: GoogleFonts.rajdhani(fontSize: 38, fontWeight: FontWeight.w900, color: const Color(0xFF00E5FF), letterSpacing: 8)),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC107))),
                        const SizedBox(width: 8),
                        Text('Finding opponent...', style: GoogleFonts.rajdhani(color: const Color(0xFFFFC107), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                _PlayerSlot(label: 'YOU', username: widget.isHost ? room.hostUsername : (room.guestUsername ?? auth.profile?.username ?? '???'), ready: true),
                const SizedBox(height: 8),
                const Text('VS', style: TextStyle(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _PlayerSlot(
                  label: 'OPPONENT',
                  username: widget.isHost ? (room.guestUsername ?? 'Waiting...') : room.hostUsername,
                  ready: widget.isHost ? room.guestId != null : true,
                ),

                const Spacer(),

                if (widget.isHost && !room.isMatchmaking && room.guestId != null)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => battle.startBattle(widget.roomId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('START BATTLE', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                  )
                else if (widget.isHost && !room.isMatchmaking)
                  Text('Share the room code with your opponent', style: GoogleFonts.rajdhani(fontSize: 16, color: Colors.white38))
                else if (!widget.isHost)
                  Text('Waiting for host to start...', style: GoogleFonts.rajdhani(fontSize: 16, color: Colors.white38))
                else
                  Text('Match found! Starting soon...', style: GoogleFonts.rajdhani(fontSize: 16, color: const Color(0xFF00E5FF))),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  final int seconds;
  const _DurationBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final mins = seconds ~/ 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Color(0xFFFFC107), size: 16),
          const SizedBox(width: 6),
          Text('$mins minute${mins != 1 ? 's' : ''}', style: GoogleFonts.rajdhani(color: const Color(0xFFFFC107), fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  final String label;
  final String username;
  final bool ready;

  const _PlayerSlot({required this.label, required this.username, required this.ready});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ready ? const Color(0xFF00E5FF).withValues(alpha: 0.4) : Colors.white10),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: ready ? const Color(0xFF00E5FF) : Colors.white38),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.rajdhani(fontSize: 11, color: Colors.white38, letterSpacing: 2)),
              Text(username, style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const Spacer(),
          if (ready)
            const Icon(Icons.check_circle, color: Color(0xFF00E5FF))
          else
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}
