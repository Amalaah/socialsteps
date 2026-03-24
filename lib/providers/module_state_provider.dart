import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialsteps/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/telemetry_service.dart';

// ─── Model ────────────────────────────────────────────────────────────────

class ModuleState {
  final int totalQuestions;
  final int correctCount;
  final int mistakes;
  final DateTime startTime;
  /// The activity module this session tracks (e.g. 'puzzle', 'emotion').
  final String? moduleKey;
  /// Local UI mirror of the child's star count (optimistic update)
  final int stars;
  /// Whether the last activity earned a star (for snack-bar feedback)
  final bool? lastEarnedStar;

  // ── Social Interaction module – level progress ──────────────────────────
  /// Zero-based index of the currently active social level (0 = Level 1).
  final int socialCurrentLevel;
  /// Which levels have been completed (length == total social levels).
  final List<bool> socialCompletedLevels;

  ModuleState({
    required this.totalQuestions,
    required this.correctCount,
    required this.mistakes,
    required this.startTime,
    this.moduleKey,
    this.stars = 0,
    this.lastEarnedStar,
    this.socialCurrentLevel = 0,
    List<bool>? socialCompletedLevels,
  }) : socialCompletedLevels =
           socialCompletedLevels ?? List.filled(5, false);

  ModuleState copyWith({
    int? totalQuestions,
    int? correctCount,
    int? mistakes,
    DateTime? startTime,
    String? moduleKey,
    int? stars,
    bool? lastEarnedStar,
    int? socialCurrentLevel,
    List<bool>? socialCompletedLevels,
  }) {
    return ModuleState(
      totalQuestions:        totalQuestions        ?? this.totalQuestions,
      correctCount:          correctCount          ?? this.correctCount,
      mistakes:              mistakes              ?? this.mistakes,
      startTime:             startTime             ?? this.startTime,
      moduleKey:             moduleKey             ?? this.moduleKey,
      stars:                 stars                 ?? this.stars,
      lastEarnedStar:        lastEarnedStar,
      socialCurrentLevel:    socialCurrentLevel    ?? this.socialCurrentLevel,
      socialCompletedLevels: socialCompletedLevels ?? List<bool>.from(this.socialCompletedLevels),
    );
  }

  /// Live accuracy ratio (0.0–1.0). Returns 0 when no questions answered.
  double get accuracy =>
      totalQuestions == 0 ? 0.0 : correctCount / totalQuestions;

  /// Seconds elapsed since the session started.
  int get elapsedSeconds => DateTime.now().difference(startTime).inSeconds;
}

// ─── Notifier ─────────────────────────────────────────────────────────────

class ModuleStateNotifier extends Notifier<ModuleState> {
  @override
  ModuleState build() {
    return ModuleState(
      totalQuestions: 0,
      correctCount: 0,
      mistakes: 0,
      startTime: DateTime.now(),
    );
  }

  void reset({String? moduleKey}) {
    // Intentionally preserve social level progress so re-entering the
    // Social module mid-session resumes from where the child left off.
    state = ModuleState(
      totalQuestions:        0,
      correctCount:          0,
      mistakes:              0,
      startTime:             DateTime.now(),
      moduleKey:             moduleKey ?? state.moduleKey,
      stars:                 state.stars,
      socialCurrentLevel:    state.socialCurrentLevel,
      socialCompletedLevels: state.socialCompletedLevels,
    );
  }

  // ── Social level helpers ───────────────────────────────────────────────

  /// Mark [level] (0-based) as completed and advance [socialCurrentLevel].
  void completeSocialLevel(int level) {
    final updated = List<bool>.from(state.socialCompletedLevels);
    if (level < updated.length) updated[level] = true;
    final next = (level + 1).clamp(0, updated.length - 1);
    state = state.copyWith(
      socialCompletedLevels: updated,
      socialCurrentLevel: updated.every((c) => c) ? level : next,
    );
  }

  /// Resets social level progress to the beginning (fresh attempt).
  void resetSocialProgress() {
    state = state.copyWith(
      socialCurrentLevel:    0,
      socialCompletedLevels: List.filled(5, false),
    );
  }

  /// Record an answer and optionally push a live progress snapshot to Firestore.
  /// [moduleKey] must be supplied on first call (or via reset) for the snapshot
  /// to be written; subsequent calls inherit the stored key.
  void recordAnswer(bool correct, {String? moduleKey}) {
    final key = moduleKey ?? state.moduleKey;
    state = state.copyWith(
      totalQuestions: state.totalQuestions + 1,
      correctCount:   state.correctCount + (correct ? 1 : 0),
      mistakes:       state.mistakes     + (correct ? 0 : 1),
      moduleKey:      key,
    );
    if (key != null) _saveProgressSnapshot(key);
  }

  void recordRound(int rounds, int correctRounds) {
    state = state.copyWith(
      totalQuestions: state.totalQuestions + rounds,
      correctCount: state.correctCount + correctRounds,
    );
  }

  /// Record an answer and award stars based on milestones of 3 correct answers.
  ///
  /// Rule: stars = correctAnswers ~/ 3
  ///   3 correct → 1 star, 6 → 2 stars, 9 → 3 stars, etc.
  ///
  /// Returns the number of new stars earned (0 or 1 per call, but could be
  /// more if answers are batch-recorded) so callers can show feedback.
  Future<int> recordAnswerAndReward(bool correct, {String? moduleKey}) async {
    final key = moduleKey ?? state.moduleKey;

    // Capture milestone BEFORE incrementing
    final int oldMilestone = state.correctCount ~/ 3;

    // Update state
    state = state.copyWith(
      totalQuestions: state.totalQuestions + 1,
      correctCount:   state.correctCount + (correct ? 1 : 0),
      mistakes:       state.mistakes     + (correct ? 0 : 1),
      moduleKey:      key,
    );

    // Push live progress snapshot (fire-and-forget, non-blocking)
    if (key != null) _saveProgressSnapshot(key);

    if (!correct) return 0;

    // Calculate how many new stars should be awarded
    int starsOwed = 0;

    // Social module is harder, so it bypasses the 3-answer milestone rule
    // and awards 1 star per successful level completion.
    if (key == 'social') {
      starsOwed = 1;
    } else {
      final int newMilestone = state.correctCount ~/ 3;
      starsOwed = newMilestone - oldMilestone;
    }

    if (starsOwed <= 0) return 0;

    // Trigger reward engine once per star owed
    int starsEarned = 0;
    for (int i = 0; i < starsOwed; i++) {
      final earned = await _runRewardEngine();
      if (earned) starsEarned++;
    }

    state = state.copyWith(
      stars:          state.stars + starsEarned,
      lastEarnedStar: starsEarned > 0,
    );

    return starsEarned;
  }

  // ─── Private: live progress snapshot ────────────────────────────────────

  /// Writes current accuracy, elapsed time, and proportional progress to
  /// Firestore. Called fire-and-forget after every answer so the parent
  /// dashboard always shows up-to-date figures.
  void _saveProgressSnapshot(String key) {
    // Run asynchronously – do not await to keep UI responsive
    _doSaveSnapshot(key).ignore();
  }

  Future<void> _doSaveSnapshot(String key) async {
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

    // Proportional progress: advances as questions accumulate.
    // Capped at 0.99 so the final saveBatch at completion sets 1.0.
    final double liveProgress =
        state.totalQuestions == 0 ? 0.0 :
        (state.totalQuestions / _expectedTotal(key)).clamp(0.0, 0.99);

    final updates = <String, dynamic>{
      '${key}Accuracy': state.accuracy,
      '${key}Time':     state.elapsedSeconds,
      '${key}Progress': liveProgress,
    };

    // For focus module, also track rounds and successes
    if (key == 'focus') {
      updates['focusRounds']   = state.totalQuestions;
      updates['focusSuccess']  = state.correctCount;
    }

    await doc.reference.update(updates);
  }

  /// Expected total answers per module (used for proportional progress).
  int _expectedTotal(String key) {
    switch (key) {
      case 'emotion': return 11; // 3 easy + 3 medium + 5 hard
      case 'focus':   return 9;  // 3 levels × 3 rounds
      case 'puzzle':  return 9;  // level1=5 + level2=4
      case 'color':   return 5;  // 5 items
      case 'social':  return 5;  // 5 sequential levels
      default:        return 10;
    }
  }

  Future<bool> _runRewardEngine() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(user.uid)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;

    final doc = snapshot.docs.first;
    final data = doc.data();

    int totalStars = data['stars'] ?? 0;
    int dailyStars = data['dailyStars'] ?? 0;
    int dailyCap   = data['dailyStarCap'] ?? 10;
    int streak     = data['streak'] ?? 0;

    final String today = DateTime.now().toIso8601String().split('T').first;
    final String? lastRewardDate = data['lastRewardDate'];
    final String? lastPlayDate   = data['lastPlayDate'];

    // Reset daily stars if new day
    if (lastRewardDate != today) dailyStars = 0;

    // Update streak
    if (lastPlayDate == null) {
      streak = 1;
    } else if (lastPlayDate == today) {
      // same day – no change
    } else {
      final String yesterdayStr = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')
          .first;
      streak = lastPlayDate == yesterdayStr ? streak + 1 : 1;
    }

    if (dailyStars >= dailyCap) {
      // Update streak/play date but don't add star
      await doc.reference.update({
        'lastRewardDate': today,
        'lastPlayDate': today,
        'streak': streak,
      });
      return false;
    }

    await doc.reference.update({
      'stars': totalStars + 1,
      'dailyStars': dailyStars + 1,
      'lastRewardDate': today,
      'lastPlayDate': today,
      'streak': streak,
    });

    return true;
  }

  // ─── Batch Firestore save on module completion ───────────────────────────

  Future<void> saveBatchToFirestore({
    required String moduleKey,
    required double accuracy,
    required int secondsTaken,
    double? progressOverride,
  }) async {
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
    final double oldAccuracy =
        (doc.data()[moduleKey + 'Accuracy'] ?? 0.0).toDouble();

    final updates = <String, dynamic>{
      moduleKey + 'PreviousAccuracy': oldAccuracy,
      moduleKey + 'Accuracy': accuracy,
      moduleKey + 'Time': secondsTaken,
      if (moduleKey == 'focus') 'focusRounds': state.totalQuestions,
      if (moduleKey == 'focus') 'focusSuccess': state.correctCount,
    };

    updates[moduleKey + 'Progress'] = progressOverride ?? 1.0;

    await doc.reference.update(updates);

    // Anonymous telemetry for ML retraining
    final combinedData =
        Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
    combinedData.addAll(updates);
    TelemetryService.logSessionData(combinedData, moduleKey);
  }
}

// ─── Providers ────────────────────────────────────────────────────────────

final moduleStateProvider =
    NotifierProvider<ModuleStateNotifier, ModuleState>(() {
  return ModuleStateNotifier();
});

/// Live stream of the child's star count from Firestore.
/// Widgets can watch this to refresh the star counter in real time.
final childStarsProvider = StreamProvider<int>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.parentsCollection)
      .doc(user.uid)
      .collection(AppConstants.childrenCollection)
      .limit(1)
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return 0;
    return (snap.docs.first.data()['stars'] ?? 0) as int;
  });
});

/// Live stream of the full child document.
/// RewardScreen and parent dashboard use this to read stars, streak, etc.
final childDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection(AppConstants.parentsCollection)
      .doc(user.uid)
      .collection(AppConstants.childrenCollection)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isEmpty ? null : snap.docs.first.data());
});

