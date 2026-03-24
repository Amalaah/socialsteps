import 'package:flutter/material.dart';
import 'package:socialsteps/utils/constants.dart';
import 'package:socialsteps/utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewProgressScreen extends StatelessWidget {
  const ViewProgressScreen({super.key});

  Future<Map<String, dynamic>?> getChildData() async {
    final parentId = FirebaseAuth.instance.currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(parentId)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Child Progress')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: getChildData(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final child = snapshot.data;

          if (child == null) {
            return const Center(
              child: Text("No child profile found"),
            );
          }

          double emotionProgress =
              (child["emotionProgress"] as num?)?.toDouble() ?? 0.0;

          double focusProgress =
              (child["focusProgress"] as num?)?.toDouble() ?? 0.0;

          double puzzleProgress =
              (child["puzzleProgress"] as num?)?.toDouble() ?? 0.0;

          double colorProgress =
              (child["colorProgress"] as num?)?.toDouble() ?? 0.0;
              
          double socialProgress = 
              (child["socialProgress"] as num?)?.toDouble() ?? 0.0;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${child['name'] ?? 'Child'}\'s Progress',
                  style: AppTheme.heading,
                ),
                const SizedBox(height: 4),
                Text('Activity accuracy so far', style: AppTheme.body),
                const SizedBox(height: 24),

                ProgressTile(
                  icon: Icons.extension_rounded,
                  title: 'Matching Objects',
                  subtitle: 'Puzzle activity',
                  percent: puzzleProgress,
                  color: AppTheme.coral,
                ),

                ProgressTile(
                  icon: Icons.palette_rounded,
                  title: 'Coloring Activity',
                  subtitle: 'Color matching',
                  percent: colorProgress,
                  color: AppTheme.primary,
                ),

                ProgressTile(
                  icon: Icons.emoji_emotions_rounded,
                  title: 'Emotion Training',
                  subtitle: 'Emotion recognition',
                  percent: emotionProgress,
                  color: AppTheme.secondary,
                ),

                ProgressTile(
                  icon: Icons.center_focus_strong_rounded,
                  title: 'Focus Training',
                  subtitle: 'Tap the stars',
                  percent: focusProgress,
                  color: AppTheme.mint,
                ),

                ProgressTile(
                  icon: Icons.groups_rounded,
                  title: 'Social Skills',
                  subtitle: 'Gestures and expressions',
                  percent: socialProgress,
                  color: AppTheme.amber,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProgressTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double percent;
  final Color color;

  const ProgressTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (percent * 100).clamp(0, 100).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.label),
                  ],
                ),
              ),
              // ── % badge ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Progress bar ─────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}