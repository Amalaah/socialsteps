import os
import re

constants_dir = r"c:\socialsteps\socialsteps-master\lib\utils"
os.makedirs(constants_dir, exist_ok=True)

constants_content = """class AppConstants {
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
"""
with open(os.path.join(constants_dir, "constants.dart"), "w", encoding="utf-8") as f:
    f.write(constants_content)

root_dir = r"c:\socialsteps\socialsteps-master\lib"
for dp, dn, filenames in os.walk(root_dir):
    for f in filenames:
        if f.endswith(".dart") and f != "constants.dart":
            path = os.path.join(dp, f)
            with open(path, "r", encoding="utf-8") as file:
                content = file.read()
            
            # Replace collections
            new_content = re.sub(r'collection\("parents"\)', r'collection(AppConstants.parentsCollection)', content)
            new_content = re.sub(r"collection\('parents'\)", r'collection(AppConstants.parentsCollection)', new_content)
            
            new_content = re.sub(r'collection\("children"\)', r'collection(AppConstants.childrenCollection)', new_content)
            new_content = re.sub(r"collection\('children'\)", r'collection(AppConstants.childrenCollection)', new_content)
            
            if new_content != content:
                import_stmt = "import 'package:socialsteps/utils/constants.dart';"
                if import_stmt not in new_content:
                    # insert after first import safely
                    new_content = re.sub(r"^(import .*;\r?\n)", r"\1" + import_stmt + "\n", new_content, count=1)
                    
                with open(path, "w", encoding="utf-8") as file:
                    file.write(new_content)

print("Constants successfully extracted and applied.")
