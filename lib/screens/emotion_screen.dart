import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/module_state_provider.dart';
import '../widgets/parental_guard.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'reward_screen.dart';

class EmotionScreen extends ConsumerStatefulWidget {
  const EmotionScreen({super.key});

  @override
  ConsumerState<EmotionScreen> createState() => _EmotionScreenState();
}

class _EmotionScreenState extends ConsumerState<EmotionScreen> {
  String level = "easy";
  int imageIndex = 0;
  bool _isCompleted = false;

  int totalQuestions = 0;
  int correctCount = 0;
  int mistakes = 0;
  int lastRewardCheckpoint = 0;

  late DateTime startTime;

  final Map<String, List<String>> emotionImages = {
    "easy": [
      "assets/emotions/easy/hpyeasy1.jpg",
      "assets/emotions/easy/sadeasy1.jpg",
      "assets/emotions/easy/angeasy1.jpg",
    ],
    "medium": [
      "assets/emotions/medium/hpymed1.jpg",
      "assets/emotions/medium/sadmed1.jpg",
      "assets/emotions/medium/anghard1.jpg",
    ],
    "hard": [
      "assets/emotions/hard/hpyhard1.jpg",
      "assets/emotions/hard/sadhard1.jpg",
      "assets/emotions/hard/anghard11.jpg",
      "assets/emotions/hard/surprised.jpg",
      "assets/emotions/hard/neutral.jpg",
    ],
  };

  final Map<String, String> correctAnswers = {
    "assets/emotions/easy/hpyeasy1.jpg": "Happy",
    "assets/emotions/easy/sadeasy1.jpg": "Sad",
    "assets/emotions/easy/angeasy1.jpg": "Angry",
    "assets/emotions/medium/hpymed1.jpg": "Happy",
    "assets/emotions/medium/sadmed1.jpg": "Sad",
    "assets/emotions/medium/anghard1.jpg": "Angry",
    "assets/emotions/hard/hpyhard1.jpg": "Happy",
    "assets/emotions/hard/sadhard1.jpg": "Sad",
    "assets/emotions/hard/anghard11.jpg": "Angry",
    "assets/emotions/hard/surprised.jpg": "Surprised",
    "assets/emotions/hard/neutral.jpg": "Neutral",
  };

  List<Map<String, String>> emotionOptions = [
    {"label": "Happy", "emoji": "😊"},
    {"label": "Sad", "emoji": "😢"},
    {"label": "Angry", "emoji": "😠"},
    {"label": "Surprised", "emoji": "😲"},
    {"label": "Neutral", "emoji": "😐"},
  ];

  @override
  void initState() {
    super.initState();
    emotionImages['easy']!.shuffle();
    emotionImages['medium']!.shuffle();
    emotionImages['hard']!.shuffle();
    emotionOptions.shuffle();
    startTime = DateTime.now();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(moduleStateProvider.notifier).reset(moduleKey: 'emotion');
    });
  }

  Future<void> updateProgress(double progress) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(user.uid)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update({
        "emotionProgress": progress,
      });
    }
  }

  void checkAnswer(String selectedEmotion) async {
    final currentImage = emotionImages[level]![imageIndex];

    totalQuestions++;

    if (correctAnswers[currentImage] == selectedEmotion) {
      correctCount++;

      final starsEarned = await ref
          .read(moduleStateProvider.notifier)
          .recordAnswerAndReward(true, moduleKey: 'emotion');

      if (!mounted) return;
      if (starsEarned > 0) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RewardScreen(
              starsJustEarned: starsEarned,
              message: 'You answered ${ref.read(moduleStateProvider).correctCount} correctly!',
            ),
          ),
        );
      }
      moveToNext();
    } else {
      mistakes++;
      ref.read(moduleStateProvider.notifier).recordAnswer(false, moduleKey: 'emotion');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Oops! 😅"),
          content: const Text("Try Again"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );
    }

    int totalImages =
        emotionImages["easy"]!.length +
        emotionImages["medium"]!.length +
        emotionImages["hard"]!.length;

    double progress = totalQuestions / totalImages;
    progress = progress.clamp(0.0, 1.0);

    await updateProgress(progress);
  }

  void finishModule() async {
    setState(() {
      _isCompleted = true; // Allow ParentalGuard to exit
    });

    int secondsTaken =
        DateTime.now().difference(startTime).inSeconds;

    double accuracy =
        totalQuestions == 0 ? 0 : correctCount / totalQuestions;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("🎉 Module Completed"),
        content: Text(
          "Accuracy: ${(accuracy * 100).toInt()}%\n"
          "Time: ${secondsTaken}s",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit module
            },
            child: const Text("Awesome!"),
          ),
        ],
      ),
    );
  }

  void moveToNext() {
    setState(() {
      emotionOptions.shuffle();
      imageIndex++;

      if (imageIndex >= emotionImages[level]!.length) {
        imageIndex = 0;

        if (level == "easy") {
          level = "medium";
        } else if (level == "medium") {
          level = "hard";
        } else {
          finishModule();
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (imageIndex >= emotionImages[level]!.length) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final currentImage = emotionImages[level]![imageIndex];

    return ParentalGuard(
      isCompleted: _isCompleted,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          title: const Text('Emotion Recognition'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: PageEntry(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // ── Level badge ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.4)),
                  ),
                  child: Text(
                    'Level: ${level.toUpperCase()}',
                    style: const TextStyle(
                      color: AppTheme.primaryLt,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // ── Emotion image ────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 24, offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Image.asset(currentImage,
                        width: 240, height: 240, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 24),
                Text('How is this person feeling?', 
                  style: AppTheme.subheading.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 32),
                // ── Emotion option buttons ─────────────────────
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: emotionOptions.map((emotion) {
                    return GestureDetector(
                      onTap: () => checkAnswer(emotion['label']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.35),
                              blurRadius: 10, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emotion['emoji']!,
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Text(
                              emotion['label']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
