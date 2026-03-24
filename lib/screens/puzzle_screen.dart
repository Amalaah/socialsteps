import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/module_state_provider.dart';
import 'reward_screen.dart';
import '../utils/app_theme.dart';
import '../widgets/parental_guard.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({super.key});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {

  int totalRoundsCompleted = 0;
  int totalAttempts = 0;
  int correctAnswers = 0;

  int level = 1;
  int round = 1;
  bool _isCompleted = false;

  late String correctAnswer;
  late List<String> options;

  final Map<int, List<Map<String, dynamic>>> levels = {
    1: [
      {
        "image": "assets/puzzle/level1/1.jpeg",
        "correct": "assets/puzzle/level1/1.jpeg",
        "options": ["assets/puzzle/level1/1.jpeg", "assets/puzzle/level1/2.jpeg", "assets/puzzle/level1/3.jpeg"]
      },
      {
        "image": "assets/puzzle/level1/2.jpeg",
        "correct": "assets/puzzle/level1/2.jpeg",
        "options": ["assets/puzzle/level1/1.jpeg", "assets/puzzle/level1/2.jpeg", "assets/puzzle/level1/3.jpeg"]
      },
      {
        "image": "assets/puzzle/level1/3.jpeg",
        "correct": "assets/puzzle/level1/3.jpeg",
        "options": ["assets/puzzle/level1/3.jpeg", "assets/puzzle/level1/4.jpeg", "assets/puzzle/level1/5.jpeg"]
      },
      {
        "image": "assets/puzzle/level1/4.jpeg",
        "correct": "assets/puzzle/level1/4.jpeg",
        "options": ["assets/puzzle/level1/2.jpeg", "assets/puzzle/level1/4.jpeg", "assets/puzzle/level1/5.jpeg"]
      },
      {
        "image": "assets/puzzle/level1/5.jpeg",
        "correct": "assets/puzzle/level1/5.jpeg",
        "options": ["assets/puzzle/level1/3.jpeg", "assets/puzzle/level1/4.jpeg", "assets/puzzle/level1/5.jpeg"]
      },
    ],
    2: [
      {
        "image": "assets/puzzle/level2/1.jpeg",
        "correct": "assets/puzzle/level2/2.jpeg",
        "options": ["assets/puzzle/level2/2.jpeg", "assets/puzzle/level2/4.jpeg", "assets/puzzle/level2/6.jpeg"]
      },
      {
        "image": "assets/puzzle/level2/3.jpeg",
        "correct": "assets/puzzle/level2/4.jpeg",
        "options": ["assets/puzzle/level2/2.jpeg", "assets/puzzle/level2/4.jpeg", "assets/puzzle/level2/8.jpeg"]
      },
      {
        "image": "assets/puzzle/level2/5.jpeg",
        "correct": "assets/puzzle/level2/6.jpeg",
        "options": ["assets/puzzle/level2/4.jpeg", "assets/puzzle/level2/6.jpeg", "assets/puzzle/level2/8.jpeg"]
      },
      {
        "image": "assets/puzzle/level2/7.jpeg",
        "correct": "assets/puzzle/level2/8.jpeg",
        "options": ["assets/puzzle/level2/2.jpeg", "assets/puzzle/level2/6.jpeg", "assets/puzzle/level2/8.jpeg"]
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(moduleStateProvider.notifier).reset(moduleKey: 'puzzle');
    });
    loadRound();
  }

  void loadRound() {
    final data = levels[level]![round - 1];
    correctAnswer = data["correct"];
    options = List<String>.from(data["options"]);
    options.shuffle();
  }

  void checkAnswer(String selected) async {
    totalAttempts++;

    if (selected == correctAnswer) {
      correctAnswers++;
      totalRoundsCompleted++;

      // Award a star for every 3 correct answers
      final starsEarned = await ref
          .read(moduleStateProvider.notifier)
          .recordAnswerAndReward(true, moduleKey: 'puzzle');

      if (!mounted) return;
      if (starsEarned > 0) {
        // Show full reward screen then continue to next round
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RewardScreen(
              starsJustEarned: starsEarned,
              message: '${ref.read(moduleStateProvider).correctCount} correct so far — keep it up!',
            ),
          ),
        );
        if (!mounted) return;
      }
      showSuccessCard(starsEarned: starsEarned);
    } else {
      ref.read(moduleStateProvider.notifier).recordAnswer(false, moduleKey: 'puzzle');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Try Again")),
      );
    }
  }

  void showSuccessCard({int starsEarned = 0}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          starsEarned > 0 ? "⭐ Star Earned!" : "🎉 Great Job!",
          textAlign: TextAlign.center,
        ),
        content: Text(
          starsEarned > 0
              ? "Correct! +$starsEarned star${starsEarned > 1 ? 's' : ''}!"
              : "Correct! Keep going — star every 3 answers!",
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

  void goToNextRound() async {
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

  void showCompletionDialog() async {
    setState(() => _isCompleted = true);
    final state = ref.read(moduleStateProvider);
    double accuracy = totalAttempts == 0 ? 0 : correctAnswers / totalAttempts;
    int secondsTaken = DateTime.now().difference(state.startTime).inSeconds;

    // Batch save at the end!
    await ref.read(moduleStateProvider.notifier).saveBatchToFirestore(
      moduleKey: "puzzle",
      accuracy: accuracy,
      secondsTaken: secondsTaken,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 All Levels Completed',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Amazing work! You scored $correctAnswers correct answers.',
            style: AppTheme.body),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back to Activities',
                style: TextStyle(color: AppTheme.primaryLt)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = levels[level]![round - 1];

    return ParentalGuard(
      isCompleted: _isCompleted,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
        title: Text('Puzzle  •  Level $level  /  Round $round'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: PageEntry(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Question image ─────────────────────────────
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 20, offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Image.asset(data['image'], height: 200),
                ),
              ),
              const SizedBox(height: 12),
              Text('Which image comes next?', style: AppTheme.body),
              const SizedBox(height: 32),
              // ── Options ────────────────────────────────────
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: options.map((option) {
                  return GestureDetector(
                    onTap: () => checkAnswer(option),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        border: Border.all(
                            color: AppTheme.primaryLt.withOpacity(0.4),
                            width: 2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(option, width: 90, height: 90),
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
