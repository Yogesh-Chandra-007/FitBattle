import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_battle/services/exercise_analyzers.dart';

ExerciseKinematics sample(
  double angle,
  double depth, {
  bool aligned = true,
}) =>
    ExerciseKinematics(
      jointAngle: angle,
      depth: depth,
      bodyAligned: aligned,
    );

void main() {
  group('PushUpAnalyzer', () {
    test('counts exactly one complete top-down-bottom-up-top repetition', () {
      final analyzer = PushUpAnalyzer(smoothing: 1, minimumStableFrames: 1);

      expect(analyzer.process(sample(170, 0.05)).phase, RepPhase.top);
      expect(analyzer.process(sample(140, 0.25)).phase, RepPhase.down);
      expect(analyzer.process(sample(90, 0.55)).phase, RepPhase.bottom);
      expect(analyzer.process(sample(130, 0.28)).phase, RepPhase.up);
      final complete = analyzer.process(sample(170, 0.05));

      expect(complete.countedRep, isTrue);
      expect(complete.repCount, 1);
      expect(analyzer.process(sample(170, 0.05)).repCount, 1);
    });

    test('does not count a shallow or misaligned push-up', () {
      final shallow = PushUpAnalyzer(smoothing: 1, minimumStableFrames: 1);
      shallow.process(sample(170, 0.05));
      shallow.process(sample(135, 0.25));
      shallow.process(sample(130, 0.28));
      expect(shallow.process(sample(170, 0.05)).repCount, 0);

      final badForm = PushUpAnalyzer(smoothing: 1, minimumStableFrames: 1);
      badForm.process(sample(170, 0.05));
      badForm.process(sample(140, 0.25));
      badForm.process(sample(90, 0.55, aligned: false));
      expect(badForm.repCount, 0);
    });
  });

  group('SquatAnalyzer', () {
    test('counts exactly one full-depth squat', () {
      final analyzer = SquatAnalyzer(smoothing: 1, minimumStableFrames: 1);

      analyzer.process(sample(175, 0.05));
      analyzer.process(sample(145, 0.25));
      analyzer.process(sample(95, 0.60));
      analyzer.process(sample(135, 0.40));
      final complete = analyzer.process(sample(175, 0.05));

      expect(complete.countedRep, isTrue);
      expect(complete.repCount, 1);
    });

    test('does not count a partial squat', () {
      final analyzer = SquatAnalyzer(smoothing: 1, minimumStableFrames: 1);
      analyzer.process(sample(175, 0.05));
      analyzer.process(sample(125, 0.32));
      analyzer.process(sample(175, 0.05));

      expect(analyzer.repCount, 0);
      expect(analyzer.phase, isNot(RepPhase.up));
    });
  });
}
