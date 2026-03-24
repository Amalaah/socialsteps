import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:socialsteps/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'activities_screen.dart';
import 'view_progress_screen.dart';
import 'assign_activites_screen.dart';
import 'view_stars_screen.dart';
import 'settings_screen.dart';
import 'ai_service.dart';
import 'tutorial_video_screen.dart';
import 'screens/feedback_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final AIService _aiService = AIService();
  bool _modelLoaded = false;
  String? _childName;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _loadChildName();
    _initializeAI();
  }

  Future<void> _loadChildName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _childName = prefs.getString('child_name');
      _avatarPath = prefs.getString('child_avatar');
    });
  }

  Future<void> _initializeAI() async {
    await _aiService.loadModel();

    if (mounted) {
      setState(() {
        _modelLoaded = true;
      });
    }
  }

  /// PURE AI FUNCTION (NO setState)
 String generateAISuggestion(Map<String, dynamic> data) {
  if (!_modelLoaded) return "Loading AI...";

  double emotion = (data["emotionAccuracy"] ?? 0.0).toDouble();
  double focus = (data["focusAccuracy"] ?? 0.0).toDouble();
  double puzzle = (data["puzzleAccuracy"] ?? 0.0).toDouble();
  double color = (data["colorAccuracy"] ?? 0.0).toDouble();

  double prevEmotion =
      (data["emotionPreviousAccuracy"] ?? emotion).toDouble();
  double prevFocus =
      (data["focusPreviousAccuracy"] ?? focus).toDouble();

  double emotionTrend = emotion - prevEmotion;
  double focusTrend = focus - prevFocus;

  double avgTime = (
    (data["emotionTime"] ?? 0) +
    (data["focusTime"] ?? 0) +
    (data["puzzleTime"] ?? 0) +
    (data["colorTime"] ?? 0)
  ) / 4;

  // 🔥 NORMALIZATION
  avgTime = avgTime / 60;      // scale time
  double streak = (data["streak"] ?? 0).toDouble() / 30;

  int result = _aiService.predictModule(
    emotion,
    focus,
    puzzle,
    color,
    emotionTrend,
    focusTrend,
    avgTime,
    streak,
  );

  switch (result) {
    case 0:
      return "Emotion Recognition";
    case 1:
      return "Focus Training";
    case 2:
      return "Puzzle Matching";
    case 3:
      return "Color Activity";
    default:
      return "Emotion Recognition";
  }
}

  Future<void> checkDailyReset(
    String parentId,
    String childDocId,
    Map<String, dynamic> data,
  ) async {

  final today = DateTime.now();
  final String todayStr =
      "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

  String? lastDate = data["lastPlayedDate"];

  if (lastDate != todayStr) {
    int currentStreak = data["streak"] ?? 0;

    // If yesterday was played, increase streak
    if (lastDate != null) {
      try {
        DateTime lastPlayed = DateTime.parse(lastDate);
        if (today.difference(lastPlayed).inDays == 1) {
          currentStreak += 1;
        } else {
          currentStreak = 1;
        }
      } catch (e) {
        // Fallback for badly formatted historical dates in Firestore like "2026-3-9"
        final parts = lastDate.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]) ?? today.year;
          final month = int.tryParse(parts[1]) ?? today.month;
          final day = int.tryParse(parts[2]) ?? today.day;
          DateTime lastPlayed = DateTime(year, month, day);
          
          if (DateTime(today.year, today.month, today.day)
                  .difference(lastPlayed)
                  .inDays ==
              1) {
            currentStreak += 1;
          } else {
            currentStreak = 1; // broken streak
          }
        } else {
          currentStreak = 1;
        }
      }
    } else {
      currentStreak = 1;
    }

    await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(parentId)
        .collection(AppConstants.childrenCollection)
        .doc(childDocId)
        .update({
      "dailyStars": 0,
      "streak": currentStreak,
      "lastPlayedDate": todayStr,
    });
  }
}

  Future<void> checkAndOpenTutorial(
  String parentId,
  String childId,
  String fieldName,
  String videoPath,
  Widget activityScreen,
) async {

  final doc = await FirebaseFirestore.instance
      .collection(AppConstants.parentsCollection)
      .doc(parentId)
      .collection(AppConstants.childrenCollection)
      .doc(childId)
      .get();

  bool seen = doc.data()?[fieldName] ?? false;

  if (!seen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TutorialVideoScreen(
          videoPath: videoPath,
          onFinished: () async {
            await FirebaseFirestore.instance
                .collection(AppConstants.parentsCollection)
                .doc(parentId)
                .collection(AppConstants.childrenCollection)
                .doc(childId)
                .update({fieldName: true});

            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => activityScreen),
            );
          },
        ),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => activityScreen),
    );
  }
}

  Widget dailyRewardCard(Map<String, dynamic> data) {
    int stars = data["stars"] ?? 0;
    int dailyStars = data["dailyStars"] ?? 0;
    int dailyCap = data["dailyStarCap"] ?? 10;
    int streak = data["streak"] ?? 0;

    String badge;
    if (stars >= 100) {
      badge = "🥇 Gold";
    } else if (stars >= 50) {
      badge = "🥈 Silver";
    } else if (stars >= 20) {
      badge = "🥉 Bronze";
    } else {
      badge = "🌱 Beginner";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.star, size: 60, color: Colors.amber),
          const SizedBox(height: 10),
          Text(
            'Today: $dailyStars / $dailyCap Stars',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text('🔥 $streak Day Streak',
              style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 6),
          Text('Badge: $badge',
              style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Parent Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('child_name');
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.parentsCollection)
            .doc(parentId)
            .collection(AppConstants.childrenCollection)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No child found"));
          }

          final doc = snapshot.data!.docs.first;
final child =
    doc.data() as Map<String, dynamic>;
final childId = doc.id;

// Call reset check
checkDailyReset(parentId, childId, child);

          final suggestion = generateAISuggestion(child);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                if (child["avatar"] != null || _avatarPath != null)
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage(child["avatar"] ?? _avatarPath!),
                    backgroundColor: Colors.transparent,
                  ),

                const SizedBox(height: 10),

                Text(
                  "Hi, ${child["name"] ?? _childName ?? "there"} 👋",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                dailyRewardCard(child),

                const SizedBox(height: 20),

                /// 🤖 AI CARD
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade200,
                        Colors.blue.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.psychology, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text(
                            'Adaptive Therapy Coach',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '🎯 Recommended: $suggestion',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    children: [
                      dashboardCard(
                        context,
                        "View Progress",
                        Icons.bar_chart,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ViewProgressScreen(),
                            ),
                          );
                        },
                      ),
                      dashboardCard(
                        context,
                        "Assign Activities",
                        Icons.assignment,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AssignActivitiesScreen(),
                            ),
                          );
                        },
                      ),
                      dashboardCard(
                        context,
                        "Activities",
                        Icons.games,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ActivitiesScreen(),
                            ),
                          );
                        },
                      ),
                      dashboardCard(
                        context,
                        "Rewards",
                        Icons.star,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ViewStarsScreen(),
                            ),
                          );
                        },
                      ),
                      dashboardCard(
                        context,
                        "Settings",
                        Icons.settings,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      dashboardCard(
                        context,
                        "AI Feedback",
                        Icons.insights_rounded,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const FeedbackScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget dashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.black87),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}