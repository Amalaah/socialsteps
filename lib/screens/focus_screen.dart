import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'reward_screen.dart';
import '../providers/module_state_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/parental_guard.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final Random _random = Random();
  late DateTime _startTime;

  String _level = "easy";
  int _round = 1;

  // Level config: rounds per level
  final Map<String, int> _totalRoundsMap = {
    "easy": 3,
    "medium": 4,
    "hard": 5,
  };

  // State variables for the round
  bool _isPlaying = false;
  bool _showObjects = false;
  bool _canTap = true; // Used in Hard mode to penalize early taps
  String _waitingText = "Get ready…";

  // Data tracking
  int _totalCorrectActions = 0; // Tracks every successful tap
  int _lastRewardCheckpoint = 0; // Every 3 actions = 1 star
  bool _isModuleCompleted = false;

  // Object positions
  Offset? _targetPosition;
  List<Offset> _distractorPositions = [];
  Offset? _highlightedPosition; // For medium mode brief highlight

  Timer? _hardModeDelayTimer;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(moduleStateProvider.notifier).reset(moduleKey: 'focus');
    });

    _startRound();
  }

  @override
  void dispose() {
    _hardModeDelayTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  // -------------------- TIMING & LOGIC --------------------

  void _startRound() {
    _hardModeDelayTimer?.cancel();
    _highlightTimer?.cancel();

    setState(() {
      _isPlaying = true;
      _showObjects = false;
      _targetPosition = null;
      _distractorPositions.clear();
      _highlightedPosition = null;

      if (_level == "hard") {
        _canTap = false;
        _waitingText = "Wait...";
      } else {
        _canTap = true;
        _waitingText = "Get ready…";
      }
    });

    // 1 second base delay before showing objects
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isPlaying) return;
      _generateObjects();
    });
  }

  void _generateObjects() {
    final Size size = MediaQuery.of(context).size;
    
    // Bounds to prevent objects drawing off-screen.
    // Assuming standard screen width ~360-400, height ~600-800
    // Accounting for app bar and status bar: keep y between 100 and screenHeight-150.
    // keep x between 20 and screenWidth-80.
    final double minX = 20;
    final double maxX = max(20, size.width - 80);
    final double minY = 100;
    final double maxY = max(100, size.height - 200);

    Offset randomOffset() {
      return Offset(
        _random.nextDouble() * (maxX - minX) + minX,
        _random.nextDouble() * (maxY - minY) + minY,
      );
    }

    _targetPosition = randomOffset();

    if (_level == "medium") {
      // 2 to 4 distractors
      int distractorsCount = _random.nextInt(3) + 2; 
      for (int i = 0; i < distractorsCount; i++) {
        _distractorPositions.add(randomOffset());
      }

      // Briefly highlight the correct one before full display
      setState(() {
        _highlightedPosition = _targetPosition;
        _showObjects = true;
      });

      _highlightTimer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _highlightedPosition = null;
        });
      });

    } else if (_level == "hard") {
      // Small/hidden/delayed "GO" signal
      // Add more distractors
      int distractorsCount = _random.nextInt(4) + 3;
      for (int i = 0; i < distractorsCount; i++) {
        _distractorPositions.add(randomOffset());
      }
      
      // Delay before objects actually appear and CAN be tapped
      int delayMs = _random.nextInt(1500) + 1000; // 1 to 2.5 second delay
      
      setState(() {
         // Show distractors but no target yet? Or show nothing until GO.
         // Let's show nothing until GO to test reflexes.
      });

      _hardModeDelayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        setState(() {
          _waitingText = "GO!";
          _canTap = true;
          _showObjects = true;
        });
      });

    } else {
      // Easy mode: Just the single star
      setState(() {
        _showObjects = true;
      });
    }
  }

  // -------------------- INTERACTIONS --------------------

  void _onTargetTap() {
    if (!_canTap) {
      _handleEarlyTap();
      return;
    }

    if (!_isPlaying) return; // Prevent double taps
    _isPlaying = false; // Disable further taps until next round begins

    _handleCorrectAction();
  }

  void _onDistractorTap() {
    if (!_canTap) {
      _handleEarlyTap();
      return;
    }

    if (!_isPlaying) return;

    ref.read(moduleStateProvider.notifier).recordAnswer(false, moduleKey: 'focus');

    // Show oops
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Oops! That's not the correct object. Try again!"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onBackgroundTap() {
    if (_level == "hard" && !_canTap && _isPlaying) {
      _handleEarlyTap();
    }
  }

  void _handleEarlyTap() {
    _hardModeDelayTimer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Too early! Wait for the GO signal! Let's try again."),
        duration: Duration(seconds: 2),
      ),
    );
    // Restart round as penalty
    _startRound();
  }

  Future<void> _handleCorrectAction() async {
    _totalCorrectActions++;

    // Calculate progression
    int moduleMaxRounds = _totalRoundsMap.values.reduce((a, b) => a + b); // 12 total rounds
    int currentTotalRoundsPassed = _getPassedRounds() + _round;
    double progress = (currentTotalRoundsPassed / moduleMaxRounds).clamp(0.0, 1.0);

    // Call state notifier to record answer and check for milestones (every 3 correct hits)
    final starsEarned = await ref
        .read(moduleStateProvider.notifier)
        .recordAnswerAndReward(true, moduleKey: 'focus');

    if (!mounted) return;

    // Provide visual feedback for the specific hit
    if (starsEarned > 0) {
      // Milestone reached (multiple of 3) -> Show the big reward popup
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RewardScreen(
            starsJustEarned: starsEarned,
            message: 'Incredible focus! You earned a star! 🌟',
          ),
        ),
      );
    } else {
      // Small visual reward for non-milestone hits
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Great job! 🎯"),
          duration: Duration(milliseconds: 600),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // Explicitly update progress doc (recordAnswerAndReward also updates telemetry)
    await _updateProgress(progress, currentTotalRoundsPassed);

    // Move to next step after a tiny delay
    Future.delayed(const Duration(milliseconds: 700), _nextStep);
  }

  int _getPassedRounds() {
    int passed = 0;
    if (_level == "medium" || _level == "hard") {
      passed += _totalRoundsMap["easy"]!;
    }
    if (_level == "hard") {
      passed += _totalRoundsMap["medium"]!;
    }
    return passed;
  }

  void _nextStep() {
    if (!mounted) return;

    final targetRoundsForLevel = _totalRoundsMap[_level]!;
    
    if (_round < targetRoundsForLevel) {
      _round++;
      _startRound();
    } else {
      _round = 1;
      if (_level == "easy") {
        _level = "medium";
        _startRound();
      } else if (_level == "medium") {
        _level = "hard";
        _startRound();
      } else {
        // Module successfully completed
        setState(() => _isModuleCompleted = true);
        Navigator.pop(context);
      }
    }
  }

  // -------------------- FIREBASE PROGRESS --------------------

  Future<void> _updateProgress(double progress, int successfulRounds) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(user.uid)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;
    final doc = snapshot.docs.first;

    await doc.reference.update({
      "focusProgress": progress,
      "focusSuccess": successfulRounds,
      "focusTime": DateTime.now().difference(_startTime).inSeconds,
    });
  }

  // -------------------- UI ELEMENTS --------------------

  @override
  Widget build(BuildContext context) {
    return ParentalGuard(
      isCompleted: _isModuleCompleted,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(title: const Text('Focus Training')),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _onBackgroundTap(),
          child: Stack(
            children: [
              // Info Banner
              Positioned(
                top: 16, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
                      ]
                    ),
                    child: Text(
                      'Level: ${_level.toUpperCase()}  •  Round: $_round / ${_totalRoundsMap[_level]}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
  
              // Waiting/Status Text
              if (!_showObjects || (_level == 'hard' && _waitingText == 'GO!'))
                Center(
                  child: AnimatedOpacity(
                    opacity: (!_showObjects || _waitingText == 'GO!') ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _waitingText,
                      style: TextStyle(
                        color: _waitingText == 'GO!' ? AppTheme.mint : AppTheme.textHint,
                        fontSize: _waitingText == 'GO!' ? 48 : 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
  
              // Render Target & Distractors
              if (_showObjects) ...[
                
                // 1. Distractors
                for (final pos in _distractorPositions)
                  Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: GestureDetector(
                      onTapDown: (_) => _onDistractorTap(),
                      child: _buildDistractor(),
                    ),
                  ),
  
                // 2. Target Object
                if (_targetPosition != null)
                  Positioned(
                    left: _targetPosition!.dx,
                    top: _targetPosition!.dy,
                    child: GestureDetector(
                       onTapDown: (_) => _onTargetTap(),
                       child: _buildTarget(),
                    ),
                  )
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistractor() {
    return Icon(
      _level == "medium" ? Icons.circle : Icons.square_rounded,
      size: _level == "hard" ? 30 : 50,
      color: AppTheme.coral.withOpacity(_level == "hard" ? 0.4 : 0.8),
    );
  }

  Widget _buildTarget() {
    bool isHighlighted = (_highlightedPosition == _targetPosition);
    double size = _level == "hard" ? 35 : (_level == "medium" ? 60 : 80);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        boxShadow: [
          if (isHighlighted || _level == "easy")
            BoxShadow(
              color: AppTheme.amber.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 5,
            ),
        ],
      ),
      child: Transform.rotate(
        angle: _level == "hard" ? pi / 4 : 0, // Rotate slightly on hard mode
        child: Icon(
          Icons.star_rounded,
          size: size,
          color: isHighlighted ? Colors.white : AppTheme.amber,
        ),
      ),
    );
  }
}
