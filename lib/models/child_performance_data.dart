class ChildPerformanceData {
  final int totalTimeSpent;
  final int totalAttempts;
  final int correctAttempts;
  final double accuracyPercentage;
  final int starsEarned;
  final int modulesCompleted;

  final double emotionAccuracy;
  final double focusAccuracy;
  final double puzzleAccuracy;
  final double colorAccuracy;
  final double socialAccuracy;
  
  final int emotionTime;
  final int focusTime;
  final int puzzleTime;
  final int colorTime;
  final int socialTime;

  ChildPerformanceData({
    required this.totalTimeSpent,
    required this.totalAttempts,
    required this.correctAttempts,
    required this.accuracyPercentage,
    required this.starsEarned,
    required this.modulesCompleted,
    required this.emotionAccuracy,
    required this.focusAccuracy,
    required this.puzzleAccuracy,
    required this.colorAccuracy,
    required this.socialAccuracy,
    required this.emotionTime,
    required this.focusTime,
    required this.puzzleTime,
    required this.colorTime,
    required this.socialTime,
  });

  factory ChildPerformanceData.fromMap(Map<String, dynamic> map) {
    // Safely extract individual accuracies
    double emotion = (map['emotionAccuracy'] as num?)?.toDouble() ?? 0.0;
    double focus = (map['focusAccuracy'] as num?)?.toDouble() ?? 0.0;
    double puzzle = (map['puzzleAccuracy'] as num?)?.toDouble() ?? 0.0;
    double color = (map['colorAccuracy'] as num?)?.toDouble() ?? 0.0;
    double social = (map['socialAccuracy'] as num?)?.toDouble() ?? 0.0;

    // Calculate total time
    int eTime = (map['emotionTime'] as num?)?.toInt() ?? 0;
    int fTime = (map['focusTime'] as num?)?.toInt() ?? 0;
    int pTime = (map['puzzleTime'] as num?)?.toInt() ?? 0;
    int cTime = (map['colorTime'] as num?)?.toInt() ?? 0;
    int sTime = (map['socialTime'] as num?)?.toInt() ?? 0;
    int totalTime = eTime + fTime + pTime + cTime + sTime;

    // Calculate modules completed (progress == 1.0 or accuracy > 0)
    int completed = 0;
    if ((map['emotionProgress'] as num?)?.toDouble() == 1.0) completed++;
    if ((map['focusProgress'] as num?)?.toDouble() == 1.0) completed++;
    if ((map['puzzleProgress'] as num?)?.toDouble() == 1.0) completed++;
    if ((map['colorProgress'] as num?)?.toDouble() == 1.0) completed++;
    if ((map['socialProgress'] as num?)?.toDouble() == 1.0) completed++;

    // Calculate total attempts and correct attempts (approximate or direct if tracked)
    int tAttempts = (map['totalQuestions'] as num?)?.toInt() ?? 0;
    int cAttempts = (map['correctAnswers'] as num?)?.toInt() ?? 0;
    
    // Overall accuracy percentage
    double overallAccuracy = 0.0;
    if (tAttempts > 0) {
      overallAccuracy = cAttempts / tAttempts;
    } else {
      // Fallback: average the module accuracies
      int activeModules = 0;
      double sumAcc = 0.0;
      if (emotion > 0) { sumAcc += emotion; activeModules++; }
      if (focus > 0) { sumAcc += focus; activeModules++; }
      if (puzzle > 0) { sumAcc += puzzle; activeModules++; }
      if (color > 0) { sumAcc += color; activeModules++; }
      if (social > 0) { sumAcc += social; activeModules++; }
      
      if (activeModules > 0) {
        overallAccuracy = sumAcc / activeModules;
      }
    }

    return ChildPerformanceData(
      totalTimeSpent: totalTime,
      totalAttempts: tAttempts,
      correctAttempts: cAttempts,
      accuracyPercentage: overallAccuracy,
      starsEarned: (map['stars'] as num?)?.toInt() ?? 0,
      modulesCompleted: completed,
      emotionAccuracy: emotion,
      focusAccuracy: focus,
      puzzleAccuracy: puzzle,
      colorAccuracy: color,
      socialAccuracy: social,
      emotionTime: eTime,
      focusTime: fTime,
      puzzleTime: pTime,
      colorTime: cTime,
      socialTime: sTime,
    );
  }
}
