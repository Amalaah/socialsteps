import os

files = [
    r"c:\socialsteps\socialsteps-master\lib\providers\module_state_provider.dart",
    r"c:\socialsteps\socialsteps-master\lib\child_profile_screen.dart",
    r"c:\socialsteps\socialsteps-master\lib\parent_dashboard.dart",
    r"c:\socialsteps\socialsteps-master\lib\activities_screen.dart",
    r"c:\socialsteps\socialsteps-master\lib\view_progress_screen.dart",
    r"c:\socialsteps\socialsteps-master\lib\assign_activites_screen.dart",
    r"c:\socialsteps\socialsteps-master\lib\view_stars_screen.dart",
    r"c:\socialsteps\socialsteps-master\lib\settings_screen.dart"
]

for f in files:
    with open(f, "r", encoding="utf-8") as file:
        content = file.read()
    if "constants.dart" not in content and "AppConstants" in content:
        content = "import 'package:socialsteps/utils/constants.dart';\n" + content
        with open(f, "w", encoding="utf-8") as file:
            file.write(content)
        print("Fixed", f)
