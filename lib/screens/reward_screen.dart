import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/module_state_provider.dart';

class RewardScreen extends ConsumerStatefulWidget {
  /// How many new stars were just earned (shown in the header banner).
  final int starsJustEarned;
  final String message;

  const RewardScreen({
    super.key,
    required this.message,
    this.starsJustEarned = 1,
  });

  @override
  ConsumerState<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends ConsumerState<RewardScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double>   _scale;
  late Animation<double>   _fade;
  Timer? _ticker;   // drives the live elapsed-time display

  // ── Level helpers ──────────────────────────────────────────────────────────

  static const List<Map<String, dynamic>> _levels = [
    {'name': 'Beginner',  'threshold': 0,  'next': 10,  'color': 0xFF9E9E9E},
    {'name': 'Explorer',  'threshold': 10, 'next': 25,  'color': 0xFF42A5F5},
    {'name': 'Achiever',  'threshold': 25, 'next': 50,  'color': 0xFF66BB6A},
    {'name': 'Master',    'threshold': 50, 'next': 100, 'color': 0xFFFFA726},
  ];

  Map<String, dynamic> _levelFor(int stars) {
    for (int i = _levels.length - 1; i >= 0; i--) {
      if (stars >= (_levels[i]['threshold'] as int)) return _levels[i];
    }
    return _levels.first;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    // Tick every second so the elapsed-time card updates without Firestore reads
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Live data from providers ───────────────────────────────────────────
    final sessionState = ref.watch(moduleStateProvider);
    final childDoc     = ref.watch(childDocProvider);

    final Map<String, dynamic> doc = childDoc.valueOrNull ?? {};

    final int   stars    = (doc['stars']  ?? 0) as int;
    final int   streak   = (doc['streak'] ?? 0) as int;
    final int   elapsedS = sessionState.elapsedSeconds;          // live from provider
    final double accuracy = sessionState.accuracy;                // live from provider

    final level = _levelFor(stars);
    final int    levelStars = stars - (level['threshold'] as int);
    final int    levelRange = (level['next']       as int) - (level['threshold'] as int);
    final double progress   = (levelStars / levelRange).clamp(0.0, 1.0);
    final Color  accent     = Color(level['color'] as int);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: childDoc.isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Column(
                    children: [
                      // ── New star banner ──────────────────────────────────
                      FadeTransition(
                        opacity: _fade,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '+${widget.starsJustEarned} ⭐  star${widget.starsJustEarned > 1 ? 's' : ''} earned!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Animated trophy ──────────────────────────────────
                      ScaleTransition(
                        scale: _scale,
                        child: Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              Colors.amber.shade300,
                              Colors.amber.shade700,
                            ]),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.5),
                                blurRadius: 30, spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.emoji_events_rounded,
                              size: 80, color: Colors.white),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Headline ─────────────────────────────────────────
                      FadeTransition(
                        opacity: _fade,
                        child: const Text(
                          'Great Job! 🎉',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── 4-stat grid: stars · streak · accuracy · time ───
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _StatCard(
                            icon: Icons.star_rounded,
                            iconColor: Colors.amber,
                            label: 'Total Stars',
                            value: '$stars',
                          ),
                          _StatCard(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: Colors.deepOrange,
                            label: 'Day Streak',
                            value: '$streak',
                          ),
                          _StatCard(
                            icon: Icons.track_changes_rounded,
                            iconColor: Colors.greenAccent,
                            label: 'Accuracy',
                            // Provider-computed, no local recalculation
                            value: '${(accuracy * 100).toInt()}%',
                          ),
                          _StatCard(
                            icon: Icons.timer_rounded,
                            iconColor: Colors.lightBlueAccent,
                            label: 'Time',
                            // Ticks every second via _ticker
                            value: _formatTime(elapsedS),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Level progress card ──────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: accent.withOpacity(0.4), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: accent, width: 1),
                                  ),
                                  child: Text(
                                    level['name'] as String,
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$levelStars / $levelRange stars',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(accent),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              progress >= 1.0
                                  ? '🎖️  Level complete!'
                                  : '${((1 - progress) * levelRange).ceil()} stars to next level',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Keep Going button ────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: Colors.amber.withOpacity(0.4),
                          ),
                          child: const Text(
                            'Keep Going!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
