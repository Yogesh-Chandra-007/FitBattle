import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'exercise_analyzers.dart';

class PoseVisibility {
  final bool isVisible;
  final String message;
  const PoseVisibility({required this.isVisible, required this.message});
}

/// The UI receives the raw pose for the skeleton, plus the smoothed joint
/// angle and state-machine result used for scoring.
class PoseResult {
  final int repCount;
  final PoseVisibility visibility;
  final Pose? pose;
  final double? angle;
  final double? depth;
  final RepPhase phase;
  final bool countedRep;

  const PoseResult({
    required this.repCount,
    required this.visibility,
    this.pose,
    this.angle,
    this.depth,
    this.phase = RepPhase.unknown,
    this.countedRep = false,
  });
}

/// ML Kit's streaming pose detector is backed by Google's BlazePose model.
/// This class owns only the camera-frame -> landmarks -> kinematics bridge;
/// deterministic rep logic lives in [exercise_analyzers.dart].
class PoseDetectorService {
  static const double _likelihoodThreshold = 0.55;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  late ExerciseAnalyzer _analyzer;
  String _currentExercise = 'pushups';

  PoseDetectorService() {
    _analyzer = PushUpAnalyzer();
  }

  int get repCount => _analyzer.repCount;

  void setExercise(String exercise) {
    _currentExercise = exercise;
    _analyzer = switch (exercise) {
      'pushups' => PushUpAnalyzer(minimumStableFrames: 1),
      'squats' => SquatAnalyzer(minimumStableFrames: 1),

      // Keep the existing exercise selectable. Its rep counter is deliberately
      // not enabled until it gets an exercise-specific analyzer.
      _ => _UnsupportedAnalyzer(),
    };
  }

  void resetCount() => _analyzer.reset();

  Future<PoseResult> processImage(InputImage inputImage) async {
    final poses = await _poseDetector.processImage(inputImage);
    if (poses.isEmpty) {
      return PoseResult(
        repCount: _analyzer.repCount,
        visibility: const PoseVisibility(
          isVisible: false,
          message: 'No person detected',
        ),
        phase: _analyzer.phase,
      );
    }

    // ML Kit returns a single primary body in this use case. Retain that exact
    // pose so development skeletons represent the landmarks being scored.
    final pose = poses.first;
    final kinematics = switch (_currentExercise) {
      'pushups' => _pushUpKinematics(pose),
      'squats' => _squatKinematics(pose),
      _ => null,
    };

    if (kinematics == null) {
      return PoseResult(
        repCount: _analyzer.repCount,
        visibility: PoseVisibility(
          isVisible: false,
          message: _currentExercise == 'pushups'
              ? 'Show one full arm, hip and ankle'
              : _currentExercise == 'squats'
                  ? 'Show hips, knees and ankles'
                  : 'Exercise tracking is unavailable',
        ),
        pose: pose,
        phase: _analyzer.phase,
      );
    }

    final analysis = _analyzer.process(kinematics);
    return PoseResult(
      repCount: analysis.repCount,
      visibility: PoseVisibility(
        isVisible: true,
        message: analysis.message,
      ),
      pose: pose,
      angle: analysis.smoothedAngle,
      phase: analysis.phase,
      countedRep: analysis.countedRep,
    );
  }

  ExerciseKinematics? _pushUpKinematics(Pose pose) {
    final sides = <_PushUpSide>[];
    for (final side in [_Side.left, _Side.right]) {
      final shoulder = _landmark(pose, side.shoulder);
      final elbow = _landmark(pose, side.elbow);
      final wrist = _landmark(pose, side.wrist);
      final hip = _landmark(pose, side.hip);
      final ankle = _landmark(pose, side.ankle);
      if ([shoulder, elbow, wrist, hip, ankle].any((point) => point == null)) {
        continue;
      }
      final bodyAngle = _angle(shoulder!, hip!, ankle!);
      sides.add(_PushUpSide(
        elbowAngle: _angle(shoulder, elbow!, wrist!),
        bodyAngle: bodyAngle,
      ));
    }
    if (sides.isEmpty) return null;

    final elbowAngle = _average(sides.map((side) => side.elbowAngle));
    final bodyAngle = _average(sides.map((side) => side.bodyAngle));
    return ExerciseKinematics(
      jointAngle: elbowAngle,
      // Bent elbows are the range-of-motion/depth signal. The required
      // bottom threshold is still independently checked by PushUpAnalyzer.
      depth: (1 - elbowAngle / 180).clamp(0.0, 1.0),
      bodyAligned: bodyAngle >= 150,
    );
  }

  ExerciseKinematics? _squatKinematics(Pose pose) {
    final sides = <_SquatSide>[];
    for (final side in [_Side.left, _Side.right]) {
      final shoulder = _landmark(pose, side.shoulder);
      final hip = _landmark(pose, side.hip);
      final knee = _landmark(pose, side.knee);
      final ankle = _landmark(pose, side.ankle);
      if ([shoulder, hip, knee, ankle].any((point) => point == null)) {
        continue;
      }
      final upperLeg = _distance(hip!, knee!);
      final lowerLeg = _distance(knee, ankle!);
      final torso = _distance(shoulder!, hip);
      if (upperLeg == 0 || lowerLeg == 0 || torso == 0) continue;

      // The hip approaching knee height is an image-scale independent depth
      // cue. It supplements knee ROM so shallow knee bends do not score.
      final verticalHipToKnee = (knee.y - hip.y).abs();
      final depth = (1 - (verticalHipToKnee / (upperLeg + lowerLeg)) * 2)
          .clamp(0.0, 1.0);
      final torsoLean = (shoulder.x - hip.x).abs() / torso;
      final kneeTravel = (knee.x - ankle.x).abs() / lowerLeg;
      sides.add(_SquatSide(
        kneeAngle: _angle(hip, knee, ankle),
        depth: depth,
        aligned: torsoLean <= 0.78 && kneeTravel <= 0.95,
      ));
    }
    if (sides.isEmpty) return null;

    return ExerciseKinematics(
      jointAngle: _average(sides.map((side) => side.kneeAngle)),
      depth: _average(sides.map((side) => side.depth)),
      bodyAligned: sides.every((side) => side.aligned),
    );
  }

  PoseLandmark? _landmark(Pose pose, PoseLandmarkType type) {
    final point = pose.landmarks[type];
    return point != null && point.likelihood >= _likelihoodThreshold
        ? point
        : null;
  }

  double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians = (math.atan2(c.y - b.y, c.x - b.x) -
            math.atan2(a.y - b.y, a.x - b.x))
        .abs();
    var angle = radians * 180 / math.pi;
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  double _distance(PoseLandmark a, PoseLandmark b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  double _average(Iterable<double> values) {
    final list = values.toList();
    return list.reduce((sum, value) => sum + value) / list.length;
  }

  void dispose() {
    _poseDetector.close();
  }
}

enum _Side { left, right }

extension on _Side {
  PoseLandmarkType get shoulder => this == _Side.left
      ? PoseLandmarkType.leftShoulder
      : PoseLandmarkType.rightShoulder;
  PoseLandmarkType get elbow => this == _Side.left
      ? PoseLandmarkType.leftElbow
      : PoseLandmarkType.rightElbow;
  PoseLandmarkType get wrist => this == _Side.left
      ? PoseLandmarkType.leftWrist
      : PoseLandmarkType.rightWrist;
  PoseLandmarkType get hip =>
      this == _Side.left ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip;
  PoseLandmarkType get knee => this == _Side.left
      ? PoseLandmarkType.leftKnee
      : PoseLandmarkType.rightKnee;
  PoseLandmarkType get ankle => this == _Side.left
      ? PoseLandmarkType.leftAnkle
      : PoseLandmarkType.rightAnkle;
}

class _PushUpSide {
  final double elbowAngle;
  final double bodyAngle;
  const _PushUpSide({required this.elbowAngle, required this.bodyAngle});
}

class _SquatSide {
  final double kneeAngle;
  final double depth;
  final bool aligned;
  const _SquatSide({
    required this.kneeAngle,
    required this.depth,
    required this.aligned,
  });
}

class _UnsupportedAnalyzer implements ExerciseAnalyzer {
  @override
  int get repCount => 0;

  @override
  RepPhase get phase => RepPhase.unknown;

  @override
  RepAnalysis process(ExerciseKinematics input) => const RepAnalysis(
        repCount: 0,
        phase: RepPhase.unknown,
        smoothedAngle: 0,
        countedRep: false,
        message: 'Exercise tracking is unavailable',
      );

  @override
  void reset() {}
}
