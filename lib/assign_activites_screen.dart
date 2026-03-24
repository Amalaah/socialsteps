import 'package:flutter/material.dart';
import 'package:socialsteps/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AssignActivitiesScreen extends StatefulWidget {
  const AssignActivitiesScreen({super.key});

  @override
  State<AssignActivitiesScreen> createState() =>
      _AssignActivitiesScreenState();
}

class _AssignActivitiesScreenState
    extends State<AssignActivitiesScreen> {

  Map<String, bool> assignedModules = {
    'emotion': false,
    'focus':   false,
    'puzzle':  false,
    'color':   false,
    'social':  false,
  };

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadExistingAssignments();
  }

  Future<void> loadExistingAssignments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(user.uid)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      if (data['assignedModules'] != null) {
        // Merge with defaults so new keys like 'social' appear even for old docs
        final saved = Map<String, bool>.from(data['assignedModules']);
        assignedModules = {...assignedModules, ...saved};
      }
    }

    setState(() => loading = false);
  }

  Future<void> saveAssignments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.parentsCollection)
        .doc(user.uid)
        .collection(AppConstants.childrenCollection)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update({
        "assignedModules": assignedModules,
      });
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Assignments Saved")),
    );
  }

  Widget moduleCard(String key, String title, IconData icon) {
    bool selected = assignedModules[key] ?? false;

    return GestureDetector(
      onTap: () {
        setState(() {
          assignedModules[key] = !selected;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blue.shade100
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(title),
            const SizedBox(height: 10),
            Icon(
              selected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: selected ? Colors.green : Colors.grey,
            )
          ],
        ),
      ),
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
      appBar: AppBar(title: const Text("Assign Activities")),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [

                  moduleCard(
                    'emotion',
                    'Emotion Training',
                    Icons.emoji_emotions,
                  ),

                  moduleCard(
                    'focus',
                    'Focus Training',
                    Icons.center_focus_strong,
                  ),

                  moduleCard(
                    'puzzle',
                    'Puzzle Matching',
                    Icons.extension,
                  ),

                  moduleCard(
                    'color',
                    'Color Activity',
                    Icons.color_lens,
                  ),

                  moduleCard(
                    'social',
                    'Social Skills',
                    Icons.people_rounded,
                  ),
                ],
              ),
            ),

            ElevatedButton(
              onPressed: saveAssignments,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
}