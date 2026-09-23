import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/battle_room.dart';
import '../models/exercise.dart';
import '../services/auth_service.dart';
import '../services/battle_service.dart';
import '../services/pose_detector_service.dart';
import '../services/theme_service.dart';
import 'result_screen.dart';

class BattleScreen extends StatefulWidget {
  final String roomId;
  final Exercise exercise;
  final bool isHost;

  const BattleScreen({super.key, required this.roomId, required this.exercise, required this.isHost});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  static const bool _kCvDebug = false;

  CameraController? _cameraController;
  final PoseDetectorService _poseService = PoseDetectorService();
  bool _isDetecting = false;
  int _myReps = 0;
  int _opponentReps = 0;
  int _secondsLeft = 60;
  int _countdown = 3;
  bool _battleStarted = false;
  Timer? _countdownTimer;
  StreamSubscription? _roomSub;
  StreamSubscription? _connectionSub;
  Timer? _disconnectTimer;
  late BattleService _battleService;
  BattleRoom? _currentRoom;
  bool _resultNavigated = false;
  bool _activeInitialized = false;
  bool _finishRequested = false;
  bool _cleanedUp = false;

  // Pose visibility state
  bool _poseVisible = false;
  String _poseMessage = 'Position yourself in frame';
  bool _cameraInitialized = false;
  Pose? _currentPose;
  double? _currentAngle;
  Size? _lastFrameSize;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _poseService.setExercise(widget.exercise.id);
    _battleService = context.read<BattleService>();
    _initCamera();
    _listenToRoom();
    _markConnected();
    _connectionSub = _battleService.connectionChanges.listen((connected) {
      if (connected) _markConnected();
    });
  }

  Future<void> _markConnected() async {
    try {
      await _battleService.markPlayerConnected(widget.roomId);
    } catch (_) {
      // The room stream presents a recoverable error if the room no longer
      // exists; never freeze the camera while a reconnect is in progress.
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _poseMessage = 'No camera found');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        // The ML Kit bridge supports exactly these one-plane formats. The old
        // code hand-built NV21 bytes but labelled them as YUV, so pose frames
        // were invalid before they reached BlazePose.
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _cameraInitialized = true;
        _poseMessage = 'Position yourself in frame';
      });
      _cameraController!.startImageStream(_processFrame);
    } catch (e) {
      if (mounted) setState(() => _poseMessage = 'Camera error: $e');
    }
  }

  void _listenToRoom() {
    _roomSub = _battleService.watchRoom(widget.roomId).listen((room) {
      if (room == null || !mounted) return;
      final opponentReps = widget.isHost ? room.guestReps : room.hostReps;
      setState(() {
        _currentRoom = room;
        _opponentReps = opponentReps;
      });

      switch (room.battleStatus) {
        case BattleStatus.countdown:
          _beginSharedClock();
          break;
        case BattleStatus.active:
          _beginSharedClock();
          if (!_activeInitialized) {
            _activeInitialized = true;
            _poseService.resetCount();
            if (mounted) setState(() => _myReps = 0);
          }
          _watchOpponentDisconnect(room);
          break;
        case BattleStatus.finished:
          // Both clients advance the shared state. The transaction means a
          // duplicated completion event is harmless.
          _battleService.publishResult(widget.roomId);
          break;
        case BattleStatus.result:
          _goToSharedResult(room);
          break;
        case BattleStatus.closed:
          _goToSharedResult(room);
          break;
        case BattleStatus.waiting:
        case BattleStatus.matched:
          break;
      }
    });
  }

  bool get _roundActive =>
      _currentRoom?.battleStatus == BattleStatus.active && _secondsLeft > 0;

  void _beginSharedClock() {
    _countdownTimer ??= Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _tickSharedClock(),
    );
    _tickSharedClock();
  }

  void _tickSharedClock() {
    final room = _currentRoom;
    if (room == null || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (room.battleStatus == BattleStatus.countdown) {
      final milliseconds = room.startTime - now;
      final countdown = (milliseconds / 1000).ceil().clamp(0, 3);
      setState(() {
        _battleStarted = true;
        _countdown = countdown;
        _secondsLeft = room.durationSeconds;
      });
      if (milliseconds <= 0) _battleService.activateBattle(widget.roomId);
      return;
    }
    if (room.battleStatus != BattleStatus.active) return;
    final endTime = room.endTime == 0
        ? room.startTime + room.durationSeconds * 1000
        : room.endTime;
    final remaining = ((endTime - now) / 1000).ceil().clamp(0, room.durationSeconds);
    setState(() {
      _battleStarted = true;
      _countdown = 0;
      _secondsLeft = remaining;
    });
    if (remaining == 0 && !_finishRequested) {
      _finishRequested = true;
      // Each client calls this score-reading transaction at the shared end.
      _battleService.finishBattle(widget.roomId);
    }
  }

  void _watchOpponentDisconnect(BattleRoom room) {
    final opponentId = widget.isHost ? room.guestId : room.hostId;
    if (opponentId == null) return;
    if (room.isPlayerConnected(opponentId) == false) {
      _disconnectTimer ??= Timer(const Duration(seconds: 8), () {
        _battleService.forfeitDisconnectedPlayer(widget.roomId, opponentId);
      });
    } else {
      _disconnectTimer?.cancel();
      _disconnectTimer = null;
    }
  }

  void _goToSharedResult(BattleRoom room) {
    if (_resultNavigated || !mounted) return;
    _resultNavigated = true;
    _cleanup();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(room: room, isHost: widget.isHost)),
    );
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isDetecting) return;

    _isDetecting = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        return;
      }

      final result = await _poseService.processImage(inputImage);
      if (!mounted) return;

      // Track previous rep count before updating state
      final prevReps = _myReps;

      setState(() {
        _poseVisible = result.visibility.isVisible;
        _poseMessage = result.visibility.message;
        _myReps = _roundActive ? result.repCount : 0;
        _currentPose = result.pose;
        _currentAngle = result.angle;
        _lastFrameSize = Size(image.width.toDouble(), image.height.toDouble());
      });

      if (_kCvDebug && (result.countedRep || result.repCount != prevReps)) {
        debugPrint(
          '[CV] rep=${result.repCount} counted=${result.countedRep} phase=${result.phase} aligned=$_poseVisible angle=${result.angle?.toStringAsFixed(1)}',
        );
      }

      // Only update Firebase when rep count actually changes
      if (_roundActive && result.countedRep && result.repCount != prevReps) {
        await _battleService.updateReps(widget.roomId, widget.isHost, result.repCount);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _poseMessage = 'Pose frame could not be processed');
      }
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) return null;
    final camera = controller.description;
    final rotation = _inputRotation(camera, controller.value.deviceOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888) ||
        image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _inputRotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    const orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }
    final compensation = orientations[deviceOrientation];
    if (compensation == null) return null;
    final degrees = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + compensation) % 360
        : (camera.sensorOrientation - compensation + 360) % 360;
    return InputImageRotationValue.fromRawValue(degrees);
  }

  void _cleanup() {
    if (_cleanedUp) return;
    _cleanedUp = true;
    _countdownTimer?.cancel();
    _disconnectTimer?.cancel();
    _roomSub?.cancel();
    _connectionSub?.cancel();
    _cameraController?.stopImageStream().catchError((_) {});
    _poseService.dispose();
    WakelockPlus.disable();
  }

  @override
  void dispose() {
    _cleanup();
    _cameraController?.dispose();
    super.dispose();
  }

  String get _myName {
    final auth = context.read<AuthService>();
    return auth.currentUser?.displayName ?? 'You';
  }

  String get _opponentName {
    if (_currentRoom == null) return 'Opponent';
    return widget.isHost
        ? (_currentRoom!.guestUsername ?? 'Opponent')
        : _currentRoom!.hostUsername;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        await _battleService.leaveRoom(widget.roomId, widget.isHost);
        if (!mounted) return;
        nav.pop();
      },
      child: Scaffold(
      backgroundColor: CyberpunkColors.background,
      body: Stack(
        children: [
          // Full-screen camera feed
          if (_cameraController?.value.isInitialized == true)
            Positioned.fill(child: CameraPreview(_cameraController!)),

          // Pose skeleton overlay
          if (_cameraController?.value.isInitialized == true &&
              _currentPose != null &&
              _lastFrameSize != null)
            Positioned.fill(
              child: CustomPaint(
                painter: PosePainter(
                  pose: _currentPose!,
                  imageSize: _lastFrameSize!,
                  rotation: _inputRotation(
                    _cameraController!.description,
                    _cameraController!.value.deviceOrientation,
                  ),
                  lensDirection: _cameraController!.description.lensDirection,
                  currentAngle: _currentAngle,
                  exercise: widget.exercise.id,
                ),
              ),
            ),

          // Top HUD panel
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHudPanel(),
          ),

          // Camera guidance overlay - shown before battle starts
          if (!_battleStarted && _cameraInitialized)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.38),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 64,
                        color: _poseVisible ? CyberpunkColors.primary : Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _poseVisible ? 'READY!' : 'Position Your Body',
                        style: GoogleFonts.rajdhani(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _poseVisible ? CyberpunkColors.primary : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _poseVisible
                              ? 'Body detected! Waiting for battle to start...'
                              : 'Stand in frame with full body visible',
                          style: GoogleFonts.rajdhani(fontSize: 14, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Pose visibility indicator during battle
          if (_battleStarted && _countdown == 0)
            Positioned(
              bottom: 110,
              left: 16,
              right: 16,
              child: _buildVisibilityIndicator(),
            ),

          // Big rep number at bottom center
          Positioned(
            bottom: 56,
            left: 0,
            right: 0,
            child: Center(child: _buildBigRepNumber()),
          ),

          // Exercise label at very bottom
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                widget.exercise.name.toUpperCase(),
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CyberpunkColors.primary,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),

          // Countdown overlay
          if (_countdown > 0 && _battleStarted)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_countdown),
                    tween: Tween(begin: 1.4, end: 0.8),
                    duration: const Duration(milliseconds: 800),
                    builder: (_, scale, __) => Transform.scale(
                      scale: scale,
                      child: Text(
                        '$_countdown',
                        style: GoogleFonts.rajdhani(
                          fontSize: 140,
                          fontWeight: FontWeight.w900,
                          color: CyberpunkColors.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Loading camera state
          if (!_cameraInitialized)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: CyberpunkColors.secondary),
                      const SizedBox(height: 16),
                      Text(
                        'Initializing camera...',
                        style: GoogleFonts.rajdhani(fontSize: 18, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildVisibilityIndicator() {
    final color = _poseVisible ? CyberpunkColors.primary : CyberpunkColors.competitive;
    final icon = _poseVisible ? Icons.visibility : Icons.visibility_off;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            _poseMessage,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudPanel() {
    final total = _myReps + _opponentReps;
    final myFraction = total == 0 ? 0.5 : (_myReps / total).clamp(0.05, 0.95);

    return Container(
      decoration: BoxDecoration(
        color: CyberpunkColors.surface.withValues(alpha: 0.92),
        border: const Border(bottom: BorderSide(color: CyberpunkColors.border, width: 1)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'RANKED MATCH',
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CyberpunkColors.primary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildPlayerInfo(_myName, true)),
              Column(
                children: [
                  Text('TIME', style: GoogleFonts.rajdhani(fontSize: 11, color: Colors.white54, letterSpacing: 2)),
                  Text(
                    _formatTime(_secondsLeft),
                    style: GoogleFonts.rajdhani(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: _secondsLeft <= 10 ? CyberpunkColors.competitive : CyberpunkColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Expanded(child: _buildPlayerInfo(_opponentName, false)),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  '$_myReps',
                  style: GoogleFonts.rajdhani(fontSize: 26, fontWeight: FontWeight.w900, color: CyberpunkColors.primary),
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 14,
                    child: Stack(
                      children: [
                        Container(color: CyberpunkColors.competitive),
                        FractionallySizedBox(
                          widthFactor: myFraction,
                          child: Container(color: CyberpunkColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 40,
                child: Text(
                  '$_opponentReps',
                  style: GoogleFonts.rajdhani(fontSize: 26, fontWeight: FontWeight.w900, color: CyberpunkColors.competitive),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(String name, bool isMe) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: isMe
          ? [_buildAvatar(isMe), const SizedBox(width: 6), _buildName(name)]
          : [_buildName(name), const SizedBox(width: 6), _buildAvatar(isMe)],
    );
  }

  Widget _buildAvatar(bool isMe) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isMe ? CyberpunkColors.primary : CyberpunkColors.competitive, width: 2),
        color: CyberpunkColors.surface,
      ),
      child: Icon(Icons.person, color: isMe ? CyberpunkColors.primary : CyberpunkColors.competitive, size: 22),
    );
  }

  Widget _buildName(String name) {
    return Text(
      name,
      style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildBigRepNumber() {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_myReps),
      tween: Tween(begin: 1.3, end: 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Text(
        '$_myReps',
        style: GoogleFonts.rajdhani(
          fontSize: 120,
          fontWeight: FontWeight.w900,
          color: CyberpunkColors.primary,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 12, offset: const Offset(2, 2)),
          ],
        ),
      ),
    );
  }
}

/// Custom painter to draw pose skeleton overlay
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final InputImageRotation? rotation;
  final CameraLensDirection lensDirection;
  final double? currentAngle;
  final String exercise;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
    this.currentAngle,
    required this.exercise,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CyberpunkColors.secondary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = CyberpunkColors.secondary
      ..style = PaintingStyle.fill;

    final highlightPaint = Paint()
      ..color = CyberpunkColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Helper to convert pose coordinate to screen coordinate
    Offset? getOffset(PoseLandmark? landmark) {
      if (landmark == null) return null;

      final x = landmark.x;
      final y = landmark.y;
      // Mirror and rotate exactly as the InputImage did before ML Kit emitted
      // landmarks. This makes the development skeleton follow the preview.
      double translatedX;
      double translatedY;
      switch (rotation) {
        case InputImageRotation.rotation90deg:
          translatedX = x * size.width / imageSize.height;
          translatedY = y * size.height / imageSize.width;
          break;
        case InputImageRotation.rotation270deg:
          translatedX = size.width - x * size.width / imageSize.height;
          translatedY = size.height - y * size.height / imageSize.width;
          break;
        case InputImageRotation.rotation180deg:
          translatedX = size.width - x * size.width / imageSize.width;
          translatedY = size.height - y * size.height / imageSize.height;
          break;
        case InputImageRotation.rotation0deg:
        case null:
          translatedX = x * size.width / imageSize.width;
          translatedY = y * size.height / imageSize.height;
          break;
      }
      if (lensDirection == CameraLensDirection.front) {
        translatedX = size.width - translatedX;
      }
      return Offset(translatedX, translatedY);
    }

    // Draw connection between two landmarks
    void drawLine(PoseLandmarkType a, PoseLandmarkType b, {bool highlight = false}) {
      final landmarkA = pose.landmarks[a];
      final landmarkB = pose.landmarks[b];

      if (landmarkA == null || landmarkB == null) return;
      if (landmarkA.likelihood < 0.5 || landmarkB.likelihood < 0.5) return;

      final offsetA = getOffset(landmarkA);
      final offsetB = getOffset(landmarkB);

      if (offsetA != null && offsetB != null) {
        canvas.drawLine(offsetA, offsetB, highlight ? highlightPaint : paint);
      }
    }

    // Draw joint circle
    void drawJoint(PoseLandmarkType type, {bool highlight = false}) {
      final landmark = pose.landmarks[type];
      if (landmark == null || landmark.likelihood < 0.5) return;

      final offset = getOffset(landmark);
      if (offset != null) {
        canvas.drawCircle(
          offset,
          highlight ? 8 : 6,
          highlight ? (Paint()..color = CyberpunkColors.primary) : jointPaint,
        );
      }
    }

    // Draw body skeleton based on exercise
    if (exercise == 'pushups') {
      // Highlight arms for push-ups
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, highlight: true);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, highlight: true);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, highlight: true);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, highlight: true);

      // Body
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      // Joints
      drawJoint(PoseLandmarkType.leftShoulder, highlight: true);
      drawJoint(PoseLandmarkType.leftElbow, highlight: true);
      drawJoint(PoseLandmarkType.leftWrist, highlight: true);
      drawJoint(PoseLandmarkType.rightShoulder, highlight: true);
      drawJoint(PoseLandmarkType.rightElbow, highlight: true);
      drawJoint(PoseLandmarkType.rightWrist, highlight: true);
    } else if (exercise == 'squats') {
      // Highlight legs for squats
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, highlight: true);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, highlight: true);
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, highlight: true);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, highlight: true);

      // Body
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // Joints
      drawJoint(PoseLandmarkType.leftHip, highlight: true);
      drawJoint(PoseLandmarkType.leftKnee, highlight: true);
      drawJoint(PoseLandmarkType.leftAnkle, highlight: true);
      drawJoint(PoseLandmarkType.rightHip, highlight: true);
      drawJoint(PoseLandmarkType.rightKnee, highlight: true);
      drawJoint(PoseLandmarkType.rightAnkle, highlight: true);
    } else {
      // Jumping jacks - full body
      // Arms
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // Body
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      // Legs
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      // All joints
      drawJoint(PoseLandmarkType.leftWrist);
      drawJoint(PoseLandmarkType.rightWrist);
      drawJoint(PoseLandmarkType.leftAnkle);
      drawJoint(PoseLandmarkType.rightAnkle);
    }

    // Draw angle text if available
    if (currentAngle != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${currentAngle!.toStringAsFixed(0)}°',
          style: GoogleFonts.rajdhani(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: CyberpunkColors.primary,
            shadows: [
              const Shadow(color: Colors.black, blurRadius: 8, offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 20, 20));
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.currentAngle != currentAngle;
  }
}
