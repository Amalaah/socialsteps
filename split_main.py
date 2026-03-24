import os

main_path = r"c:\socialsteps\socialsteps-master\lib\main.dart"
screens_dir = r"c:\socialsteps\socialsteps-master\lib\screens"

with open(main_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

def get_content(start_marker, end_marker=None):
    start_idx = -1
    end_idx = len(lines)
    for i, line in enumerate(lines):
        if start_marker in line:
            start_idx = i
            break
    if start_idx == -1: return ""
    
    if end_marker:
        for i in range(start_idx + 1, len(lines)):
            if end_marker in line:
                end_idx = i
                break
    else:
        # Find next marker if end_marker is None
        for i in range(start_idx + 1, len(lines)):
            if "/* ================= " in line or "// focus screen" in line or "/* ================= REWARD SCREEN" in line:
                end_idx = i
                break
                
    return "".join(lines[start_idx:end_idx]), start_idx, end_idx

child_dashboard_code, cd_start, cd_end = get_content("/* ================= CHILD DASHBOARD")
emotion_code, em_start, em_end = get_content("/* ================= EMOTION MODULE")
focus_code, fo_start, fo_end = get_content("// focus screen")
reward_code, rw_start, rw_end = get_content("/* ================= REWARD SCREEN")

# Write child_dashboard.dart
with open(os.path.join(screens_dir, "child_dashboard.dart"), "w", encoding="utf-8") as f:
    f.write("import 'package:flutter/material.dart';\n")
    f.write("import 'emotion_screen.dart';\n")
    f.write("import 'focus_screen.dart';\n")
    f.write("import 'puzzle_screen.dart';\n")
    f.write("import 'color_module_screen.dart';\n\n")
    f.write(child_dashboard_code)

# Write emotion_screen.dart
with open(os.path.join(screens_dir, "emotion_screen.dart"), "w", encoding="utf-8") as f:
    f.write("import 'package:flutter/material.dart';\n")
    f.write("import 'package:cloud_firestore/cloud_firestore.dart';\n")
    f.write("import 'package:firebase_auth/firebase_auth.dart';\n")
    f.write("import '../services/adaptive_reward.dart';\n\n")
    f.write(emotion_code)

# Write focus_screen.dart
with open(os.path.join(screens_dir, "focus_screen.dart"), "w", encoding="utf-8") as f:
    f.write("import 'dart:math';\n")
    f.write("import 'package:flutter/material.dart';\n")
    f.write("import 'package:cloud_firestore/cloud_firestore.dart';\n")
    f.write("import 'package:firebase_auth/firebase_auth.dart';\n")
    f.write("import '../services/adaptive_reward.dart';\n\n")
    f.write(focus_code)

# Write reward_screen.dart
if reward_code:
    with open(os.path.join(screens_dir, "reward_screen.dart"), "w", encoding="utf-8") as f:
        f.write("import 'package:flutter/material.dart';\n\n")
        f.write(reward_code)

# Update main.dart
if cd_start != -1:
    new_main_lines = lines[:cd_start]
    with open(main_path, "w", encoding="utf-8") as f:
        f.writelines(new_main_lines)

print("Split complete.")
