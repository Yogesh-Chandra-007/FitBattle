import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/battle_room.dart';

/// Firebase is the source of truth for every battle transition and score.
/// All transitions below use transactions so two clients can safely make the
/// same transition without a host-only race.
class BattleService extends ChangeNotifier {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final _uuid = const Uuid();

  BattleRoom? _currentRoom;
  BattleRoom? get currentRoom => _currentRoom;

  Stream<BattleRoom?> watchRoom(String roomId) {
    return _roomRef(roomId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value is! Map) return null;
      final room = BattleRoom.fromMap(
        roomId,
        event.snapshot.value as Map<dynamic, dynamic>,
      );
      _currentRoom = room;
      notifyListeners();
      return room;
    });
  }

  /// Used to re-arm presence after a transient Firebase reconnect.
  Stream<bool> get connectionChanges => FirebaseDatabase.instance
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);

  Future<String> createRoom(String exercise, int durationSeconds) =>
      _createRoom(exercise, durationSeconds, isMatchmaking: false);

  Future<String> _createRoom(
    String exercise,
    int durationSeconds, {
    required bool isMatchmaking,
  }) async {
    final user = _requireUser();
    final roomId = _uuid.v4().substring(0, 6).toUpperCase();
    await _roomRef(roomId).set({
      'hostId': user.uid,
      'hostUsername': user.displayName ?? 'Player 1',
      'guestId': null,
      'guestUsername': null,
      'exercise': exercise,
      'durationSeconds': durationSeconds,
      'status': BattleStatus.waiting.name,
      'hostReps': 0,
      'guestReps': 0,
      'startTime': 0,
      'endTime': 0,
      'winnerId': null,
      'finishReason': null,
      'isMatchmaking': isMatchmaking,
      'presence': {
        user.uid: {'connected': true, 'lastSeen': ServerValue.timestamp},
      },
      'createdAt': ServerValue.timestamp,
    });
    await _armPresence(roomId, user.uid);
    final snapshot = await _roomRef(roomId).get();
    if (snapshot.value is Map) {
      _currentRoom = BattleRoom.fromMap(roomId, snapshot.value as Map);
    }
    return roomId;
  }

  /// Atomically claims an open room and moves it from WAITING to MATCHED.
  Future<bool> joinRoom(String roomId) async {
    final user = _requireUser();
    final normalized = roomId.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalized)) return false;

    var joined = false;
    final result = await _roomRef(normalized).runTransaction((current) {
      // Firebase invokes the transaction handler locally first. If the node
      // is not cached locally, `current` is null. Returning success(null)
      // instructs the SDK to fetch the server data and retry the transaction
      // with authoritative server state rather than aborting prematurely.
      if (current == null) {
        return Transaction.success(current);
      }
      final room = _roomMap(current);
      if (room == null ||
          room['status'] != BattleStatus.waiting.name ||
          room['guestId'] != null ||
          room['hostId'] == user.uid) {
        return Transaction.abort();
      }
      room['guestId'] = user.uid;
      room['guestUsername'] = user.displayName ?? 'Player 2';
      room['status'] = BattleStatus.matched.name;
      room['presence'] = _presenceWith(room, user.uid, true);
      joined = true;
      return Transaction.success(room);
    });

    if (result.committed && joined) {
      await _armPresence(normalized, user.uid);
      final snapValue = result.snapshot.value;
      if (snapValue is Map) {
        _currentRoom = BattleRoom.fromMap(normalized, snapValue);
      } else {
        final snapshot = await _roomRef(normalized).get();
        if (snapshot.value is Map) {
          _currentRoom = BattleRoom.fromMap(normalized, snapshot.value as Map);
        }
      }
      return true;
    }
    return false;
  }

  /// MATCHED -> COUNTDOWN. This is intentionally not host-only; the
  /// transaction makes duplicate taps harmless while keeping one start time.
  Future<void> startBattle(String roomId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const countdownMilliseconds = 3000;
    await _roomRef(roomId).runTransaction((current) {
      final room = _roomMap(current);
      if (room == null ||
          room['status'] != BattleStatus.matched.name ||
          room['guestId'] == null) {
        return Transaction.abort();
      }
      final startTime = now + countdownMilliseconds;
      final duration = _asInt(room['durationSeconds'], 60) * 1000;
      room['status'] = BattleStatus.countdown.name;
      room['startTime'] = startTime;
      room['endTime'] = startTime + duration;
      room['hostReps'] = 0;
      room['guestReps'] = 0;
      room['winnerId'] = null;
      room['finishReason'] = null;
      return Transaction.success(room);
    });
  }

  /// COUNTDOWN -> ACTIVE. Every connected player calls this when the shared
  /// timestamp is reached, and only the first transaction commits.
  Future<void> activateBattle(String roomId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _roomRef(roomId).runTransaction((current) {
      final room = _roomMap(current);
      if (room == null || room['status'] != BattleStatus.countdown.name) {
        return Transaction.abort();
      }
      if (_asInt(room['startTime']) > now) return Transaction.abort();
      room['status'] = BattleStatus.active.name;
      room['activatedAt'] = ServerValue.timestamp;
      return Transaction.success(room);
    });
  }

  /// The device may only increase its own score while the shared state is
  /// ACTIVE. A transaction prevents delayed stream writes from lowering it.
  Future<void> updateReps(String roomId, bool isHost, int reps) async {
    final user = _requireUser();
    await _roomRef(roomId).runTransaction((current) {
      final room = _roomMap(current);
      if (room == null || room['status'] != BattleStatus.active.name) {
        return Transaction.abort();
      }
      final field = room['hostId'] == user.uid
          ? 'hostReps'
          : room['guestId'] == user.uid
              ? 'guestReps'
              : null;
      if (field == null) return Transaction.abort();
      final safeReps = reps < 0 ? 0 : reps;
      final existingReps = _asInt(room[field]);
      room[field] = existingReps > safeReps ? existingReps : safeReps;
      // `isHost` is retained in the public API for existing callers, but the
      // authenticated room role above is authoritative.
      return Transaction.success(room);
    });
  }

  /// ACTIVE -> FINISHED. Both players call this at [BattleRoom.endTime]. The
  /// winner is calculated from the scores already stored in Firebase.
  Future<void> finishBattle(
    String roomId, {
    String? forfeitUserId,
    String reason = 'time',
  }) async {
    final caller = _requireUser();
    await _roomRef(roomId).runTransaction((current) {
      final room = _roomMap(current);
      if (room == null || room['status'] != BattleStatus.active.name) {
        return Transaction.abort();
      }
      if (!_isPlayer(room, caller.uid)) return Transaction.abort();
      _finishRoom(room, forfeitUserId: forfeitUserId, reason: reason);
      return Transaction.success(room);
    });
  }

  /// FINISHED -> RESULT. It is safe for every listener to call this: only one
  /// transaction commits and both screens then navigate from the same record.
  Future<void> publishResult(String roomId) async {
    await _roomRef(roomId).runTransaction((current) {
      final room = _roomMap(current);
      if (room == null || room['status'] != BattleStatus.finished.name) {
        return Transaction.abort();
      }
      room['status'] = BattleStatus.result.name;
      room['resultAt'] = ServerValue.timestamp;
      return Transaction.success(room);
    });
  }

  /// Firebase onDisconnect writes this presence record even after a process
  /// crash. The opponent waits briefly before calling this forfeit transaction.
  Future<void> forfeitDisconnectedPlayer(
    String roomId,
    String disconnectedUserId,
  ) async {
    final caller = _requireUser();
    await _roomRef(roomId).runTransaction((current) {
      final room = _roomMap(current);
      if (room == null || room['status'] != BattleStatus.active.name) {
        return Transaction.abort();
      }
      if (!_isPlayer(room, caller.uid) || !_isPlayer(room, disconnectedUserId)) {
        return Transaction.abort();
      }
      final presence = room['presence'];
      final disconnected = presence is Map &&
          presence[disconnectedUserId] is Map &&
          (presence[disconnectedUserId] as Map)['connected'] == false;
      if (!disconnected) return Transaction.abort();
      _finishRoom(
        room,
        forfeitUserId: disconnectedUserId,
        reason: 'disconnect',
      );
      return Transaction.success(room);
    });
  }

  /// Records presence and queues the equivalent server-side disconnect write.
  Future<void> markPlayerConnected(String roomId) async {
    final user = _requireUser();
    await _roomRef(roomId).child('presence').child(user.uid).update({
      'connected': true,
      'lastSeen': ServerValue.timestamp,
    });
    await _armPresence(roomId, user.uid);
  }

  Future<void> _armPresence(String roomId, String uid) =>
      _roomRef(roomId).child('presence').child(uid).onDisconnect().update({
        'connected': false,
        'lastSeen': ServerValue.timestamp,
      });

  /// Used by a player intentionally leaving before the result is published.
  Future<void> leaveRoom(String roomId, bool isHost) async {
    final user = _requireUser();
    var shouldPublish = false;
    await _roomRef(roomId).runTransaction((current) {
      final room = _roomMap(current);
      if (room == null || !_isPlayer(room, user.uid)) {
        return Transaction.abort();
      }
      final status = BattleStatus.fromValue(room['status']);
      if (status == BattleStatus.active) {
        _finishRoom(room, forfeitUserId: user.uid, reason: 'left');
        shouldPublish = true;
      } else if (status == BattleStatus.waiting) {
        room['status'] = BattleStatus.closed.name;
        room['finishReason'] = 'cancelled';
      } else if (status == BattleStatus.matched ||
          status == BattleStatus.countdown) {
        if (room['guestId'] == user.uid) {
          room['guestId'] = null;
          room['guestUsername'] = null;
          room['status'] = BattleStatus.waiting.name;
          final presence = _presenceWith(room, user.uid, false);
          presence.remove(user.uid);
          room['presence'] = presence;
        } else {
          _finishRoom(room, forfeitUserId: user.uid, reason: 'left');
          shouldPublish = true;
        }
      }
      return Transaction.success(room);
    });
    await _roomRef(roomId).child('presence').child(user.uid).onDisconnect().cancel();
    if (shouldPublish) await publishResult(roomId);
  }

  /// RESULT -> CLOSED. Retaining the terminal record prevents old delayed
  /// writes from becoming a new battle and lets both result screens finish.
  Future<void> closeRoom(String roomId) async {
    final user = _requireUser();
    await _roomRef(roomId).runTransaction((current) {
      final room = _roomMap(current);
      if (room == null ||
          room['status'] != BattleStatus.result.name ||
          !_isPlayer(room, user.uid)) {
        return Transaction.abort();
      }
      room['status'] = BattleStatus.closed.name;
      room['closedAt'] = ServerValue.timestamp;
      return Transaction.success(room);
    });
  }

  /// Allows ResultScreen to update profile stats once even if navigation or a
  /// duplicated Firebase event rebuilds the screen.
  Future<bool> claimResultRecording(String roomId) async {
    final user = _requireUser();
    var claimed = false;
    await _roomRef(roomId).runTransaction((current) {
      final room = _roomMap(current);
      if (room == null ||
          !_isPlayer(room, user.uid) ||
          (room['status'] != BattleStatus.result.name &&
              room['status'] != BattleStatus.closed.name)) {
        return Transaction.abort();
      }
      final recorded = Map<dynamic, dynamic>.from(
        room['resultRecordedBy'] is Map ? room['resultRecordedBy'] as Map : {},
      );
      if (recorded[user.uid] == true) return Transaction.abort();
      recorded[user.uid] = true;
      room['resultRecordedBy'] = recorded;
      claimed = true;
      return Transaction.success(room);
    });
    return claimed;
  }

  // Matchmaking claims are routed through the same transaction as code joins.
  Future<String> findOrCreateMatchmakingRoom(
    String exercise,
    int durationSeconds,
  ) async {
    final user = _requireUser();
    final snap = await _db
        .child('rooms')
        .orderByChild('status')
        .equalTo(BattleStatus.waiting.name)
        .get();
    if (snap.value is Map) {
      for (final entry in (snap.value as Map).entries) {
        if (entry.value is! Map) continue;
        final room = BattleRoom.fromMap(entry.key.toString(), entry.value as Map);
        if (room.exercise == exercise &&
            room.isMatchmaking &&
            room.hostId != user.uid &&
            room.guestId == null &&
            await joinRoom(room.id)) {
          return room.id;
        }
      }
    }
    return _createRoom(exercise, durationSeconds, isMatchmaking: true);
  }

  Stream<List<BattleRoom>> watchOpenRooms() {
    return _db
        .child('rooms')
        .orderByChild('status')
        .equalTo(BattleStatus.waiting.name)
        .onValue
        .map((event) {
      if (event.snapshot.value is! Map) return <BattleRoom>[];
      return (event.snapshot.value as Map).entries
          .where((entry) => entry.value is Map)
          .map((entry) => BattleRoom.fromMap(entry.key.toString(), entry.value as Map))
          .toList();
    });
  }

  DatabaseReference _roomRef(String roomId) => _db.child('rooms').child(roomId);

  User _requireUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('You must be signed in to battle.');
    return user;
  }

  Map<dynamic, dynamic>? _roomMap(Object? value) {
    return value is Map ? Map<dynamic, dynamic>.from(value) : null;
  }

  Map<dynamic, dynamic> _presenceWith(
    Map<dynamic, dynamic> room,
    String uid,
    bool connected,
  ) {
    final presence = Map<dynamic, dynamic>.from(
      room['presence'] is Map ? room['presence'] as Map : {},
    );
    presence[uid] = {
      'connected': connected,
      'lastSeen': ServerValue.timestamp,
    };
    return presence;
  }

  bool _isPlayer(Map<dynamic, dynamic> room, String uid) =>
      room['hostId'] == uid || room['guestId'] == uid;

  int _asInt(Object? value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _finishRoom(
    Map<dynamic, dynamic> room, {
    required String? forfeitUserId,
    required String reason,
  }) {
    final hostId = room['hostId']?.toString() ?? '';
    final guestId = room['guestId']?.toString();
    String? winnerId;
    if (forfeitUserId == hostId) {
      winnerId = guestId;
    } else if (forfeitUserId == guestId) {
      winnerId = hostId;
    } else {
      final hostReps = _asInt(room['hostReps']);
      final guestReps = _asInt(room['guestReps']);
      winnerId = hostReps == guestReps
          ? null
          : hostReps > guestReps
              ? hostId
              : guestId;
    }
    room['status'] = BattleStatus.finished.name;
    room['winnerId'] = winnerId;
    room['finishReason'] = reason;
    room['finishedAt'] = ServerValue.timestamp;
  }
}
