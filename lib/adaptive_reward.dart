import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socialsteps/utils/constants.dart';

Future<bool> rewardEngine(double accuracy) async {

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final parentId = user.uid;

  final snapshot = await FirebaseFirestore.instance
      .collection(AppConstants.parentsCollection)
      .doc(parentId)
      .collection(AppConstants.childrenCollection)
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) return false;

  final doc = snapshot.docs.first;
  final data = doc.data();

  int totalStars = data["stars"] ?? 0;
  int dailyStars = data["dailyStars"] ?? 0;
  int dailyCap = data["dailyStarCap"] ?? 10;
  int streak = data["streak"] ?? 0;

  String today = DateTime.now().toIso8601String().split("T").first;

  String? lastRewardDate = data["lastRewardDate"];
  String? lastPlayDate = data["lastPlayDate"];

  /// RESET DAILY STARS
  if (lastRewardDate != today) {
    dailyStars = 0;
  }

  /// STREAK SYSTEM
  if (lastPlayDate == null) {
    streak = 1;
  } 
  else if (lastPlayDate == today) {
    // same day
  } 
  else {
    DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    String yesterdayStr = yesterday.toIso8601String().split("T").first;

    if (lastPlayDate == yesterdayStr) {
      streak += 1;
    } else {
      streak = 1;
    }
  }

  /// DAILY CAP
  if (dailyStars >= dailyCap) {
    await doc.reference.update({
      "lastRewardDate": today,
      "lastPlayDate": today,
      "streak": streak,
    });

    return false;
  }

  /// ADD STAR
  await doc.reference.update({
    "stars": totalStars + 1,
    "dailyStars": dailyStars + 1,
    "lastRewardDate": today,
    "lastPlayDate": today,
    "streak": streak,
  });

  return true;
}

Future<void> updateModuleProgress({
  required String module,
  required double progress,
  required double accuracy,
  required int timeSpent,
}) async {

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final snapshot = await FirebaseFirestore.instance
      .collection(AppConstants.parentsCollection)
      .doc(user.uid)
      .collection(AppConstants.childrenCollection)
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) return;

  final docRef = snapshot.docs.first.reference;

  await docRef.update({
    "${module}Progress": progress,
    "${module}Accuracy": accuracy,
    "${module}Time": timeSpent,
  });

  await rewardEngine(accuracy);
}