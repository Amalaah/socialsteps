import 'package:flutter/material.dart';
import 'package:socialsteps/utils/constants.dart';
import 'package:socialsteps/utils/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/color_module_screen.dart';
import 'screens/social_module_screen.dart';
import 'tutorial_video_screen.dart';
import 'screens/puzzle_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/emotion_screen.dart';
import 'main.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {

  Future<void> checkAndOpenTutorial(
    String fieldName,
    String videoPath,
    Widget activityScreen, {
    String? buttonText,
  }) async {
    final parentId = FirebaseAuth.instance.currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(parentId)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return;

    final doc     = snapshot.docs.first;
    final childId = doc.id;
    bool seen     = doc.data()[fieldName] ?? false;

    if (!seen) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TutorialVideoScreen(
            videoPath: videoPath,
            buttonText: buttonText,
            onFinished: () async {
              await FirebaseFirestore.instance
                  .collection(AppConstants.parentsCollection)
                  .doc(parentId)
                  .collection(AppConstants.childrenCollection)
                  .doc(childId)
                  .update({fieldName: true});

              if (!mounted) return;
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => activityScreen),
              );
            },
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => activityScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(AppConstants.parentsCollection)
              .doc(parentId)
              .collection(AppConstants.childrenCollection)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }

            final child   = snapshot.data!.docs.first.data() as Map<String, dynamic>;
            final modules = (child['assignedModules'] ?? {}) as Map<String, dynamic>;
            final name    = (child['name'] ?? 'there') as String;
            final stars   = (child['stars']  ?? 0) as int;

            final activities = [
              if (modules['puzzle'] == true)
                _ActivityDef(
                  emoji: '🧩',
                  title: 'Puzzle',
                  subtitle: 'Match & solve',
                  gradient: AppTheme.activityGradients[2],
                  onTap: () => checkAndOpenTutorial(
                    'puzzleTutorialSeen',
                    'assets/videos/puzzle_tutorial.mp4',
                    const PuzzleScreen(),
                  ),
                ),
              if (modules['emotion'] == true)
                _ActivityDef(
                  emoji: '😊',
                  title: 'Emotions',
                  subtitle: 'Identify feelings',
                  gradient: AppTheme.activityGradients[0],
                  onTap: () => checkAndOpenTutorial(
                    'tutorialSeenEmotion',
                    'assets/videos/emotion_tutorial.mp4',
                    const EmotionScreen(),
                    buttonText: 'Start Activity',
                  ),
                ),
              if (modules['focus'] == true)
                _ActivityDef(
                  emoji: '⭐',
                  title: 'Focus',
                  subtitle: 'Tap the stars',
                  gradient: AppTheme.activityGradients[1],
                  onTap: () => checkAndOpenTutorial(
                    'focusTutorialSeen',
                    'assets/videos/focus_tutorial.mp4',
                    const FocusScreen(),
                  ),
                ),
              if (modules['color'] == true)
                _ActivityDef(
                  emoji: '🎨',
                  title: 'Colors',
                  subtitle: 'Fill & match',
                  gradient: AppTheme.activityGradients[3],
                  onTap: () => checkAndOpenTutorial(
                    'tutorialSeenColor',
                    'assets/videos/color_tutorial.mp4',
                    const ColorModuleScreen(),
                    buttonText: 'Start Activity',
                  ),
                ),
              if (modules['social'] == true)
                _ActivityDef(
                  emoji: '🤝',
                  title: 'Social Skills',
                  subtitle: 'Greet & connect',
                  gradient: AppTheme.activityGradients[4],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SocialModuleScreen(),
                    ),
                  ),
                ),
            ];

            return PageEntry(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ─────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, $name! 👋',
                                style: AppTheme.heading,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'What would you like to do today?',
                                style: AppTheme.body,
                              ),
                            ],
                          ),
                        ),
                        // Star badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: AppTheme.amber.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppTheme.amber, size: 20),
                              const SizedBox(width: 5),
                              Text(
                                '$stars',
                                style: const TextStyle(
                                  color: AppTheme.amber,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    Text('Activities', style: AppTheme.subheading),
                    const SizedBox(height: 16),

                    if (activities.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(
                            children: [
                              const Text('🌟',
                                  style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text(
                                'No activities assigned yet.\nAsk your therapist to set some up!',
                                textAlign: TextAlign.center,
                                style: AppTheme.body,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.0,
                          children: activities
                              .map((a) => ActivityCard(
                                    emoji:    a.emoji,
                                    title:    a.title,
                                    subtitle: a.subtitle,
                                    gradient: a.gradient,
                                    onTap:    a.onTap,
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActivityDef {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActivityDef({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
}