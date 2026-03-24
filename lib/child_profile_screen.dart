import 'package:flutter/material.dart';
import 'package:socialsteps/utils/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'auth_screen.dart';
// import 'main.dart';
import 'parent_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChildProfileScreen extends StatefulWidget {
  final String? childId;
  final Map<String, dynamic>? initialData;

  const ChildProfileScreen({super.key, this.childId, this.initialData});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();

  String selectedAvatar = "";

  final List<String> avatar = [
    "assets/avatar/unicorn.jpg",
    "assets/avatar/lion.jpg",
    "assets/avatar/cat.jpg",
    "assets/avatar/panda.jpg",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      nameController.text = widget.initialData!["name"] ?? "";
      ageController.text = (widget.initialData!["age"] ?? "").toString();
      selectedAvatar = widget.initialData!["avatar"] ?? "";
    }
  }

  Future<void> saveChildProfile() async {
    final name = nameController.text.trim();
    final age = ageController.text.trim();

    if (name.isEmpty || age.isEmpty || selectedAvatar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final parentId = FirebaseAuth.instance.currentUser!.uid;

    if (widget.childId != null) {
      // Update existing
      await FirebaseFirestore.instance
          .collection(AppConstants.parentsCollection)
          .doc(parentId)
          .collection(AppConstants.childrenCollection)
          .doc(widget.childId)
          .update({
        "name": name,
        "age": age,
        "avatar": selectedAvatar,
      });
    } else {
      // Add new
      await FirebaseFirestore.instance
          .collection(AppConstants.parentsCollection)
          .doc(parentId)
          .collection(AppConstants.childrenCollection)
          .add({
        "name": name,
        "age": age,
        "avatar": selectedAvatar,
        "stars": 0,
        "dailyStars": 0,
        "dailyStarCap": 10,
        "streak": 0,
        "emotionProgress": 0.0,
        "focusProgress": 0.0,
        "puzzleProgress": 0.0,
        "colorProgress": 0.0,
        "emotionAccuracy": 0.0,
        "focusAccuracy": 0.0,
        "puzzleAccuracy": 0.0,
        "colorAccuracy": 0.0,
        "lastRewardDate": "",
        "lastPlayDate": "",
        "assignedModules": {
          "emotion": true,
          "focus": true,
          "puzzle": true,
          "color": true,
        },
        "emotionTutorialSeen": false,
        "focusTutorialSeen": false,
        "puzzleTutorialSeen": false,
        "colorTutorialSeen": false,
      });
    }

    // Save to SharedPreferences for fast retrieval on dashboard
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('child_name', name);
    await prefs.setString('child_avatar', selectedAvatar);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(widget.childId != null
              ? "Profile Updated 🎉"
              : "Child Profile Created 🎉")),
    );

    Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => const ParentDashboard(),
  ),
);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Create Child Profile")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: SingleChildScrollView(
          child: Column(
            children: [

              const SizedBox(height: 20),

              const Text(
                "Choose an Avatar",
                style: TextStyle(fontSize: 20),
              ),

              const SizedBox(height: 20),

              Wrap(
                spacing: 15,
                children: avatar.map((avatar) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedAvatar = avatar;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedAvatar == avatar
                              ? Colors.blue
                              : Colors.grey,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        avatar,
                        width: 70,
                        height: 70,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Child Name",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Age",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: saveChildProfile,
                child: const Text("Create Child Profile"),
              ),

            ],
          ),
        ),
      ),
    );
  }
}