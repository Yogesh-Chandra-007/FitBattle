import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class UserProfile {
  final String uid;
  final String username;
  final String email;
  final int totalBattles;
  final int totalWins;
  final int totalLosses;
  final int currentStreak;
  final int totalReps;
  final double caloriesBurned;
  final String favoriteExercise;
  final String rank;
  final bool isDarkTheme;
  final bool isOnline;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.email,
    this.totalBattles = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.currentStreak = 0,
    this.totalReps = 0,
    this.caloriesBurned = 0,
    this.favoriteExercise = 'pushups',
    this.rank = 'Rookie',
    this.isDarkTheme = true,
    this.isOnline = false,
  });

  double get winRate => totalBattles == 0 ? 0 : (totalWins / totalBattles * 100);

  factory UserProfile.fromMap(String uid, Map<dynamic, dynamic> map) {
    return UserProfile(
      uid: uid,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      totalBattles: map['totalBattles'] ?? 0,
      totalWins: map['totalWins'] ?? 0,
      totalLosses: map['totalLosses'] ?? 0,
      currentStreak: map['currentStreak'] ?? 0,
      totalReps: map['totalReps'] ?? 0,
      caloriesBurned: (map['caloriesBurned'] ?? 0).toDouble(),
      favoriteExercise: map['favoriteExercise'] ?? 'pushups',
      rank: map['rank'] ?? 'Rookie',
      isDarkTheme: map['isDarkTheme'] ?? true,
      isOnline: map['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'username': username,
        'email': email,
        'totalBattles': totalBattles,
        'totalWins': totalWins,
        'totalLosses': totalLosses,
        'currentStreak': currentStreak,
        'totalReps': totalReps,
        'caloriesBurned': caloriesBurned,
        'favoriteExercise': favoriteExercise,
        'rank': rank,
        'isDarkTheme': isDarkTheme,
        'isOnline': isOnline,
      };
}

String _calcRank(int wins) {
  if (wins >= 100) return 'Legend';
  if (wins >= 50) return 'Diamond';
  if (wins >= 25) return 'Platinum';
  if (wins >= 10) return 'Gold';
  if (wins >= 5) return 'Silver';
  if (wins >= 1) return 'Bronze';
  return 'Rookie';
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  Future<UserCredential> signUp(String email, String password, String username) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user!.updateDisplayName(username);
    final profileData = {
      'username': username,
      'email': email,
      'totalWins': 0,
      'totalLosses': 0,
      'totalBattles': 0,
      'currentStreak': 0,
      'totalReps': 0,
      'caloriesBurned': 0,
      'favoriteExercise': 'pushups',
      'rank': 'Rookie',
      'isDarkTheme': true,
      'isOnline': true,
      'createdAt': ServerValue.timestamp,
    };
    await _db.child('users/${cred.user!.uid}').set(profileData);
    _profile = UserProfile.fromMap(cred.user!.uid, profileData);
    notifyListeners();
    return cred;
  }

  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _db.child('users/${cred.user!.uid}').update({'isOnline': true});
    await loadProfile();
    notifyListeners();
    return cred;
  }

  Future<void> signOut() async {
    if (currentUser != null) {
      await _db.child('users/${currentUser!.uid}').update({'isOnline': false});
    }
    _profile = null;
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> loadProfile() async {
    if (currentUser == null) return;
    final snap = await _db.child('users/${currentUser!.uid}').get();
    if (snap.exists) {
      _profile = UserProfile.fromMap(currentUser!.uid, snap.value as Map<dynamic, dynamic>);
      notifyListeners();
    }
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _db.child('users/$uid').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      return UserProfile.fromMap(uid, event.snapshot.value as Map<dynamic, dynamic>);
    });
  }

  Future<void> updateTheme(bool isDark) async {
    if (currentUser == null) return;
    await _db.child('users/${currentUser!.uid}').update({'isDarkTheme': isDark});
    if (_profile != null) {
      _profile = UserProfile.fromMap(currentUser!.uid, {
        ..._profile!.toMap(),
        'isDarkTheme': isDark,
      });
      notifyListeners();
    }
  }

  Future<void> updateUsername(String newUsername) async {
    if (currentUser == null) return;
    await currentUser!.updateDisplayName(newUsername);
    await _db.child('users/${currentUser!.uid}').update({'username': newUsername});
    await loadProfile();
  }

  Future<void> recordBattleResult({
    required bool won,
    required int repsEarned,
    required String exercise,
  }) async {
    if (currentUser == null) return;
    final snap = await _db.child('users/${currentUser!.uid}').get();
    if (!snap.exists) return;
    final data = snap.value as Map<dynamic, dynamic>;
    final battles = (data['totalBattles'] ?? 0) + 1;
    final wins = (data['totalWins'] ?? 0) + (won ? 1 : 0);
    final losses = (data['totalLosses'] ?? 0) + (won ? 0 : 1);
    final streak = won ? (data['currentStreak'] ?? 0) + 1 : 0;
    final totalReps = (data['totalReps'] ?? 0) + repsEarned;
    // Rough calorie estimate: ~0.5 cal per rep average
    final calories = (data['caloriesBurned'] ?? 0.0) + repsEarned * 0.5;

    // Determine favorite exercise by counting
    final exCounts = Map<String, int>.from(data['exerciseCounts'] ?? {});
    exCounts[exercise] = (exCounts[exercise] ?? 0) + 1;
    final favorite = exCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final rank = _calcRank(wins);

    await _db.child('users/${currentUser!.uid}').update({
      'totalBattles': battles,
      'totalWins': wins,
      'totalLosses': losses,
      'currentStreak': streak,
      'totalReps': totalReps,
      'caloriesBurned': calories,
      'favoriteExercise': favorite,
      'exerciseCounts': exCounts,
      'rank': rank,
    });

    // Update leaderboard
    await _db.child('leaderboard/${currentUser!.uid}').update({
      'username': data['username'] ?? currentUser!.displayName ?? 'Player',
      'wins': wins,
      'rank': rank,
    });

    await loadProfile();
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final snap = await _db.child('users').get();
    if (!snap.exists) return [];
    final all = snap.value as Map<dynamic, dynamic>;
    return all.entries
        .where((e) {
          final uname = (e.value as Map)['username']?.toString().toLowerCase() ?? '';
          return uname.contains(query.toLowerCase()) && e.key != currentUser?.uid;
        })
        .map((e) => UserProfile.fromMap(e.key as String, e.value as Map<dynamic, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final snap = await _db.child('leaderboard').orderByChild('wins').limitToLast(50).get();
    if (!snap.exists) return [];
    final map = snap.value as Map<dynamic, dynamic>;
    final list = map.entries.map((e) => {
      'uid': e.key,
      'username': (e.value as Map)['username'] ?? '',
      'wins': (e.value as Map)['wins'] ?? 0,
      'rank': (e.value as Map)['rank'] ?? 'Rookie',
    }).toList();
    list.sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
    return list;
  }
}
