import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  final lines = file.readAsLinesSync();

  int cdStart = -1, emStart = -1, foStart = -1, rwStart = -1;

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('/* ================= CHILD DASHBOARD')) cdStart = i;
    if (lines[i].contains('/* ================= EMOTION MODULE')) emStart = i;
    if (lines[i].contains('// focus screen')) foStart = i;
    if (lines[i].contains('/* ================= REWARD SCREEN')) rwStart = i;
  }

  Directory('lib/screens').createSync(recursive: true);
  Directory('lib/services').createSync(recursive: true);

  if (cdStart != -1 && emStart != -1) {
    var cdLines = lines.sublist(cdStart, emStart);
    File('lib/screens/child_dashboard.dart').writeAsStringSync('''
import 'package:flutter/material.dart';
import 'emotion_screen.dart';
import 'focus_screen.dart';
import 'puzzle_screen.dart';
import 'color_module_screen.dart';

${cdLines.join('\n')}
''');
  }

  if (emStart != -1 && foStart != -1) {
    var emLines = lines.sublist(emStart, foStart);
    File('lib/screens/emotion_screen.dart').writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/adaptive_reward.dart';

${emLines.join('\n')}
''');
  }

  if (foStart != -1 && rwStart != -1) {
    var foLines = lines.sublist(foStart, rwStart);
    File('lib/screens/focus_screen.dart').writeAsStringSync('''
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/adaptive_reward.dart';

${foLines.join('\n')}
''');
  }

  if (rwStart != -1) {
    var rwLines = lines.sublist(rwStart);
    File('lib/screens/reward_screen.dart').writeAsStringSync('''
import 'package:flutter/material.dart';

${rwLines.join('\n')}
''');
  }

  if (cdStart != -1) {
    var mainLines = lines.sublist(0, cdStart);
    File('lib/main.dart').writeAsStringSync(mainLines.join('\n') + '\n');
  }

  print('Dart splitting complete.');
}
