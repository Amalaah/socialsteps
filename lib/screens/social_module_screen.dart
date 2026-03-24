import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import '../providers/module_state_provider.dart';
import '../services/social_detection_service.dart';
import '../utils/app_theme.dart';
import '../widgets/parental_guard.dart';
import 'reward_screen.dart';

// ─── Level definitions ────────────────────────────────────────────────────────

enum _Signal { eyeContact, smile, wave }

class _LevelDef {
  final String title;
  final String emoji;
  final String instruction;
  final String hint;
  final int holdSeconds;
  final List<_Signal> required;

  const _LevelDef({
    required this.title,
    required this.emoji,
    required this.instruction,
    required this.hint,
    required this.holdSeconds,
    required this.required,
  });

  bool isMet(DetectionResult r) => required.every((s) {
        switch (s) {
          case _Signal.eyeContact:
            return r.eyeContact;
          case _Signal.smile:
            return r.smiling;
          case _Signal.wave:
            return r.waving;
        }
      });
}

const List<_LevelDef> _levels = [
  _LevelDef(
    title: 'Eye Contact',
    emoji: '👁️',
    instruction: 'Look straight at the camera!',
    hint: 'Face the camera and keep both eyes open for 3 seconds.',
    holdSeconds: 3,
    required: [_Signal.eyeContact],
  ),
  _LevelDef(
    title: 'Wave Hello',
    emoji: '👋',
    instruction: 'Wave your hand at the camera!',
    hint: 'Move your hand left and right in front of the camera.',
    holdSeconds: 4,
    required: [_Signal.wave],
  ),
  _LevelDef(
    title: 'Eye Contact & Smile',
    emoji: '😊',
    instruction: 'Look at the camera and smile!',
    hint: 'Keep looking at the camera and show a big smile.',
    holdSeconds: 4,
    required: [_Signal.eyeContact, _Signal.smile],
  ),
  _LevelDef(
    title: 'Look then Wave',
    emoji: '🤩',
    instruction: 'Look at the camera, then wave!',
    hint: 'First make eye contact, then wave your hand.',
    holdSeconds: 5,
    required: [_Signal.eyeContact, _Signal.wave],
  ),
  _LevelDef(
    title: 'Full Greeting',
    emoji: '🎉',
    instruction: 'Eye contact, wave, then smile!',
    hint: 'Look at the camera, wave your hand, and show a big smile!',
    holdSeconds: 6,
    required: [_Signal.eyeContact, _Signal.wave, _Signal.smile],
  ),
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

enum _PermState { checking, granted, denied, permanentlyDenied }

// Level status as seen by the UI
enum _LevelStatus { completed, active, locked }

_LevelStatus _statusOf(int index, int currentLevel, List<bool> completed) {
  if (completed[index]) return _LevelStatus.completed;
  if (index == currentLevel) return _LevelStatus.active;
  return _LevelStatus.locked;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

/// Social Interaction module screen.
///
/// Level progress ([socialCurrentLevel] / [socialCompletedLevels]) lives in
/// [moduleStateProvider] so it survives navigation away from this screen
/// during the same app session. Completing a level calls
/// [ModuleStateNotifier.completeSocialLevel] which atomically marks it done
/// and advances [socialCurrentLevel] to the next unlocked level.
class SocialModuleScreen extends ConsumerStatefulWidget {
  const SocialModuleScreen({super.key});

  @override
  ConsumerState<SocialModuleScreen> createState() => _SocialModuleScreenState();
}

class _SocialModuleScreenState extends ConsumerState<SocialModuleScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // ── Camera / detection ────────────────────────────────────────────────────
  CameraController? _camera;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  late SocialDetectionService _detector;
  StreamSubscription<DetectionResult>? _detectionSub;
  DetectionResult _det = DetectionResult.empty;

  // ── Video tutorial ──────────────────────────────────────────────────────────
  VideoPlayerController? _videoController;
  bool _isVideoPhase = true;

  // ── Permission ────────────────────────────────────────────────────────────
  _PermState _permState = _PermState.checking;

  // ── Hold-progress (local UI state only – does not need to persist) ────────
  double _holdProgress = 0.0;
  Timer? _holdTimer;
  bool _levelTransitioning = false;

  // Guard to prevent camera callbacks after dispose
  bool _disposed = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _celebCtrl;
  late Animation<double> _celebScale;

  // ── Convenience getters backed by provider ────────────────────────────────

  /// Zero-based index of the active level, sourced from the provider.
  int get _currentLevel => ref.read(moduleStateProvider).socialCurrentLevel;

  /// Which levels are done, sourced from the provider.
  List<bool> get _completed =>
      ref.read(moduleStateProvider).socialCompletedLevels;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detector = SocialDetectionService();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _celebScale =
        CurvedAnimation(parent: _celebCtrl, curve: Curves.elasticOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Reset the timer / accuracy counters but KEEP social level progress.
      ref.read(moduleStateProvider.notifier).reset(moduleKey: 'social');
      _checkPermissionAndInit();
    });
  }

  void _playLevelVideo(int level) {
    _videoController?.dispose();
    final path = 'assets/videos/level${level + 1}_tutorial.mp4';
    
    // We instantiate the controller but do not use it until initialized.
    final ctrl = VideoPlayerController.asset(path);
    setState(() {
      _videoController = ctrl;
      _isVideoPhase = true;
    });

    ctrl.initialize().then((_) {
      if (!mounted) return;
      
      // Stop camera frame processing while video plays
      if (_camera?.value.isStreamingImages == true) {
        _camera?.stopImageStream().ignore();
      }

      setState(() {}); // refresh after initialize
      ctrl.play();
    }).catchError((e) {
      debugPrint('[SocialModule] Video error for $path: $e');
      // If video fails, fallback to camera logic
      if (mounted) {
        setState(() => _isVideoPhase = false);
        _startImageStream();
      }
    });

    ctrl.addListener(() {
      if (!mounted) return;
      if (ctrl.value.isInitialized && ctrl.value.position >= ctrl.value.duration) {
        if (_isVideoPhase) {
          setState(() {
            _isVideoPhase = false;
          });
          ctrl.pause(); // Retain the last frame
          _startImageStream(); // Start actual camera processing
        }
      }
    });
  }

  void _replayVideo() {
    if (_videoController == null) return;
    
    // Stop camera frames and detection
    if (_camera?.value.isStreamingImages == true) {
      _camera?.stopImageStream().ignore();
    }
    
    setState(() {
      _isVideoPhase = true;
      _det = DetectionResult.empty; // Clear old detection status
    });
    
    _videoController!.seekTo(Duration.zero);
    _videoController!.play();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_camera?.value.isStreamingImages == true) {
        _camera?.stopImageStream().ignore();
      }
      _videoController?.pause();
    } else if (state == AppLifecycleState.resumed &&
        _permState == _PermState.granted &&
        !_disposed) {
      if (_isVideoPhase && _videoController != null) {
        _videoController?.play();
      } else {
        _startImageStream();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;                               // guard first — no more frame callbacks
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    _detectionSub?.cancel();
    // Stop stream synchronously before the camera is disposed to drain in-flight
    // processFrame calls and prevent DeviceOrientationManager race condition.
    try {
      if (_camera?.value.isStreamingImages == true) {
        _camera!.stopImageStream().ignore();
      }
    } catch (_) {}
    _camera?.dispose();
    _videoController?.dispose();
    _detector.dispose();
    _pulseCtrl.dispose();
    _celebCtrl.dispose();
    super.dispose();
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _permState = _PermState.granted);
      await _initCamera();
    } else if (status.isPermanentlyDenied) {
      setState(() => _permState = _PermState.permanentlyDenied);
    } else {
      setState(() => _permState = _PermState.denied);
    }
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (_disposed || cameras.isEmpty) return;
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _rotation = _sensorToRotation(cam.sensorOrientation);
      final ctrl = CameraController(
        cam, 
        ResolutionPreset.low,
        enableAudio: false, 
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      if (_disposed || !mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _camera = ctrl);
      
      // Hook up level playback here once camera is primed
      _playLevelVideo(_currentLevel);
      _subscribeToDetection();
    } catch (e) {
      debugPrint('[SocialModule] Camera error: $e');
    }
  }

  void _startImageStream() {
    if (_disposed) return;
    if (_camera == null || !_camera!.value.isInitialized) return;
    if (_camera!.value.isStreamingImages) return;
    _camera!.startImageStream((img) {
      if (!_disposed) _detector.processFrame(img, _rotation);
    });
  }

  void _subscribeToDetection() {
    _detectionSub = _detector.results.listen((r) {
      if (!mounted || _levelTransitioning) return;
      setState(() => _det = r);
      _evaluateLevel(r);
    });
  }

  // ── Level evaluation ──────────────────────────────────────────────────────

  void _evaluateLevel(DetectionResult r) {
    if (_isVideoPhase) return; // Ignore detections during video

    final cur = _currentLevel;
    if (cur >= _levels.length) return;

    // If the level is already completed in the provider, skip
    if (_completed[cur]) return;

    final met = _levels[cur].isMet(r);

    if (met && _holdTimer == null) {
      final totalMs = _levels[cur].holdSeconds * 1000;
      const tickMs = 50;
      _holdTimer =
          Timer.periodic(const Duration(milliseconds: tickMs), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _holdProgress =
              (_holdProgress + tickMs / totalMs).clamp(0.0, 1.0);
        });
        if (_holdProgress >= 1.0) {
          t.cancel();
          _holdTimer = null;
          _completeLevel(cur);
        }
      });
    } else if (!met && _holdTimer != null) {
      _holdTimer?.cancel();
      _holdTimer = null;
      setState(() => _holdProgress = 0.0);
    }
  }

  Future<void> _completeLevel(int level) async {
    _levelTransitioning = true;
    setState(() => _holdProgress = 0.0);

    // ── 1. Persist level completion in provider ───────────────────────────
    ref
        .read(moduleStateProvider.notifier)
        .completeSocialLevel(level); // marks done, advances socialCurrentLevel

    // ── 2. Record attempt + run reward engine (stars = correct ~/ 3) ─────
    //
    // recordAnswerAndReward:
    //   • increments totalQuestions + correctCount
    //   • pushes a live Firestore progress snapshot (_saveProgressSnapshot)
    //   • checks milestone: if correctCount crosses a multiple of 3, calls
    //     _runRewardEngine which writes stars / dailyStars to Firestore →
    //     the childStarsProvider / childDocProvider StreamProviders react
    //     immediately (no extra notifyListeners() needed — Riverpod does it)
    final starsEarned = await ref
        .read(moduleStateProvider.notifier)
        .recordAnswerAndReward(true, moduleKey: 'social');

    // ── 3. Star-earned feedback ───────────────────────────────────────────
    if (mounted && starsEarned > 0) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RewardScreen(
            message: 'Level Complete!',
            starsJustEarned: starsEarned,
          ),
        ),
      );
    }

    if (!mounted) return;
    _celebCtrl.forward(from: 0);

    final allDone =
        ref.read(moduleStateProvider).socialCompletedLevels.every((c) => c);

    if (allDone) {
      _finishModule();
    } else {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _celebCtrl.reverse();
        _detector.resetWave();
        _levelTransitioning = false;
        
        // Ensure new level starts with its video
        int newLevel = ref.read(moduleStateProvider).socialCurrentLevel;
        if (newLevel < _levels.length) {
          _playLevelVideo(newLevel);
        } else {
          setState(() {}); // refresh UI
        }
      });
    }
  }


  Future<void> _finishModule() async {
    final state = ref.read(moduleStateProvider);
    await ref.read(moduleStateProvider.notifier).saveBatchToFirestore(
          moduleKey: 'social',
          accuracy: state.accuracy,
          secondsTaken: state.elapsedSeconds,
        );
    if (!mounted) return;
    _showCompletionDialog(state.elapsedSeconds);
  }

  void _showCompletionDialog(int seconds) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        title: const Text(
          '🎉 Amazing Job!',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You completed all 5 social skills!',
                textAlign: TextAlign.center, style: AppTheme.body),
            const SizedBox(height: 16),
            _StatChip(emoji: '⏱️', label: 'Time', value: '${seconds}s'),
            const SizedBox(height: 8),
            _StatChip(
                emoji: '⭐',
                label: 'Levels',
                value: '${_levels.length}/${_levels.length}'),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
            onPressed: () {
              // Reset social progress so module can be replayed fresh
              ref
                  .read(moduleStateProvider.notifier)
                  .resetSocialProgress();
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to activities
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Back to Activities'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static InputImageRotation _sensorToRotation(int sensor) {
    switch (sensor) {
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation0deg;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch the provider so the UI rebuilds whenever level state changes
    final socialState = ref.watch(moduleStateProvider);
    final currentLevel = socialState.socialCurrentLevel;
    final completed = socialState.socialCompletedLevels;
    final doneCount = completed.where((c) => c).length;

    return ParentalGuard(
      isCompleted: doneCount == _levels.length,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(currentLevel, doneCount),
              Expanded(
                child: _permState == _PermState.checking
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary))
                    : _permState != _PermState.granted
                        ? _buildPermissionDenied()
                        : SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Column(
                              children: [
                                _buildCameraPanel(currentLevel),
                                const SizedBox(height: 20),
                                _buildLevelList(currentLevel, completed),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(int currentLevel, int doneCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: AppTheme.surface,
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Social Skills', style: AppTheme.subheading),
                Text(
                  doneCount == _levels.length
                      ? 'All levels completed! 🌟'
                      : 'Level ${currentLevel + 1} of ${_levels.length}',
                  style: AppTheme.body,
                ),
              ],
            ),
          ),
          // Overall progress ring
          SizedBox(
            width: 44, height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: doneCount / _levels.length,
                  strokeWidth: 5,
                  backgroundColor: AppTheme.surfaceAlt,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.mint),
                ),
                Text(
                  '$doneCount',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Permission denied ─────────────────────────────────────────────────────

  Widget _buildPermissionDenied() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined,
              size: 72, color: AppTheme.textHint),
          const SizedBox(height: 20),
          const Text('Camera Access Needed',
              style: AppTheme.subheading, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            _permState == _PermState.permanentlyDenied
                ? 'Camera permission was denied. Please open Settings and grant camera access.'
                : 'This module needs the camera to detect your social skills.',
            style: AppTheme.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: Icon(_permState == _PermState.permanentlyDenied
                ? Icons.settings_outlined
                : Icons.camera_alt_outlined),
            label: Text(_permState == _PermState.permanentlyDenied
                ? 'Open Settings'
                : 'Grant Permission'),
            onPressed: _permState == _PermState.permanentlyDenied
                ? openAppSettings
                : _checkPermissionAndInit,
          ),
        ],
      ),
    );
  }

  // ── Camera panel ──────────────────────────────────────────────────────────

  Widget _buildCameraPanel(int currentLevel) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      height: 480,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
            color: AppTheme.primary.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Column(
          children: [
            // Top half: Video Player
            Expanded(
              flex: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : Container(
                          color: AppTheme.surfaceAlt,
                          child: const Center(
                            child: CircularProgressIndicator(color: AppTheme.primary),
                          ),
                        ),
                  
                  // If video is playing, show a "Tutorial" badge
                  if (_isVideoPhase)
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24)
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Tutorial', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  
                  // Replay Button Overlay
                  Positioned(
                    top: 12, right: 12,
                    child: GestureDetector(
                      onTap: _replayVideo,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24)
                        ),
                        child: const Icon(Icons.replay_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom half: Camera Preview
            Expanded(
              flex: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_camera != null && _camera!.value.isInitialized)
                    CameraPreview(_camera!)
                  else
                    Container(
                      color: AppTheme.surfaceAlt,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      ),
                    ),

                  // Overlay block if tutorial is still playing
                  if (_isVideoPhase)
                    Container(
                      color: Colors.black87,
                      child: const Center(
                        child: Text(
                          'Watch the tutorial first! 👀',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  if (!_isVideoPhase) ...[
                    // Gradient + instruction overlay
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 32, 12, 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.76)
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_levels[currentLevel].emoji,
                                style: const TextStyle(fontSize: 26)),
                            const SizedBox(height: 4),
                            Text(
                              _levels[currentLevel].instruction,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            _buildSignalChips(currentLevel),
                          ],
                        ),
                      ),
                    ),
                    
                    // Target dot
                    const Positioned(
                      top: 14, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.circle, size: 9, color: AppTheme.coral),
                          SizedBox(width: 6),
                          Text('Look here',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalChips(int currentLevel) {
    final def = _levels[currentLevel];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8, runSpacing: 6,
      children: [
        if (def.required.contains(_Signal.eyeContact))
          _SignalChip(label: 'Eye Contact',
              icon: Icons.visibility_outlined, active: _det.eyeContact),
        if (def.required.contains(_Signal.smile))
          _SignalChip(label: 'Smile',
              icon: Icons.sentiment_very_satisfied_outlined,
              active: _det.smiling),
        if (def.required.contains(_Signal.wave))
          _SignalChip(label: 'Wave',
              icon: Icons.waving_hand_outlined, active: _det.waving),
      ],
    );
  }

  // ── Level list ────────────────────────────────────────────────────────────

  Widget _buildLevelList(int currentLevel, List<bool> completed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Levels', style: AppTheme.subheading),
        const SizedBox(height: 12),
        ...List.generate(
          _levels.length,
          (i) => _buildLevelCard(i, currentLevel, completed),
        ),
      ],
    );
  }

  Widget _buildLevelCard(int index, int currentLevel, List<bool> completed) {
    final def = _levels[index];
    final status = _statusOf(index, currentLevel, completed);
    final isActive   = status == _LevelStatus.active;
    final isDone     = status == _LevelStatus.completed;
    final isLocked   = status == _LevelStatus.locked;

    // Border color driven by status
    final borderColor = isDone
        ? AppTheme.mint.withOpacity(0.45)
        : isActive
            ? AppTheme.primary.withOpacity(0.65)
            : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.surfaceAlt : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: AppTheme.primary.withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status badge + title row ──────────────────────────────────
            Row(
              children: [
                _LevelBadge(index: index, status: status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(def.emoji,
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(def.title,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isLocked
                                        ? AppTheme.textHint
                                        : AppTheme.textPrimary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isDone
                            ? 'Completed ✅'
                            : isLocked
                                ? '🔒 Complete the previous level first'
                                : def.hint,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDone
                                ? AppTheme.mint
                                : isLocked
                                    ? AppTheme.textHint
                                    : AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Hold-time chip (active only)
                if (isActive)
                  _HoldChip(seconds: def.holdSeconds),
              ],
            ),

            // ── Active level: progress bar + feedback text ────────────────
            if (isActive) ...[
              const SizedBox(height: 14),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _holdProgress,
                  minHeight: 8,
                  backgroundColor: AppTheme.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _holdProgress > 0.0
                        ? AppTheme.mint
                        : AppTheme.primary.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Live status text
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _levels[currentLevel].isMet(_det)
                    ? _StatusRow(
                        key: const ValueKey('active'),
                        icon: Icons.auto_awesome,
                        color: AppTheme.amber,
                        text: _holdProgress > 0
                            ? 'Keep it up! ${(_holdProgress * def.holdSeconds).ceil()}s…'
                            : 'Great! Hold that pose…',
                      )
                    : _StatusRow(
                        key: const ValueKey('waiting'),
                        icon: Icons.remove_red_eye_outlined,
                        color: AppTheme.textHint,
                        text: 'Waiting for detection…',
                      ),
              ),
            ],

            // ── Celebration pop on the level just completed ───────────────
            if (isDone && index == currentLevel - 1)
              Center(
                child: ScaleTransition(
                  scale: _celebScale,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('🌟 Great job!',
                        style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.amber,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Level badge ──────────────────────────────────────────────────────────────

class _LevelBadge extends StatelessWidget {
  final int index;
  final _LevelStatus status;

  const _LevelBadge({required this.index, required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isDone   = status == _LevelStatus.completed;
    final bool isLocked = status == _LevelStatus.locked;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.mint.withOpacity(0.18)
            : isLocked
                ? AppTheme.surface
                : AppTheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(11),
        border: isDone
            ? Border.all(color: AppTheme.mint.withOpacity(0.5), width: 1.5)
            : isLocked
                ? Border.all(color: AppTheme.textHint.withOpacity(0.2))
                : Border.all(color: AppTheme.primary.withOpacity(0.4)),
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_circle_rounded,
                color: AppTheme.mint, size: 22)
            : isLocked
                ? const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.textHint, size: 18)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary),
                  ),
      ),
    );
  }
}

// ─── Hold-time chip ───────────────────────────────────────────────────────────

class _HoldChip extends StatelessWidget {
  final int seconds;
  const _HoldChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20)),
      child: Text('${seconds}s',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryLt)),
    );
  }
}

// ─── Status row ───────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusRow({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

// ─── Signal chip ─────────────────────────────────────────────────────────────

class _SignalChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;

  const _SignalChip(
      {required this.label, required this.icon, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.mint.withOpacity(0.25)
            : Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: active
                ? AppTheme.mint.withOpacity(0.7)
                : Colors.white24,
            width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13, color: active ? AppTheme.mint : Colors.white54),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? AppTheme.mint : Colors.white54)),
        ],
      ),
    );
  }
}

// ─── Stat chip (completion dialog) ───────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatChip(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(label, style: AppTheme.body),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
