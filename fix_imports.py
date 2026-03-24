import os
import re

lib_dir = r"c:\socialsteps\socialsteps-master\lib"
constants_import = "import 'package:socialsteps/utils/constants.dart';\n"

for root, _, files in os.walk(lib_dir):
    for filename in files:
        if filename.endswith(".dart"):
            filepath = os.path.join(root, filename)
            
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            
            modified = False
            
            # 1. Replace test_app with socialsteps
            if "package:test_app" in content:
                content = content.replace("package:test_app", "package:socialsteps")
                modified = True
                
            # 2. Add AppConstants import if missing
            if "AppConstants" in content and "constants.dart" not in content and filename != "constants.dart":
                # Find the last import statement
                lines = content.split('\n')
                last_import_idx = -1
                for i, line in enumerate(lines):
                    if line.strip().startswith('import '):
                        last_import_idx = i
                
                if last_import_idx != -1:
                    lines.insert(last_import_idx + 1, "import 'package:socialsteps/utils/constants.dart';")
                    content = '\n'.join(lines)
                    modified = True
                else:
                    content = constants_import + content
                    modified = True
                    
            if modified:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"Fixed imports in {filepath}")
