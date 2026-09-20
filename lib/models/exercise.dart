class Exercise {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<String> keyPoints;

  const Exercise({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.keyPoints,
  });
}

const List<Exercise> availableExercises = [
  Exercise(
    id: 'pushups',
    name: 'Push-Ups',
    emoji: '💪',
    description: 'Classic chest exercise',
    keyPoints: ['Keep body straight', 'Full range of motion', 'Controlled pace'],
  ),
  Exercise(
    id: 'squats',
    name: 'Squats',
    emoji: '🦵',
    description: 'Lower body power',
    keyPoints: ['Feet shoulder-width', 'Knees over toes', 'Thighs parallel to floor'],
  ),
];
