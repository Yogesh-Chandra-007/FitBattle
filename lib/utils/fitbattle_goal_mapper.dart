class FitBattleGoalMapper {
  /// Supported battle durations in seconds: 30s, 1min (60s), 90s
  static const List<int> availableDurations = [30, 60, 90];
  static const int defaultDuration = 60;

  /// Returns a human-readable label for the duration
  static String durationLabel(int durationSeconds) {
    if (durationSeconds == 30) return '30s';
    if (durationSeconds == 60) return '1 min';
    if (durationSeconds == 90) return '90s';
    return '${durationSeconds}s';
  }

  static String difficultyFromDurationSeconds(int durationSeconds) {
    if (durationSeconds <= 30) return 'Easy';
    if (durationSeconds <= 60) return 'Medium';
    return 'Hard';
  }

  static String bodyFocusFromExercise(String exerciseId) {
    switch (exerciseId) {
      case 'pushups':
        return 'Chest, Arms, Core';
      case 'squats':
        return 'Legs, Core';
      default:
        return 'Full Body';
    }
  }
}
