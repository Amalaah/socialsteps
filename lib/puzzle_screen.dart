import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'adaptive_reward.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {

  int totalRoundsCompleted = 0;
  int lastRewardCheckpoint = 0;
  int totalAttempts = 0;
  int correctAnswers = 0;
 int correctRounds = 0;
 late DateTime startTime;

  int level = 1;
  int round = 1;

  late String correctAnswer;
  late List<String> options;

  // ⭐ LEVEL DATA
  final Map<int, List<Map<String, dynamic>>> levels = {

    // 🔹 LEVEL 1 — Match Same Image (1–5)
    1: [
      {
        "image": "assets/puzzle/level1/1.jpeg",
        "correct": "assets/puzzle/level1/1.jpeg",
        "options": [
          "assets/puzzle/level1/1.jpeg",
          "assets/puzzle/level1/2.jpeg",
          "assets/puzzle/level1/3.jpeg",
        ]
      },
      {
        "image": "assets/puzzle/level1/2.jpeg",
        "correct": "assets/puzzle/level1/2.jpeg",
        "options": [
          "assets/puzzle/level1/1.jpeg",
          "assets/puzzle/level1/2.jpeg",
          "assets/puzzle/level1/3.jpeg",
        ]
      },
      {
        "image": "assets/puzzle/level1/3.jpeg",
        "correct": "assets/puzzle/level1/3.jpeg",
        "options": [
          "assets/puzzle/level1/3.jpeg",
          "assets/puzzle/level1/4.jpeg",
          "assets/puzzle/level1/5.jpeg",
        ]
      },
      {
        "image": "assets/puzzle/level1/4.jpeg",
        "correct": "assets/puzzle/level1/4.jpeg",
        "options": [
          "assets/puzzle/level1/2.jpeg",
          "assets/puzzle/level1/4.jpeg",
          "assets/puzzle/level1/5.jpeg",
        ]
      },
      {
        "image": "assets/puzzle/level1/5.jpeg",
        "correct": "assets/puzzle/level1/5.jpeg",
        "options": [
          "assets/puzzle/level1/3.jpeg",
          "assets/puzzle/level1/4.jpeg",
          "assets/puzzle/level1/5.jpeg",
        ]
      },
    ],

    // 🔹 LEVEL 2 — Match Pair Images
    // Big: 1,3,5,7  → Options: 2,4,6,8

    2: [
      {
        "image": "assets/puzzle/level2/1.jpeg",
        "correct": "assets/puzzle/level2/2.jpeg",
        "options": [
          "assets/puzzle/level2/2.jpeg",
          "assets/puzzle/level2/4.jpeg",
          "assets/puzzle/level2/6.jpeg",
        ]
      },
      {
        "image": "assets/puzzle/level2/3.jpeg",
        "correct": "assets/puzzle/level2/4.jpeg",
        "options": [
          "assets/puzzle/level2/2.jpeg",
          "assets/puzzle/level2/4.jpeg",
          "assets/puzzle/level2/8.jpeg",
        ]
      },
      {
        "image": "assets/puzzle/level2/5.jpeg",
        "correct": "assets/puzzle/level2/6.jpeg",
        "options": [
          "assets/puzzle/level2/4.jpeg",
          "assets/puzzle/level2/6.jpeg",
          "assets/puzzle/level2/8.jpeg",
        ]
      },
      {
        "image": "assets/puzzle/level2/7.jpeg",
        "correct": "assets/puzzle/level2/8.jpeg",
        "options": [
          "assets/puzzle/level2/2.jpeg",
          "assets/puzzle/level2/6.jpeg",
          "assets/puzzle/level2/8.jpeg",
        ]
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
    loadRound();
  }

  void loadRound() {
    final data = levels[level]![round - 1];
    correctAnswer = data["correct"];
    options = List<String>.from(data["options"]);
    options.shuffle();
  }

  // ⭐ CHECK ANSWER
  void checkAnswer(String selected) async {
  totalAttempts++;

  if (selected == correctAnswer) {
    correctAnswers++;
    totalRoundsCompleted++;

    double progress = totalRoundsCompleted / 9;
    progress = progress.clamp(0.0, 1.0);

    await updateProgress(progress);

    await evaluateAndReward();

    showSuccessCard();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Try Again")),
    );
  }
}

  // ⭐ SUCCESS POPUP
  void showSuccessCard() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "🎉 Great Job!",
          textAlign: TextAlign.center,
        ),
        content: const Text(
          "Correct Answer!",
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              goToNextRound();
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  // ⭐ NEXT ROUND / LEVEL
  void goToNextRound() async {

  totalRoundsCompleted++;

  double progress = totalRoundsCompleted / 9; // 9 total rounds
  progress = progress.clamp(0.0, 1.0);

  await updateProgress(progress);

  if (round < (levels[level]?.length ?? 0)) {
    setState(() {
      round++;
      loadRound();
    });
  } else {
    goToNextLevel();
  }
}

  void goToNextLevel() {
    if (level < levels.length) {
      setState(() {
        level++;
        round = 1;
        loadRound();
      });
    } else {
      showCompletionDialog();
    }
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

    double accuracy = progress;

    await snapshot.docs.first.reference.update({
      "puzzleProgress": progress,
      "puzzleAccuracy": accuracy,
      "puzzleTime": DateTime.now().difference(startTime).inSeconds,
    });

    // ⭐ CALL YOUR REWARD SYSTEM
    await rewardEngine(accuracy);
  }
}
  // ⭐ FINAL COMPLETION
  void showCompletionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🎉 All Levels Completed"),
        content: const Text("Amazing work!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Back"),
          )
        ],
      ),
    );
  }

  Future<void> evaluateAndReward() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  if (totalRoundsCompleted - lastRewardCheckpoint < 3) return;

  lastRewardCheckpoint = totalRoundsCompleted;

  double accuracy =
      totalAttempts == 0 ? 0 : correctAnswers / totalAttempts;

  int secondsTaken =
      DateTime.now().difference(startTime).inSeconds;

  const int idealTime = 60;

  double speedScore = 1 - (secondsTaken / idealTime);
  speedScore = speedScore.clamp(0.0, 1.0);

  double finalScore =
      (accuracy * 0.7) + (speedScore * 0.3);

  final snapshot = await FirebaseFirestore.instance
      .collection(AppConstants.parentsCollection)
      .doc(user.uid)
      .collection(AppConstants.childrenCollection)
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) return;

  final doc = snapshot.docs.first;

 // Get old puzzle accuracy before overwriting
double oldPuzzle = (doc["puzzleAccuracy"] ?? 0.0).toDouble();

double progress = finalScore;

await updateModuleProgress(
  module: "puzzle",
  progress: progress,
  accuracy: progress,
  timeSpent: DateTime.now().difference(startTime).inSeconds,
);

if (finalScore < 0.7) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Try again to earn a star ⭐"),
    ),
  );
}
}

  @override
  Widget build(BuildContext context) {

    final data = levels[level]![round - 1];

    return Scaffold(
      appBar: AppBar(
        title: Text("Level $level  •  Round $round"),
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // ⭐ Big image
            Image.asset(data["image"], height: 200),

            const SizedBox(height: 40),

            // ⭐ Options
            Wrap(
              spacing: 20,
              children: options.map((option) {
                return GestureDetector(
                  onTap: () => checkAnswer(option),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      option,
                      width: 80,
                      height: 80,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}