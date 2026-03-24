import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../utils/app_theme.dart';
import '../models/child_performance_data.dart';
import '../widgets/performance_charts.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  Future<Map<String, dynamic>?> _getChildData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(user.uid)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.data();
    }
    return null;
  }

  /// Generates heuristic-based text feedback summarizing accuracy
  String _generateFeedback(ChildPerformanceData data, bool isWeekly) {
    String timeframeCap = isWeekly ? "This week" : "This month";
    
    // Map of modules and their accuracies for sorting
    Map<String, double> moduleAccuracies = {
      "Emotion Recognition": data.emotionAccuracy,
      "Focus Training": data.focusAccuracy,
      "Matching Objects": data.puzzleAccuracy,
      "Color Recognition": data.colorAccuracy,
      "Social Interactions": data.socialAccuracy,
    };

    // Filter out unplayed modules (accuracy == 0 and attempts == 0 implies unplayed, but we'll use > 0 for active tracking)
    var activeModules = moduleAccuracies.entries.where((e) => e.value > 0.0).toList();
    activeModules.sort((a, b) => b.value.compareTo(a.value)); // Descending order

    String strongestModule = activeModules.isNotEmpty ? activeModules.first.key : "Exploring Modules";
    String weakestModule = activeModules.isNotEmpty ? activeModules.last.key : "Exploring Modules";
    
    // Default encouraging baseline
    String feedback = "$timeframeCap, your child has done a wonderful job engaging with the learning modules! They have earned **${data.starsEarned} total stars** and completed **${data.modulesCompleted} modules** so far. Here is a supportive overview of their progress:\n\n";

    // 1. STRENGTHS
    feedback += "**Strengths**\n";
    if (activeModules.isEmpty) {
      if (data.totalAttempts == 0) {
        feedback += "• They haven't played enough yet to determine clear strengths. Have them try a few modules at their own pace!\n";
      } else {
        feedback += "• They are building their foundational skills across all areas steadily. Every bit of engagement is a win!\n";
      }
    } else {
      feedback += "• **Top Performing Area:** They are doing exceptionally well in **$strongestModule** (${(activeModules.first.value * 100).toInt()}% accuracy).\n";
      
      // Additional strengths > 75%
      var strengths = activeModules.where((e) => e.value >= 0.75 && e.key != strongestModule).toList();
      if (strengths.isNotEmpty) {
        feedback += "• They also show wonderful consistency in ${strengths.map((e) => e.key).join(' and ')}.\n";
      }
      
      if (strongestModule == "Emotion Recognition") {
        feedback += "• They have a great ability to identify and match facial expressions, which is a fantastic step for social comprehension.\n";
      } else if (strongestModule == "Focus Training") {
        feedback += "• Their reaction time and sustained attention span are notably high. This is excellent for task completion!\n";
      } else if (strongestModule == "Matching Objects" || strongestModule == "Color Recognition") {
        feedback += "• Their visual categorization and matching skills are beautifully developed.\n";
      } else if (strongestModule == "Social Interactions") {
        feedback += "• They are doing great with eye contact and gestural prompts, showing strong interactive engagement.\n";
      }
    }
    feedback += "\n";

    // 2. NEEDS IMPROVEMENT
    feedback += "**Needs Improvement**\n";
    var improvements = activeModules.where((e) => e.value < 0.6).toList();
    
    if (improvements.isEmpty) {
      feedback += "• They are doing consistently well across the board! They seem very comfortable with the current challenges.\n";
    } else {
      feedback += "• **Current Challenge:** They seem to find **$weakestModule** a bit more challenging right now (${(activeModules.last.value * 100).toInt()}% accuracy).\n";
      
      if (weakestModule == "Focus Training") {
        feedback += "• It’s completely normal for attention to wander. We can build this up gradually over time.\n";
      } else if (weakestModule == "Social Interactions") {
        feedback += "• Camera-based interaction can sometimes feel abstract or overwhelming. Taking it slow is perfectly fine.\n";
      } else if (weakestModule == "Emotion Recognition") {
        feedback += "• Reading expressions takes time and practice. They are doing their best to map these concepts.\n";
      }
    }
    feedback += "\n";

    // 3. RECOMMENDATIONS
    feedback += "**Recommendations**\n";
    if (isWeekly) {
      feedback += "• **Keep sessions short**: Aim for just 5-10 minutes a day. Brief, positive interactions prevent sensory fatigue and keep learning fun.\n";
      if (improvements.isNotEmpty) {
        feedback += "• **Targeted Practice**: Try playing **$weakestModule** together tomorrow. Cheer enthusiastically for any attempt, even if it's not perfectly correct!\n";
        if (weakestModule != strongestModule) {
           feedback += "• **Confidence Boost**: After a tricky session, switch back to **$strongestModule** so they end playtime feeling successful and empowered.\n";
        }
      } else {
        feedback += "• **Celebrate!**: They had a beautifully engaged week. Celebrate their star count to build positive reinforcement routines.\n";
      }
    } else {
      feedback += "• **Consistency is Key**: Over the month, regular play builds strong, predictable pathways which are very comforting and effective.\n";
      if (improvements.isNotEmpty && improvements.any((e) => e.key == "Social Interactions")) {
        feedback += "• **Help with Social Module**: Try sitting next to them and exaggerating your own expressions (like smiling wide or waving playfully) so they can safely mirror you in person.\n";
      } else {
        feedback += "• **Gradual Independence**: Since they are progressing well, let them tackle the modules with slightly less hand-over-hand assistance to foster independence.\n";
      }
    }

    return feedback;
  }

  /// Generates dynamic bullet-pointed insights based on performance data
  List<String> _getAIInsights(ChildPerformanceData data) {
    List<String> insights = [];

    // 1. Strongest/Weakest Module
    Map<String, double> accuracies = {
      "Emotion Recognition": data.emotionAccuracy,
      "Focus Training": data.focusAccuracy,
      "Matching Objects": data.puzzleAccuracy,
      "Color Recognition": data.colorAccuracy,
      "Social Interactions": data.socialAccuracy,
    };

    var activeModules = accuracies.entries.where((e) => e.value > 0).toList();
    if (activeModules.isNotEmpty) {
      activeModules.sort((a, b) => b.value.compareTo(a.value));
      insights.add("Building Mastery: **${activeModules.first.key}** is currently their strongest area with ${(activeModules.first.value * 100).toInt()}% accuracy.");
      
      if (activeModules.length > 1) {
        var weakest = activeModules.last;
        insights.add("Growth Opportunity: **${weakest.key}** needs a bit more focus to improve consistency.");
      }
    } else {
      insights.add("Getting Started: Keep exploring different modules to identify your child's natural strengths!");
    }

    // 2. Engagement Level
    String engagement;
    if (data.totalTimeSpent > 3600) {
      engagement = "High";
    } else if (data.totalTimeSpent > 1800) {
      engagement = "Steady";
    } else if (data.totalTimeSpent > 0) {
      engagement = "Emerging";
    } else {
      engagement = "Starting";
    }
    insights.add("Engagement: Their interaction level is **$engagement**, with a total of **${(data.totalTimeSpent / 60).toStringAsFixed(1)} minutes** spent learning.");

    // 3. Improvement Trends
    if (data.accuracyPercentage >= 0.8) {
      insights.add("Excellence: They are maintaining a very high overall accuracy of **${(data.accuracyPercentage * 100).toInt()}%**.");
    } else if (data.accuracyPercentage >= 0.6) {
      insights.add("Solid Progress: They are showing consistent improvement across most modules.");
    } else if (data.totalAttempts > 0) {
      insights.add("Persistence: They are putting in great effort! Focus on completing easier levels to build confidence.");
    }

    // 4. Milestone
    if (data.modulesCompleted > 0) {
       insights.add("Milestone: They have already successfully completed **${data.modulesCompleted} out of 5** modules!");
    }

    return insights;
  }

  /// Generates supportive, actionable suggestions for parents
  List<Map<String, String>> _getParentSuggestions(ChildPerformanceData data) {
    List<Map<String, String>> suggestions = [];

    // Map modules to skills for better context
    Map<String, String> moduleToSkill = {
      "Emotion Recognition": "Social-Emotional Skills",
      "Focus Training": "Attention & Focus",
      "Matching Objects": "Visual-Spatial Reasoning",
      "Color Recognition": "Identification Skills",
      "Social Interactions": "Social Engagement",
    };

    Map<String, double> accuracies = {
      "Emotion Recognition": data.emotionAccuracy,
      "Focus Training": data.focusAccuracy,
      "Matching Objects": data.puzzleAccuracy,
      "Color Recognition": data.colorAccuracy,
      "Social Interactions": data.socialAccuracy,
    };

    var activeModules = accuracies.entries.where((e) => e.value > 0).toList();
    activeModules.sort((a, b) => b.value.compareTo(a.value));

    // 1. Support Strengths
    if (activeModules.isNotEmpty) {
      var strongest = activeModules.first;
      suggestions.add({
        "title": "Celebrate Success!",
        "content": "Your child is showing wonderful natural ability in **${strongest.key}**. You can reinforce their **${moduleToSkill[strongest.key]}** by offering verbal praise whenever they finish a level!",
        "type": "strength"
      });
    }

    // 2. Targeted Practice
    var unplayed = accuracies.entries.where((e) => e.value == 0).toList();
    if (unplayed.isNotEmpty) {
      var next = unplayed.first;
      suggestions.add({
        "title": "Try Something New",
        "content": "Whenever they feel ready, consider introducing **${next.key}** together. This will help build their **${moduleToSkill[next.key]}** in a gentle, supportive way.",
        "type": "practice"
      });
    } else if (activeModules.length > 1) {
      var weakest = activeModules.last;
      suggestions.add({
        "title": "Gentle Reinforcement",
        "content": "Since **${weakest.key}** feels a bit trickier right now, try playing it together for just 2-3 minutes. Small, successful sessions build great confidence in **${moduleToSkill[weakest.key]}**.",
        "type": "reinforcement"
      });
    }

    // 3. General ASD-friendly advice
    suggestions.add({
      "title": "Learning Tip",
      "content": "Consistency and routine are very comforting. Try to keep the learning environment calm and free from distractions to help them stay focused and happy.",
      "type": "tip"
    });

    return suggestions;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          title: const Text('AI Feedback'),
          bottom: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.black54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: "Weekly Feedback"),
              Tab(text: "Monthly Feedback"),
            ],
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _getChildData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text("No child profile found to generate feedback."));
            }

            final childData = snapshot.data!;
            final perfData = ChildPerformanceData.fromMap(childData);
            
            final weeklyText = _generateFeedback(perfData, true);
            final monthlyText = _generateFeedback(perfData, false);
            final insights = _getAIInsights(perfData);
            final suggestions = _getParentSuggestions(perfData);

            return TabBarView(
              children: [
                _FeedbackTab(text: weeklyText, data: perfData, insights: insights, suggestions: suggestions),
                _FeedbackTab(text: monthlyText, data: perfData, insights: insights, suggestions: suggestions),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  final String text;
  final ChildPerformanceData data;
  final List<String> insights;
  final List<Map<String, String>> suggestions;

  const _FeedbackTab({
    required this.text, 
    required this.data, 
    required this.insights,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    // Basic Markdown bullet rendering wrapper
    final lines = text.split('\n');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Charts Section
            const Text(
              "Performance Insights",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            
            // Completion Gauge and Time Pie Chart in a Row or Stack
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: CompletionGauge(completed: data.modulesCompleted, total: 5)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: TimePieChart(data: data)),
              ],
            ),
            
            const SizedBox(height: 32),
            AccuracyBarChart(data: data),
            
            const SizedBox(height: 40),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 24),

            // AI Insights Section
            const Text(
              "AI Insights",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 16, height: 1.5, color: AppTheme.textSecondary),
                        children: _parseBoldText(insight),
                      ),
                    ),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 32),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 24),

            // Supportive Suggestions Section
            const Text(
              "Supportive Suggestions",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...suggestions.map((suggestion) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getSuggestionColor(suggestion['type']!).withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: _getSuggestionColor(suggestion['type']!).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getSuggestionIcon(suggestion['type']!), size: 20, color: _getSuggestionColor(suggestion['type']!)),
                      const SizedBox(width: 8),
                      Text(
                        suggestion['title']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getSuggestionColor(suggestion['type']!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textSecondary),
                      children: _parseBoldText(suggestion['content']!),
                    ),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 32),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 24),
            
            const Text(
              "Key Takeaways",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            
            ...lines.map((line) {
              if (line.trim().isEmpty) {
                return const SizedBox(height: 12);
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                    children: _parseBoldText(line),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Helper to parse "**text**" into TextSpans
  List<TextSpan> _parseBoldText(String line) {
    List<TextSpan> spans = [];
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final match in boldRegex.allMatches(line)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
      ));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastMatchEnd)));
    }
    return spans;
  }

  Color _getSuggestionColor(String type) {
    switch (type) {
      case 'strength': return Colors.green;
      case 'practice': return Colors.blue;
      case 'reinforcement': return Colors.orange;
      case 'tip': return AppTheme.primary;
      default: return AppTheme.textSecondary;
    }
  }

  IconData _getSuggestionIcon(String type) {
    switch (type) {
      case 'strength': return Icons.auto_awesome;
      case 'practice': return Icons.rocket_launch;
      case 'reinforcement': return Icons.psychology;
      case 'tip': return Icons.lightbulb;
      default: return Icons.info;
    }
  }
}
