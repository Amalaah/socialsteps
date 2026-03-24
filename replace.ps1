$ErrorActionPreference = "Stop"

$files = Get-ChildItem -Path "c:\socialsteps\socialsteps-master\lib" -Recurse -Filter "*.dart" | Where-Object { $_.Name -ne "constants.dart" }

foreach ($f in $files) {
    try {
        $content = [System.IO.File]::ReadAllText($f.FullName)
        $modified = $false

        if ($content -match 'collection\("parents"\)') {
            $content = $content -replace 'collection\("parents"\)', 'collection(AppConstants.parentsCollection)'
            $modified = $true
        }
        if ($content -match 'collection\("children"\)') {
            $content = $content -replace 'collection\("children"\)', 'collection(AppConstants.childrenCollection)'
            $modified = $true
        }

        if ($modified) {
            if ($content -notmatch 'utils/constants\.dart') {
                # Insert import after first import
                $content = $content -replace '(?m)^(import .*;\r?\n)', "`$1import 'package:socialsteps/utils/constants.dart';`n"
            }
            [System.IO.File]::WriteAllText($f.FullName, $content)
            Write-Host "Updated $($f.Name)"
        }
    } catch {
        Write-Host "Error processing $($f.FullName): $_"
    }
}
Write-Host "Done!"
