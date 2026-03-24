import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/child_performance_data.dart';
import '../utils/app_theme.dart';

class AccuracyBarChart extends StatelessWidget {
  final ChildPerformanceData data;

  const AccuracyBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Module Accuracy",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1.5,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 100,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const style = TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      );
                      switch (value.toInt()) {
                        case 0: return const Text('E', style: style);
                        case 1: return const Text('F', style: style);
                        case 2: return const Text('P', style: style);
                        case 3: return const Text('C', style: style);
                        case 4: return const Text('S', style: style);
                        default: return const Text('');
                      }
                    },
                    reservedSize: 30,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                _makeGroupData(0, data.emotionAccuracy * 100, AppTheme.primary),
                _makeGroupData(1, data.focusAccuracy * 100, Colors.orange),
                _makeGroupData(2, data.puzzleAccuracy * 100, Colors.green),
                _makeGroupData(3, data.colorAccuracy * 100, Colors.blue),
                _makeGroupData(4, data.socialAccuracy * 100, Colors.purple),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            "E: Emotion | F: Focus | P: Puzzle | C: Color | S: Social",
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100,
            color: AppTheme.border.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

class TimePieChart extends StatelessWidget {
  final ChildPerformanceData data;

  const TimePieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    bool hasData = data.totalTimeSpent > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Time Distribution",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 1.5,
          child: hasData
              ? PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      _makeSection(data.emotionTime.toDouble(), "Emotion", AppTheme.primary),
                      _makeSection(data.focusTime.toDouble(), "Focus", Colors.orange),
                      _makeSection(data.puzzleTime.toDouble(), "Puzzle", Colors.green),
                      _makeSection(data.colorTime.toDouble(), "Color", Colors.blue),
                      _makeSection(data.socialTime.toDouble(), "Social", Colors.purple),
                    ],
                  ),
                )
              : const Center(child: Text("No data yet")),
        ),
      ],
    );
  }

  PieChartSectionData _makeSection(double value, String title, Color color) {
    return PieChartSectionData(
      color: color,
      value: value,
      title: value > 0 ? title : '',
      radius: 50,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

class CompletionGauge extends StatelessWidget {
  final int completed;
  final int total;

  const CompletionGauge({super.key, required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                value: completed / total,
                strokeWidth: 10,
                backgroundColor: AppTheme.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            Column(
              children: [
                Text(
                  "$completed/$total",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Text(
                  "Modules",
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          "Overall Completion",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
