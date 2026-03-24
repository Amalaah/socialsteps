import os
import shutil
import re

lib_dir = r"c:\socialsteps\socialsteps-master\lib"
screens_dir = os.path.join(lib_dir, "screens")
services_dir = os.path.join(lib_dir, "services")
widgets_dir = os.path.join(lib_dir, "widgets")
models_dir = os.path.join(lib_dir, "models")
providers_dir = os.path.join(lib_dir, "providers")

for d in [screens_dir, services_dir, widgets_dir, models_dir, providers_dir]:
    os.makedirs(d, exist_ok=True)

# Move existing screens and services
screens = [
    "activities_screen.dart", "assign_activites_screen.dart", "auth_screen.dart",
    "child_profile_screen.dart", "color_module_screen.dart", "parent_dashboard.dart",
    "puzzle_screen.dart", "settings_screen.dart", "tutorial_video_screen.dart",
    "view_progress_screen.dart", "view_stars_screen.dart"
]

services = ["ai_service.dart", "adaptive_reward.dart"]

for f in screens:
    src = os.path.join(lib_dir, f)
    if os.path.exists(src):
        shutil.move(src, os.path.join(screens_dir, f))

for f in services:
    src = os.path.join(lib_dir, f)
    if os.path.exists(src):
        shutil.move(src, os.path.join(services_dir, f))

# Split main.dart
main_path = os.path.join(lib_dir, "main.dart")
with open(main_path, "r", encoding="utf-8") as file:
    lines = file.readlines()

def get_content(start_marker, end_marker=None):
    start_idx = -1
    for i, line in enumerate(lines):
        if start_marker in line:
            start_idx = i
            break
    if start_idx == -1: return "", -1, -1
    
    end_idx = len(lines)
    if end_marker:
        for i in range(start_idx + 1, len(lines)):
            if end_marker in line:
                end_idx = i
                break
    else:
        for i in range(start_idx + 1, len(lines)):
            if any(marker in line for marker in ["/* ================= ", "// focus screen", "/* ================= REWARD SCREEN"]):
                end_idx = i
                break
                
    return "".join(lines[start_idx:end_idx]), start_idx, end_idx

child_dashboard_code, cd_start, cd_end = get_content("/* ================= CHILD DASHBOARD")
emotion_code, em_start, em_end = get_content("/* ================= EMOTION MODULE")
focus_code, fo_start, fo_end = get_content("// focus screen")
reward_code, rw_start, rw_end = get_content("/* ================= REWARD SCREEN")

if cd_start != -1:
    with open(os.path.join(screens_dir, "child_dashboard.dart"), "w", encoding="utf-8") as f:
        f.write("import 'package:flutter/material.dart';\n")
        f.write("import 'emotion_screen.dart';\n")
        f.write("import 'focus_screen.dart';\n")
        f.write("import 'puzzle_screen.dart';\n")
        f.write("import 'color_module_screen.dart';\n\n")
        f.write(child_dashboard_code)

if em_start != -1:
    with open(os.path.join(screens_dir, "emotion_screen.dart"), "w", encoding="utf-8") as f:
        f.write("import 'package:flutter/material.dart';\n")
        f.write("import 'package:cloud_firestore/cloud_firestore.dart';\n")
        f.write("import 'package:firebase_auth/firebase_auth.dart';\n")
        f.write("import '../services/adaptive_reward.dart';\n\n")
        f.write(emotion_code)

if fo_start != -1:
    with open(os.path.join(screens_dir, "focus_screen.dart"), "w", encoding="utf-8") as f:
        f.write("import 'dart:math';\n")
        f.write("import 'package:flutter/material.dart';\n")
        f.write("import 'package:cloud_firestore/cloud_firestore.dart';\n")
        f.write("import 'package:firebase_auth/firebase_auth.dart';\n")
        f.write("import '../services/adaptive_reward.dart';\n\n")
        f.write(focus_code)

if rw_start != -1:
    with open(os.path.join(screens_dir, "reward_screen.dart"), "w", encoding="utf-8") as f:
        f.write("import 'package:flutter/material.dart';\n\n")
        f.write(reward_code)

if cd_start != -1:
    new_main_lines = lines[:cd_start]
    with open(main_path, "w", encoding="utf-8") as f:
        f.writelines(new_main_lines)

print("Done Refactoring Folders and Extracting Screens.")
