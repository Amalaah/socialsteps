import 'package:cloud_firestore/cloud_firestore.dart';

class TelemetryService {
  /// Logs an anonymous snapshot of user metrics after completing a module.
  /// Converts the child's unified stats into the exact 8 float features
  /// required by the ML model (`train_model.py`) for future retraining.
  static Future<void> logSessionData(Map<String, dynamic> data, String moduleKey) async {
    try {
      double emotion = (data["emotionAccuracy"] ?? 0.0).toDouble();
      double focus = (data["focusAccuracy"] ?? 0.0).toDouble();
      double puzzle = (data["puzzleAccuracy"] ?? 0.0).toDouble();
      double color = (data["colorAccuracy"] ?? 0.0).toDouble();

      double prevEmotion = (data["emotionPreviousAccuracy"] ?? emotion).toDouble();
      double prevFocus = (data["focusPreviousAccuracy"] ?? focus).toDouble();

      double emotionTrend = emotion - prevEmotion;
      double focusTrend = focus - prevFocus;

      double avgTime = ((data["emotionTime"] ?? 0) +
          (data["focusTime"] ?? 0) +
          (data["puzzleTime"] ?? 0) +
          (data["colorTime"] ?? 0)) / 4.0;
      
      avgTime = avgTime / 60.0; // scale time
      double streak = (data["streak"] ?? 0).toDouble() / 30.0;

      List<double> snapshot = [
        emotion,
        focus,
        puzzle,
        color,
        emotionTrend,
        focusTrend,
        avgTime,
        streak
      ];

      int actualChoice = 0; // default emotion
      if (moduleKey == "focus") actualChoice = 1;
      else if (moduleKey == "puzzle") actualChoice = 2;
      else if (moduleKey == "color") actualChoice = 3;

      await FirebaseFirestore.instance.collection("telemetry_logs").add({
        "snapshot": snapshot,
        "actual_choice": actualChoice,
        "timestamp": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Telemetry logging failed: \$e");
    }
  }
}
