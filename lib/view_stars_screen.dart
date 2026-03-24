import 'package:flutter/material.dart';
import 'package:socialsteps/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class ViewStarsScreen extends StatelessWidget {
  const ViewStarsScreen({super.key});

  String _getLevel(int stars) {
    if (stars >= 50) return 'Master 🏆';
    if (stars >= 25) return 'Achiever 🥇';
    if (stars >= 10) return 'Explorer 🌟';
    return 'Beginner ⭐';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rewards & Performance')),
      // ── StreamBuilder for instant updates ────────────────────────────────
      // Firestore onSnapshot fires every time stars / accuracy fields change,
      // so the reward screen reflects progress immediately whenever any module
      // (including Social Interaction) calls _runRewardEngine or
      // saveBatchToFirestore.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.parentsCollection)
            .doc(user.uid)
            .collection(AppConstants.childrenCollection)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No child found'));
          }

          final data =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;

          final int stars        = data['stars']        ?? 0;

          final double emotionAcc  = (data['emotionAccuracy']  ?? 0.0).toDouble();
          final int    emotionTime = data['emotionTime']  ?? 0;

          final double focusAcc    = (data['focusAccuracy']    ?? 0.0).toDouble();
          final int    focusTime   = data['focusTime']    ?? 0;

          final double puzzleAcc   = (data['puzzleAccuracy']   ?? 0.0).toDouble();
          final int    puzzleTime  = data['puzzleTime']   ?? 0;

          final double colorAcc    = (data['colorAccuracy']    ?? 0.0).toDouble();
          final int    colorTime   = data['colorTime']    ?? 0;

          final double socialAcc   = (data['socialAccuracy']   ?? 0.0).toDouble();
          final int    socialTime  = data['socialTime']   ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Stars badge ─────────────────────────────────────────
                const Icon(Icons.star, size: 100, color: Colors.amber),
                const SizedBox(height: 10),
                Text(
                  '$stars Stars',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Level: ${_getLevel(stars)}',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),

                const SizedBox(height: 30),

                // ── Bar chart (all 5 modules) ────────────────────────────
                _PerformanceChart(
                  values: [
                    emotionAcc, focusAcc, puzzleAcc, colorAcc, socialAcc
                  ],
                ),

                const SizedBox(height: 30),

                // ── Per-module performance cards ────────────────────────
                _PerformanceCard(
                    title: 'Emotion Recognition',
                    accuracy: emotionAcc,
                    time: emotionTime),
                _PerformanceCard(
                    title: 'Focus Training',
                    accuracy: focusAcc,
                    time: focusTime),
                _PerformanceCard(
                    title: 'Puzzle Matching',
                    accuracy: puzzleAcc,
                    time: puzzleTime),
                _PerformanceCard(
                    title: 'Color Activity',
                    accuracy: colorAcc,
                    time: colorTime),
                // Social Interaction card — shows 0% until module is played
                _PerformanceCard(
                    title: 'Social Interaction',
                    accuracy: socialAcc,
                    time: socialTime),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Bar chart widget ─────────────────────────────────────────────────────────

class _PerformanceChart extends StatelessWidget {
  final List<double> values; // [emotion, focus, puzzle, color, social]

  const _PerformanceChart({required this.values});

  static const _labels = [
    'Emotion', 'Focus', 'Puzzle', 'Color', 'Social'
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  interval: 20,
                  reservedSize: 38),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  return i >= 0 && i < _labels.length
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_labels[i],
                              style: const TextStyle(fontSize: 10)),
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
          barGroups: List.generate(
            values.length,
            (i) => BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (values[i] * 100).clamp(0, 100),
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                  color: _barColor(i),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _barColor(int index) {
    const colors = [
      Color(0xFF7C5CBF), // violet  – Emotion
      Color(0xFF52D9B5), // mint    – Focus
      Color(0xFFFF8B64), // coral   – Puzzle
      Color(0xFF48CAE4), // sky     – Color
      Color(0xFF52D9B5), // mint    – Social (gradient start)
    ];
    return colors[index % colors.length];
  }
}

// ─── Performance card widget ──────────────────────────────────────────────────

class _PerformanceCard extends StatelessWidget {
  final String title;
  final double accuracy;
  final int time;

  const _PerformanceCard({
    required this.title,
    required this.accuracy,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 4),
            Text('Time: ${time}s'),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: accuracy.clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }
}