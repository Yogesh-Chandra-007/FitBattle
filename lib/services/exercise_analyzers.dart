/// Exercise-level kinematics after landmark detection.  Keeping this layer
/// free of ML Kit types makes the rep rules deterministic and testable.
enum RepPhase { unknown, top, down, bottom, up }

class ExerciseKinematics {
  /// Smoothed primary joint angle: elbow for push-ups, knee for squats.
  final double jointAngle;

  /// Normalised range/depth signal (0 = extended/standing, 1 = deepest).
  final double depth;

  /// Landmark-derived form gate. A repetition is never counted without it.
  final bool bodyAligned;

  const ExerciseKinematics({
    required this.jointAngle,
    required this.depth,
    required this.bodyAligned,
  });
}

class RepAnalysis {
  final int repCount;
  final RepPhase phase;
  final double smoothedAngle;
  final bool countedRep;
  final String message;

  const RepAnalysis({
    required this.repCount,
    required this.phase,
    required this.smoothedAngle,
    required this.countedRep,
    required this.message,
  });
}

abstract class ExerciseAnalyzer {
  int get repCount;
  RepPhase get phase;
  RepAnalysis process(ExerciseKinematics input);
  void reset();
}

/// Shared TOP -> DOWN -> BOTTOM -> UP -> TOP state machine.
///
/// A phase needs [minimumStableFrames] consecutive smoothed observations. This
/// removes single-frame landmark spikes without using elapsed time or frame
/// count as a proxy for a rep.
abstract class AngleRepAnalyzer implements ExerciseAnalyzer {
  final double smoothing;
  final int minimumStableFrames;

  double? _smoothedAngle;
  int _repCount = 0;
  RepPhase _phase = RepPhase.unknown;
  RepPhase? _candidate;
  int _candidateFrames = 0;

  AngleRepAnalyzer({this.smoothing = 0.28, this.minimumStableFrames = 2});

  @override
  int get repCount => _repCount;

  @override
  RepPhase get phase => _phase;

  bool isTop(double angle, double depth);
  bool isDown(double angle, double depth);
  bool isBottom(double angle, double depth);
  bool isUp(double angle, double depth);
  String cueFor(RepPhase phase, {required bool aligned});

  @override
  RepAnalysis process(ExerciseKinematics input) {
    _smoothedAngle = _smoothedAngle == null
        ? input.jointAngle
        : _smoothedAngle! + smoothing * (input.jointAngle - _smoothedAngle!);
    final angle = _smoothedAngle!;

    // Don't block phase progression on transient alignment drops; only gate
    // REP COUNT emission on alignment at the rep-completing transition.
    final aligned = input.bodyAligned;

    var counted = false;
    final phaseBeforeFrame = _phase;
    switch (phaseBeforeFrame) {
      case RepPhase.unknown:
        if (_stable(RepPhase.top, isTop(angle, input.depth))) {
          _phase = RepPhase.top;
        }
        break;
      case RepPhase.top:
        if (_stable(RepPhase.down, isDown(angle, input.depth))) {
          _phase = RepPhase.down;
        }
        break;
      case RepPhase.down:
        if (_stable(RepPhase.bottom, isBottom(angle, input.depth))) {
          _phase = RepPhase.bottom;
        }
        break;
      case RepPhase.bottom:
        if (_stable(RepPhase.up, isUp(angle, input.depth))) {
          _phase = RepPhase.up;
        }
        break;
      case RepPhase.up:
        if (_stable(RepPhase.top, isTop(angle, input.depth))) {
          _phase = RepPhase.top;
          if (aligned) {
            _repCount++;
            counted = true;
          }
        }
        break;
    }

    return _result(angle, counted, cueFor(_phase, aligned: aligned));
  }

  bool _stable(RepPhase candidate, bool matches) {
    if (!matches) {
      _clearCandidate();
      return false;
    }
    if (_candidate == candidate) {
      _candidateFrames++;
    } else {
      _candidate = candidate;
      _candidateFrames = 1;
    }
    if (_candidateFrames < minimumStableFrames) return false;
    _clearCandidate();
    return true;
  }

  void _clearCandidate() {
    _candidate = null;
    _candidateFrames = 0;
  }

  RepAnalysis _result(double angle, bool counted, String message) => RepAnalysis(
        repCount: _repCount,
        phase: _phase,
        smoothedAngle: angle,
        countedRep: counted,
        message: message,
      );

  @override
  void reset() {
    _smoothedAngle = null;
    _repCount = 0;
    _phase = RepPhase.unknown;
    _clearCandidate();
  }
}

class PushUpAnalyzer extends AngleRepAnalyzer {
  PushUpAnalyzer({super.smoothing, super.minimumStableFrames});

  @override
  bool isTop(double angle, double depth) => angle >= 160 && depth <= 0.22;

  @override
  bool isDown(double angle, double depth) => angle <= 145 && depth >= 0.20;

  @override
  bool isBottom(double angle, double depth) => angle <= 100 && depth >= 0.42;

  @override
  bool isUp(double angle, double depth) => angle >= 115 && depth <= 0.38;

  @override
  String cueFor(RepPhase phase, {required bool aligned}) {
    if (!aligned) return 'Keep shoulders, hips and ankles aligned';
    return switch (phase) {
      RepPhase.unknown => 'Start at the top of a push-up',
      RepPhase.top => 'Lower your chest with control',
      RepPhase.down => 'Keep lowering for full depth',
      RepPhase.bottom => 'Drive back up',
      RepPhase.up => 'Fully extend your arms',
    };
  }
}

class SquatAnalyzer extends AngleRepAnalyzer {
  SquatAnalyzer({super.smoothing, super.minimumStableFrames});

  @override
  bool isTop(double angle, double depth) => angle >= 165 && depth <= 0.28;

  @override
  bool isDown(double angle, double depth) => angle <= 150 && depth >= 0.18;

  @override
  bool isBottom(double angle, double depth) => angle <= 105 && depth >= 0.45;

  @override
  bool isUp(double angle, double depth) => angle >= 125 && depth <= 0.62;

  @override
  String cueFor(RepPhase phase, {required bool aligned}) {
    if (!aligned) return 'Keep knees tracking over your feet';
    return switch (phase) {
      RepPhase.unknown => 'Stand tall to arm the rep counter',
      RepPhase.top => 'Sit down into your squat',
      RepPhase.down => 'Reach parallel depth',
      RepPhase.bottom => 'Drive through your feet',
      RepPhase.up => 'Stand fully tall',
    };
  }
}
