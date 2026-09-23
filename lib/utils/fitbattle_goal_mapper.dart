class FitBattleGoalMapper {
  static const int targetReps50DurationSeconds = 60;
  static const int targetReps100DurationSeconds = 120;
  static const int targetReps200DurationSeconds = 180;

  /// Maps the existing backend "durationSeconds" field to a UI "target reps"
  /// number so we can match the mockup without changing Firebase schema.
  static int targetRepsFromDurationSeconds(int durationSeconds) {
    if (durationSeconds <= targetReps50DurationSeconds) return 50;
    if (durationSeconds <= targetReps100DurationSeconds) return 100;
    return 200;
  }

  /// Maps a UI target reps selection to the closest available duration.
  ///
  /// This is used only for snapping user input into one of the current
  /// supported backend durations.
  static int durationSecondsFromTargetReps(int targetReps) {
    if (targetReps <= 75) return targetReps50DurationSeconds;
    if (targetReps <= 150) return targetReps100DurationSeconds;
    return targetReps200DurationSeconds;
  }

  static String difficultyFromDurationSeconds(int durationSeconds) {
    final minutes = durationSeconds ~/ 60;
    if (minutes <= 1) return 'Easy';
    if (minutes == 2) return 'Medium';
    return 'Hard';
  }

  static String estimatedTimeFromDurationSeconds(int durationSeconds) {
    final minutes = durationSeconds ~/ 60;
    if (minutes <= 1) return '1–2 min';
    if (minutes == 2) return '2 min';
    return '1–3 min';
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
