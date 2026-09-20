import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';

class FriendsService extends ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<List<UserProfile>> watchFriends() {
    return _db.child('friends/$_uid').onValue.asyncMap((event) async {
      if (!event.snapshot.exists) return [];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      final friendUids = map.keys.cast<String>().toList();

      final profiles = <UserProfile>[];
      for (final uid in friendUids) {
        final snap = await _db.child('users/$uid').get();
        if (snap.exists) {
          profiles.add(UserProfile.fromMap(uid, snap.value as Map<dynamic, dynamic>));
        }
      }
      return profiles;
    });
  }

  Future<void> addFriend(String friendUid) async {
    if (_uid.isEmpty || friendUid == _uid) return;
    await _db.child('friends/$_uid/$friendUid').set(true);
    await _db.child('friends/$friendUid/$_uid').set(true);
    notifyListeners();
  }

  Future<void> removeFriend(String friendUid) async {
    if (_uid.isEmpty) return;
    await _db.child('friends/$_uid/$friendUid').remove();
    await _db.child('friends/$friendUid/$_uid').remove();
    notifyListeners();
  }

  Future<bool> isFriend(String friendUid) async {
    if (_uid.isEmpty) return false;
    final snap = await _db.child('friends/$_uid/$friendUid').get();
    return snap.exists;
  }

  Future<void> sendBattleInvite(String friendUid, String roomId, String exercise) async {
    if (_uid.isEmpty) return;
    final mySnap = await _db.child('users/$_uid').get();
    final myName = mySnap.exists ? (mySnap.value as Map)['username'] ?? 'Player' : 'Player';

    await _db.child('invites/$friendUid/$roomId').set({
      'fromUid': _uid,
      'fromUsername': myName,
      'roomId': roomId,
      'exercise': exercise,
      'timestamp': ServerValue.timestamp,
    });
  }

  Stream<List<Map<String, dynamic>>> watchInvites() {
    return _db.child('invites/$_uid').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final map = event.snapshot.value as Map<dynamic, dynamic>;
      return map.entries.map((e) => {
        'roomId': e.key,
        ...(e.value as Map<dynamic, dynamic>).map((k, v) => MapEntry(k.toString(), v)),
      }).toList();
    });
  }

  Future<void> dismissInvite(String roomId) async {
    await _db.child('invites/$_uid/$roomId').remove();
  }
}
