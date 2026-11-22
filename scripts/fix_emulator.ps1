<#
.SYNOPSIS
    ROADIX - Android Emulator Diagnostic & Recovery Tool
.DESCRIPTION
    Fixes the common "The Android emulator exited with code 1 during startup" error
    by terminating lingering/orphaned emulator processes and removing stale AVD lock files.
#>

param (
    [string]$AvdName = "Pixel_7_Pro",
    [switch]$Launch = $false
)

Write-Host "=== ROADIX Android Emulator Recovery ===" -ForegroundColor Cyan

# 1. Kill lingering emulator and qemu processes
Write-Host "[1/3] Terminating any frozen or orphaned emulator processes..." -ForegroundColor Yellow
$procs = Get-Process -Name emulator, qemu-system-x86_64 -ErrorAction SilentlyContinue
if ($procs) {
    $procs | ForEach-Object {
        Write-Host "  -> Stopping $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Gray
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
} else {
    Write-Host "  -> No lingering emulator processes found." -ForegroundColor Gray
}

# 2. Clear stale lock files in AVD directory
$avdDir = Join-Path "$HOME\.android\avd" "$AvdName.avd"
Write-Host "[2/3] Inspecting AVD directory: $avdDir" -ForegroundColor Yellow

if (Test-Path $avdDir) {
    $locks = Get-ChildItem -Path $avdDir -Filter "*.lock*" -Recurse -ErrorAction SilentlyContinue
    if ($locks) {
        $locks | ForEach-Object {
            Write-Host "  -> Removing stale lock: $($_.Name)" -ForegroundColor Red
            Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
        }
        Write-Host "  -> All stale lock files cleared." -ForegroundColor Green
    } else {
        Write-Host "  -> No lock files detected." -ForegroundColor Gray
    }
} else {
    Write-Warning "AVD directory not found at $avdDir"
}

# 3. Verify adb status and optionally launch
Write-Host "[3/3] Restarting adb server..." -ForegroundColor Yellow
& adb kill-server 2>$null
& adb start-server 2>$null

if ($Launch) {
    Write-Host "Launching $AvdName..." -ForegroundColor Cyan
    & flutter emulators --launch $AvdName
}

Write-Host "=== Recovery Complete! You can now launch '$AvdName' from VS Code or Flutter. ===" -ForegroundColor Green
