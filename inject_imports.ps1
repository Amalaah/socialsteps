$files = Get-ChildItem -Path "c:\socialsteps\socialsteps-master\lib" -Recurse -Filter "*.dart"
foreach ($f in $files) {
    if ($f.Name -eq "constants.dart") { continue }
    $c = [System.IO.File]::ReadAllText($f.FullName)
    if ($c -match "AppConstants" -and $c -notmatch "constants\.dart") {
        $c = $c -replace '(?m)^(import .*;\r?\n)', "`$1import 'package:socialsteps/utils/constants.dart';`n"
        [System.IO.File]::WriteAllText($f.FullName, $c)
    }
}
