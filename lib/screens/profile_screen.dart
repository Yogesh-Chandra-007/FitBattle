import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/theme_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, dynamic>> _leaderboard = [];
  bool _loadingLeaderboard = false;
  bool _editingUsername = false;
  final _usernameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loadingLeaderboard = true);
    final auth = context.read<AuthService>();
    final lb = await auth.getLeaderboard();
    if (mounted) setState(() { _leaderboard = lb; _loadingLeaderboard = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profile = auth.profile;
    final uid = auth.currentUser?.uid ?? '';

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<UserProfile?>(
          stream: auth.watchProfile(uid),
          builder: (context, snap) {
            final p = snap.data ?? profile;
            if (p == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, p, auth),
                  const SizedBox(height: 24),
                  _buildStatsGrid(p),
                  const SizedBox(height: 24),
                  _buildRankCard(p),
                  const SizedBox(height: 24),
                  _buildLeaderboard(uid),
                  const SizedBox(height: 24),
                  _buildSettings(context, p, auth),
                  const SizedBox(height: 32),
                  _buildSignOutButton(context, auth),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile p, AuthService auth) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: cs.primary.withValues(alpha: 0.2),
          child: Text(
            p.username.isNotEmpty ? p.username[0].toUpperCase() : '?',
            style: GoogleFonts.rajdhani(fontSize: 32, fontWeight: FontWeight.w800, color: cs.primary),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_editingUsername) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _usernameCtrl,
                        style: TextStyle(color: cs.onSurface),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          fillColor: Theme.of(context).cardColor,
                          filled: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.check, color: cs.primary),
                      onPressed: () async {
                        final name = _usernameCtrl.text.trim();
                        if (name.isNotEmpty) await auth.updateUsername(name);
                        setState(() => _editingUsername = false);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: cs.onSurface.withValues(alpha: 0.4)),
                      onPressed: () => setState(() => _editingUsername = false),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Text(p.username, style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        _usernameCtrl.text = p.username;
                        setState(() => _editingUsername = true);
                      },
                      child: Icon(Icons.edit, color: cs.onSurface.withValues(alpha: 0.4), size: 16),
                    ),
                  ],
                ),
              ],
              Text(p.rank, style: GoogleFonts.rajdhani(fontSize: 14, color: _rankColor(p.rank), fontWeight: FontWeight.w700)),
              Text(p.email, style: GoogleFonts.rajdhani(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(UserProfile p) {
    final winRate = p.winRate.toStringAsFixed(1);
    final calories = p.caloriesBurned.toStringAsFixed(0);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STATS', style: GoogleFonts.rajdhani(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 2)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _statCard('Battles', '${p.totalBattles}', Icons.sports_mma),
            _statCard('Wins', '${p.totalWins}', Icons.emoji_events, color: const Color(0xFF4CAF50)),
            _statCard('Losses', '${p.totalLosses}', Icons.close, color: Colors.redAccent),
            _statCard('Win Rate', '$winRate%', Icons.percent, color: cs.primary),
            _statCard('Streak', '${p.currentStreak}', Icons.local_fire_department, color: Colors.orange),
            _statCard('Total Reps', '${p.totalReps}', Icons.fitness_center),
            _statCard('Calories', '${calories}kcal', Icons.local_dining, color: Colors.amber),
            _statCard('Fav. Exercise', _exerciseEmoji(p.favoriteExercise), Icons.star, color: cs.secondary),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color ?? cs.onSurface.withValues(alpha: 0.6), size: 20),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.w800, color: color ?? cs.onSurface)),
          Text(label, style: GoogleFonts.rajdhani(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildRankCard(UserProfile p) {
    final cs = Theme.of(context).colorScheme;
    final color = _rankColor(p.rank);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.military_tech, color: color, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CURRENT RANK', style: GoogleFonts.rajdhani(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 2)),
              Text(p.rank.toUpperCase(), style: GoogleFonts.rajdhani(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
              Text('${p.totalWins} wins required for next rank', style: GoogleFonts.rajdhani(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(String myUid) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('LEADERBOARD', style: GoogleFonts.rajdhani(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 2)),
            const Spacer(),
            GestureDetector(
              onTap: _loadLeaderboard,
              child: Icon(Icons.refresh, color: cs.onSurface.withValues(alpha: 0.4), size: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loadingLeaderboard)
          const Center(child: CircularProgressIndicator())
        else if (_leaderboard.isEmpty)
          Center(child: Text('No data yet', style: GoogleFonts.rajdhani(color: cs.onSurface.withValues(alpha: 0.4))))
        else
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _leaderboard.length.clamp(0, 10),
              separatorBuilder: (_, __) => Divider(color: Theme.of(context).dividerColor, height: 1),
              itemBuilder: (_, i) {
                final entry = _leaderboard[i];
                final isMe = entry['uid'] == myUid;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: i < 3 ? [Colors.amber, Colors.grey, const Color(0xFFCD7F32)][i] : (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0)),
                    child: Text('${i + 1}', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                  ),
                  title: Text(
                    entry['username'] ?? '???',
                    style: GoogleFonts.rajdhani(fontSize: 15, fontWeight: FontWeight.w700, color: isMe ? cs.primary : cs.onSurface),
                  ),
                  subtitle: Text(entry['rank'] ?? 'Rookie', style: GoogleFonts.rajdhani(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
                  trailing: Text('${entry['wins']} W', style: GoogleFonts.rajdhani(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF4CAF50))),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSettings(BuildContext context, UserProfile p, AuthService auth) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SETTINGS', style: GoogleFonts.rajdhani(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4), letterSpacing: 2)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: SwitchListTile(
            value: themeNotifier.isDark,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              themeNotifier.setDark(v);
              auth.updateTheme(v);
            },
            title: Text('Dark Theme', style: GoogleFonts.rajdhani(fontSize: 16, color: cs.onSurface)),
            secondary: Icon(
              themeNotifier.isDark ? Icons.dark_mode : Icons.light_mode,
              color: cs.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignOutButton(BuildContext context, AuthService auth) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => auth.signOut(),
        icon: const Icon(Icons.logout, color: Colors.redAccent),
        label: Text('Sign Out', style: GoogleFonts.rajdhani(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.redAccent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Color _rankColor(String rank) {
    switch (rank) {
      case 'Legend': return const Color(0xFF00E5FF);
      case 'Diamond': return const Color(0xFF64B5F6);
      case 'Platinum': return const Color(0xFF80CBC4);
      case 'Gold': return const Color(0xFFFFC107);
      case 'Silver': return const Color(0xFFBDBDBD);
      case 'Bronze': return const Color(0xFFCD7F32);
      default: return Colors.white54;
    }
  }

  String _exerciseEmoji(String ex) {
    switch (ex) {
      case 'pushups': return '💪';
      case 'squats': return '🦵';
      case 'jumping_jacks': return '⭐';
      default: return '🏃';
    }
  }
}
