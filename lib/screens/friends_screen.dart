import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/exercise.dart';
import '../services/auth_service.dart';
import '../services/battle_service.dart';
import '../services/friends_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchCtrl = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final auth = context.read<AuthService>();
    final results = await auth.searchUsers(q);
    if (mounted) setState(() { _searchResults = results; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    final friends = context.read<FriendsService>();
    final auth = context.read<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(friends, auth),
            _buildInvitesSection(friends),
            Expanded(child: _buildFriendsList(friends, auth)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(FriendsService friends, AuthService auth) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by username...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _searching ? null : _search,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _searching
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Search', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Material(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                children: _searchResults.map((u) {
                  final myUid = auth.currentUser?.uid ?? '';
                  if (u.uid == myUid) return const SizedBox.shrink();
                  return FutureBuilder<bool>(
                    future: friends.isFriend(u.uid),
                    builder: (context, snap) {
                      final already = snap.data ?? false;
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                          child: Text(u.username[0].toUpperCase(), style: GoogleFonts.rajdhani(color: const Color(0xFF00E5FF), fontWeight: FontWeight.w800)),
                        ),
                        title: Text(u.username, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        subtitle: Text(u.rank, style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11)),
                        trailing: already
                            ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 22)
                            : IconButton(
                                icon: const Icon(Icons.person_add, color: Color(0xFF00E5FF)),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  await friends.addFriend(u.uid);
                                  if (!mounted) return;
                                  setState(() => _searchResults = []);
                                  _searchCtrl.clear();
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('${u.username} added!'), backgroundColor: const Color(0xFF4CAF50)),
                                  );
                                },
                              ),
                      );
                    },
                  );
                }).toList(),
              ),
              ),  // Material
            ),
          ],  // if spread list
        ],  // outer Column children
      ),
    );
  }

  Widget _buildInvitesSection(FriendsService friends) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: friends.watchInvites(),
      builder: (context, snap) {
        final invites = snap.data ?? [];
        if (invites.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A00),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text('BATTLE INVITES', style: GoogleFonts.rajdhani(fontSize: 11, color: const Color(0xFFFFC107), letterSpacing: 2)),
              ),
              ...invites.map((inv) => Material(
                color: Colors.transparent,
                child: ListTile(
                dense: true,
                leading: const Icon(Icons.sports_mma, color: Color(0xFFFFC107)),
                title: Text(
                  '${inv['fromUsername'] ?? 'Someone'} challenges you!',
                  style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text('Exercise: ${inv['exercise'] ?? '?'}', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _acceptInvite(inv),
                      child: Text('JOIN', style: GoogleFonts.rajdhani(color: const Color(0xFF00E5FF), fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                      onPressed: () => friends.dismissInvite(inv['roomId']),
                    ),
                  ],
                ),
              ))),  // ListTile, Material, map
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptInvite(Map<String, dynamic> invite) async {
    final friends = context.read<FriendsService>();
    final battle = context.read<BattleService>();
    final roomId = invite['roomId'] as String;
    final exerciseId = invite['exercise'] as String;

    final exercise = availableExercises.firstWhere((e) => e.id == exerciseId, orElse: () => availableExercises.first);

    await friends.dismissInvite(roomId);
    final joined = await battle.joinRoom(roomId);
    if (!mounted) return;

    if (joined) {
      Navigator.pushNamed(context, '/lobby', arguments: {'roomId': roomId, 'exercise': exercise, 'isHost': false});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room is no longer available.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _buildFriendsList(FriendsService friends, AuthService auth) {
    return StreamBuilder<List<UserProfile>>(
      stream: friends.watchFriends(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.group, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                Text('No friends yet', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 16)),
                Text('Search for users above to add friends', style: GoogleFonts.rajdhani(color: Colors.white24, fontSize: 12)),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('FRIENDS (${list.length})', style: GoogleFonts.rajdhani(fontSize: 12, color: Colors.white38, letterSpacing: 2)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: list.length,
                itemBuilder: (_, i) => _buildFriendTile(list[i], friends),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFriendTile(UserProfile friend, FriendsService friends) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              child: Text(
                friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?',
                style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF00E5FF)),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: friend.isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                  border: const Border.fromBorderSide(BorderSide(color: Color(0xFF141414), width: 1.5)),
                ),
              ),
            ),
          ],
        ),
        title: Text(friend.username, style: GoogleFonts.rajdhani(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        subtitle: Row(
          children: [
            Text(friend.rank, style: GoogleFonts.rajdhani(fontSize: 11, color: Colors.white38)),
            const SizedBox(width: 6),
            Text(friend.isOnline ? '• Online' : '• Offline', style: GoogleFonts.rajdhani(fontSize: 11, color: friend.isOnline ? const Color(0xFF4CAF50) : Colors.white24)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (friend.isOnline)
              IconButton(
                icon: const Icon(Icons.sports_mma, color: Color(0xFF00E5FF), size: 20),
                tooltip: 'Invite to battle',
                onPressed: () => _showInviteDialog(friend),
              ),
            IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.white24, size: 18),
              tooltip: 'Remove friend',
              onPressed: () => _confirmRemove(friend, friends),
            ),
          ],
        ),
      ),  // ListTile
      ),  // Material
    );   // Container
  }

  Future<void> _showInviteDialog(UserProfile friend) async {
    final battle = context.read<BattleService>();
    final friends = context.read<FriendsService>();

    Exercise? selectedExercise = availableExercises.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text('Invite ${friend.username}', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.w800)),
          content: RadioGroup<Exercise>(
            groupValue: selectedExercise!,
            onChanged: (v) => setDialog(() => selectedExercise = v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableExercises.map((ex) {
                return RadioListTile<Exercise>(
                  value: ex,
                  activeColor: const Color(0xFF00E5FF),
                  title: Text('${ex.emoji} ${ex.name}', style: GoogleFonts.rajdhani(color: Colors.white)),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.rajdhani(color: Colors.white38))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final roomId = await battle.createRoom(selectedExercise!.id, 60);
                await friends.sendBattleInvite(friend.uid, roomId, selectedExercise!.id);
                if (!mounted) return;
                Navigator.pushNamed(context, '/lobby', arguments: {
                  'roomId': roomId,
                  'exercise': selectedExercise,
                  'isHost': true,
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
              child: Text('SEND INVITE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(UserProfile friend, FriendsService friends) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Remove ${friend.username}?', style: GoogleFonts.rajdhani(color: Colors.white)),
        content: Text('They will be removed from your friends list.', style: GoogleFonts.rajdhani(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.rajdhani(color: Colors.white38))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: GoogleFonts.rajdhani(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) await friends.removeFriend(friend.uid);
  }
}
