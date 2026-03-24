import 'package:flutter/material.dart';
import 'package:socialsteps/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tutorial_video_screen.dart';
import 'child_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int dailyCap = 10;
  bool loading = true;
  String? childId;
  Map<String, dynamic>? childData;

  @override
  void initState() {
    super.initState();
    loadCap();
  }

  Future<void> loadCap() async {
    final parentId = FirebaseAuth.instance.currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(parentId)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      setState(() {
        childId = doc.id;
        childData = doc.data();
        dailyCap = childData?["dailyStarCap"] ?? 10;
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> saveCap() async {
    final parentId = FirebaseAuth.instance.currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(parentId)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update({
        "dailyStarCap": dailyCap,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Daily star limit updated")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // -------------------------
          // 👤 PROFILE SECTION
          // -------------------------
          if (childId != null) ...[
            const Text(
              "Profile Settings",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: const Text("Edit Child Profile"),
                subtitle: Text("Update name, age or avatar"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildProfileScreen(
                        childId: childId,
                        initialData: childData,
                      ),
                    ),
                  ).then((_) => loadCap()); // Refresh on return
                },
              ),
            ),
            const SizedBox(height: 30),
          ],
          // ⭐ DAILY STAR LIMIT SECTION
          // -------------------------

          const Text(
            "Daily Star Limit",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Text(
            "$dailyCap Stars per day",
            style: const TextStyle(fontSize: 16),
          ),

          Slider(
            min: 5,
            max: 20,
            divisions: 15,
            value: dailyCap.toDouble(),
            onChanged: (value) {
              setState(() {
                dailyCap = value.toInt();
              });
            },
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: saveCap,
              child: const Text("Save"),
            ),
          ),

          const SizedBox(height: 40),

          // -------------------------
          // 🎥 WATCH TUTORIALS SECTION
          // -------------------------

          const Text(
            "Watch Tutorials",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          tutorialTile(
            context,
            "Emotion Tutorial",
            "assets/videos/emotion_tutorial.mp4",
          ),

          tutorialTile(
            context,
            "Puzzle Tutorial",
            "assets/videos/puzzle_tutorial.mp4",
          ),

          tutorialTile(
            context,
            "Focus Tutorial",
            "assets/videos/focus_tutorial.mp4",
          ),

          tutorialTile(
            context,
            "Color Tutorial",
            "assets/videos/color_tutorial.mp4",
          ),
        ],
      ),
    );
  }

  // -------------------------
  // 🎬 Tutorial Tile Widget
  // -------------------------

  Widget tutorialTile(
    BuildContext context,
    String title,
    String videoPath,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.play_circle_fill, color: Colors.blue),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TutorialVideoScreen(
                videoPath: videoPath,
                onFinished: () {
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}