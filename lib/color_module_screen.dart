import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'adaptive_reward.dart';

class ColorModuleScreen extends StatefulWidget {
  const ColorModuleScreen({super.key});

  @override
  State<ColorModuleScreen> createState() => _ColorModuleScreenState();
}

class _ColorModuleScreenState extends State<ColorModuleScreen> {

  Color? selectedColor;
  bool filled = false;
  int currentIndex = 0;

  int totalAttempts = 0;
  int correctCount = 0;
  int lastRewardCheckpoint = 0;

  late DateTime startTime;

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
  }

  

  final List<Map<String, dynamic>> items = [
    {
      "full": "assets/puzzle/level3/teddy_full.jpeg",
      "blank": "assets/puzzle/level3/teddy_blank.jpeg",
      "color": Colors.red,
    },
    {
      "full": "assets/puzzle/level3/orange_full.jpeg",
      "blank": "assets/puzzle/level3/orange_blank.jpeg",
      "color": Colors.orange,
    },
    {
      "full": "assets/puzzle/level3/car_full.jpeg",
      "blank": "assets/puzzle/level3/car_blank.jpeg",
      "color": Colors.green,
    },
    {
      "full": "assets/puzzle/level3/banana_full.jpeg",
      "blank": "assets/puzzle/level3/banana_blank.jpeg",
      "color": Colors.yellow,
    },
    {
      "full": "assets/puzzle/level3/flower_full.jpeg",
      "blank": "assets/puzzle/level3/flower_blank.jpeg",
      "color": const Color.fromARGB(255, 216, 105, 142),
    },
  ];

  String get fullImage => items[currentIndex]["full"];
  String get blankImage => items[currentIndex]["blank"];
  Color get correctColor => items[currentIndex]["color"];

  void pickColor(Color color) {
    setState(() => selectedColor = color);
  }

  /* -------------------- REWARD SYSTEM -------------------- */

  Future<void> evaluateAndReward() async {

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  if (correctCount - lastRewardCheckpoint < 3) return;

  lastRewardCheckpoint = correctCount;

  double accuracy =
      totalAttempts == 0 ? 0 : correctCount / totalAttempts;

  int secondsTaken =
      DateTime.now().difference(startTime).inSeconds;

  final snapshot = await FirebaseFirestore.instance
      .collection(AppConstants.parentsCollection)
      .doc(user.uid)
      .collection(AppConstants.childrenCollection)
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) return;

  final doc = snapshot.docs.first;

  /// SAVE PERFORMANCE EVERY FEW ROUNDS
  double oldColor = (doc["colorAccuracy"] ?? 0.0).toDouble();

  await doc.reference.update({
    "colorPreviousAccuracy": oldColor,
    "colorAccuracy": accuracy,
    "colorTime": secondsTaken,
  });

  /// STAR REWARD LOGIC
  const int idealTime = 60;

  double speedScore = 1 - (secondsTaken / idealTime);
  speedScore = speedScore.clamp(0.0, 1.0);

  double finalScore =
      (accuracy * 0.7) + (speedScore * 0.3);

  if (finalScore >= 0.7) {

    bool earned = await rewardEngine(accuracy);

    if (!earned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Daily star limit reached 🌙 Come back tomorrow!"),
        ),
      );
    }
  }
  }

  /* -------------------- GAME LOGIC -------------------- */

  void fillObject() async {
    totalAttempts++;

    if (selectedColor == correctColor) {
      correctCount++;

      double progress = correctCount / items.length;
      progress = progress.clamp(0.0, 1.0);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection(AppConstants.parentsCollection)
            .doc(user.uid)
            .collection(AppConstants.childrenCollection)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          await snapshot.docs.first.reference.update({
            "colorProgress": progress,
          });
        }
      }

      await evaluateAndReward();

      setState(() => filled = true);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("🎉 Great Job!"),
          content: const Text("You colored it perfectly!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                if (currentIndex == items.length - 1) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    filled = false;
                    selectedColor = null;
                    currentIndex++;
                  });
                }
              },
              child: const Text("Next"),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Try again")),
      );
    }
  }

  /* -------------------- UI -------------------- */

  Widget colorButton(Color color) {
    return GestureDetector(
      onTap: () => pickColor(color),
      child: Container(
        width: 55,
        height: 55,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(width: 3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Color Activity")),
      body: Column(
        children: [
          const SizedBox(height: 20),

          Image.asset(fullImage, height: 170),

          const SizedBox(height: 20),

          Stack(
            alignment: Alignment.center,
            children: [
              if (!filled)
                Image.asset(blankImage, height: 260),

              if (filled)
                Image.asset(fullImage, height: 260),

              Positioned(
                top: 95,
                left: 110,
                child: GestureDetector(
                  onTap: fillObject,
                  child: Container(
                    width: 110,
                    height: 90,
                    color: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text("Choose a color"),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              colorButton(Colors.red),
              colorButton(Colors.orange),
              colorButton(Colors.green),
              colorButton(Colors.yellow),
              colorButton(
                  const Color.fromARGB(255, 216, 105, 142)),
            ],
          ),
        ],
      ),
    );
  }
}
