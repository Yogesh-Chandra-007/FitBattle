enum BattleStatus {
  waiting,
  matched,
  countdown,
  active,
  finished,
  result,
  closed;

  static BattleStatus fromValue(Object? value) {
    final raw = value?.toString().toLowerCase();
    return BattleStatus.values.firstWhere(
      (status) => status.name == raw,
      // Existing rooms created before the state machine used `finished`.
      orElse: () => BattleStatus.waiting,
    );
  }
}

class BattleRoom {
  final String id;
  final String hostId;
  final String hostUsername;
  final String? guestId;
  final String? guestUsername;
  final String exercise;
  final int durationSeconds;
  final BattleStatus battleStatus;
  final int hostReps;
  final int guestReps;

  /// Epoch milliseconds when COUNTDOWN ends and the battle becomes ACTIVE.
  final int startTime;
  final int endTime;
  final String? winnerId;
  final String? finishReason;
  final bool isMatchmaking;
  final Map<String, bool> connectedPlayers;

  BattleRoom({
    required this.id,
    required this.hostId,
    required this.hostUsername,
    this.guestId,
    this.guestUsername,
    required this.exercise,
    required this.durationSeconds,
    required this.battleStatus,
    required this.hostReps,
    required this.guestReps,
    required this.startTime,
    required this.endTime,
    this.winnerId,
    this.finishReason,
    this.isMatchmaking = false,
    this.connectedPlayers = const {},
  });

  String get status => battleStatus.name;
  bool get isTerminal =>
      battleStatus == BattleStatus.result || battleStatus == BattleStatus.closed;

  bool? isPlayerConnected(String userId) => connectedPlayers[userId];

  factory BattleRoom.fromMap(String id, Map<dynamic, dynamic> map) {
    final presence = map['presence'];
    final connectedPlayers = <String, bool>{};
    if (presence is Map) {
      for (final entry in presence.entries) {
        final value = entry.value;
        if (value is Map && value['connected'] is bool) {
          connectedPlayers[entry.key.toString()] = value['connected'] as bool;
        }
      }
    }
    return BattleRoom(
      id: id,
      hostId: map['hostId']?.toString() ?? '',
      hostUsername: map['hostUsername']?.toString() ?? '',
      guestId: map['guestId']?.toString(),
      guestUsername: map['guestUsername']?.toString(),
      exercise: map['exercise']?.toString() ?? 'pushups',
      durationSeconds: _int(map['durationSeconds'], 60),
      battleStatus: BattleStatus.fromValue(map['status']),
      hostReps: _int(map['hostReps']),
      guestReps: _int(map['guestReps']),
      startTime: _int(map['startTime']),
      endTime: _int(map['endTime']),
      winnerId: map['winnerId']?.toString(),
      finishReason: map['finishReason']?.toString(),
      isMatchmaking: map['isMatchmaking'] == true,
      connectedPlayers: connectedPlayers,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'hostUsername': hostUsername,
      'guestId': guestId,
      'guestUsername': guestUsername,
      'exercise': exercise,
      'durationSeconds': durationSeconds,
      'status': status,
      'hostReps': hostReps,
      'guestReps': guestReps,
      'startTime': startTime,
      'endTime': endTime,
      'winnerId': winnerId,
      'finishReason': finishReason,
      'isMatchmaking': isMatchmaking,
      'presence': {
        for (final entry in connectedPlayers.entries)
          entry.key: {'connected': entry.value},
      },
    };
  }

  static int _int(Object? value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
