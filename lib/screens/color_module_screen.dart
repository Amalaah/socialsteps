import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/module_state_provider.dart';
import 'reward_screen.dart';
import '../utils/app_theme.dart';
import '../widgets/parental_guard.dart';

class ColorModuleScreen extends ConsumerStatefulWidget {
  const ColorModuleScreen({super.key});

  @override
  ConsumerState<ColorModuleScreen> createState() => _ColorModuleScreenState();
}

class _ColorModuleScreenState extends ConsumerState<ColorModuleScreen> {

  Color? selectedColor;
  bool filled = false;
  int currentIndex = 0;

  int totalAttempts = 0;
  int correctCount = 0;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(moduleStateProvider.notifier).reset(moduleKey: 'color');
    });
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

  void fillObject() async {
    totalAttempts++;

    if (selectedColor == correctColor) {
      correctCount++;

      // Award a star for every 3 correct answers
      final starsEarned = await ref
          .read(moduleStateProvider.notifier)
          .recordAnswerAndReward(true, moduleKey: 'color');

      if (!mounted) return;
      setState(() => filled = true);

      if (starsEarned > 0) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RewardScreen(
              starsJustEarned: starsEarned,
              message: '${ref.read(moduleStateProvider).correctCount} colors matched!',
            ),
          ),
        );
        if (!mounted) return;
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(starsEarned > 0 ? "⭐ Star Earned!" : "🎉 Great Job!"),
          content: Text(
            starsEarned > 0
                ? "You colored it! +$starsEarned star${starsEarned > 1 ? 's' : ''}!"
                : "You colored it! Keep going — star every 3!",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                if (currentIndex == items.length - 1) {
                  finishModule(); // End of module
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
      ref.read(moduleStateProvider.notifier).recordAnswer(false, moduleKey: 'color');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Try again")),
      );
    }
  }

  void finishModule() async {
    setState(() => _isCompleted = true);
    final state = ref.read(moduleStateProvider);
    double accuracy = totalAttempts == 0 ? 0 : correctCount / totalAttempts;
    int secondsTaken = DateTime.now().difference(state.startTime).inSeconds;

    // Batch save at the end!
    await ref.read(moduleStateProvider.notifier).saveBatchToFirestore(
      moduleKey: "color",
      accuracy: accuracy,
      secondsTaken: secondsTaken,
    );

    if (!mounted) return;
    Navigator.pop(context); // Pop back to activities list
  }

  Widget colorButton(Color color) {
    final isSelected = selectedColor == color;
    return GestureDetector(
      onTap: () => pickColor(color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: isSelected ? 62 : 52,
        height: isSelected ? 62 : 52,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isSelected ? 0.7 : 0.3),
              blurRadius: isSelected ? 16 : 6,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParentalGuard(
      isCompleted: _isCompleted,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(title: const Text('Color Activity')),
      body: PageEntry(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // ── Reference image ─────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Image.asset(fullImage, height: 150),
            ),
            const SizedBox(height: 16),
            // ── Canvas ──────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Image.asset(
                    filled ? fullImage : blankImage,
                    height: 240,
                  ),
                ),
                if (!filled)
                  Positioned(
                    top: 85,
                    left: 100,
                    child: GestureDetector(
                      onTap: fillObject,
                      child: Container(
                        width: 120, height: 100,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              selectedColor == null
                  ? 'Pick a color below, then tap the picture!'
                  : 'Nice! Now tap the picture to color it in 🎨',
              textAlign: TextAlign.center,
              style: AppTheme.body,
            ),
            const SizedBox(height: 12),
            // ── Color swatches ───────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                colorButton(Colors.red),
                colorButton(Colors.orange),
                colorButton(Colors.green),
                colorButton(Colors.yellow),
                colorButton(const Color.fromARGB(255, 216, 105, 142)),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
