import 'dart:io';

void main() {
  final constantsDir = Directory('lib/utils');
  if (!constantsDir.existsSync()) {
    constantsDir.createSync(recursive: true);
  }

  final constantsFile = File('lib/utils/constants.dart');
  constantsFile.writeAsStringSync('''class AppConstants {
  // Firestore Collections
  static const String parentsCollection = "parents";
  static const String childrenCollection = "children";
  
  // Modules
  static const String moduleEmotion = "emotion";
  static const String moduleFocus = "focus";
  static const String modulePuzzle = "puzzle";
  static const String moduleColor = "color";

  // Difficulty Levels
  static const String levelEasy = "easy";
  static const String levelMedium = "medium";
  static const String levelHard = "hard";
}
''');

  final rootDir = Directory('lib');
  final files = rootDir.listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart') && !file.path.endsWith('constants.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    String newContent = content;

    newContent = newContent.replaceAll('collection("parents")', 'collection(AppConstants.parentsCollection)');
    newContent = newContent.replaceAll("collection('parents')", 'collection(AppConstants.parentsCollection)');

    newContent = newContent.replaceAll('collection("children")', 'collection(AppConstants.childrenCollection)');
    newContent = newContent.replaceAll("collection('children')", 'collection(AppConstants.childrenCollection)');

    if (newContent != content) {
      if (!newContent.contains("import 'package:socialsteps/utils/constants.dart';") && 
          !newContent.contains("import '../utils/constants.dart';")) {
        newContent = newContent.replaceFirst(RegExp(r'(import .*;\n)'), "\\1import 'package:socialsteps/utils/constants.dart';\\n");
      }
      file.writeAsStringSync(newContent);
    }
  }

  print("Constants successfully extracted and applied using Dart.");
}
