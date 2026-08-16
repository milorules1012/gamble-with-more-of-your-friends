#Requires -Version 5.0
<#
.SYNOPSIS
  Double-click installer for GWYF Unlimited Players. Finds the game automatically and
  copies the mod files in - no manual folder-merging required.

.DESCRIPTION
  Run this from inside the extracted release folder (the one containing BepInEx\,
  winhttp.dll, doorstop_config.ini). It finds "Gamble With Your Friends" across all
  Steam libraries, copies the mod files into it, and reports success or a clear error.
  Prefer double-clicking Install-GWYF.bat, which just calls this with the right flags.
#>
param(
    [string]$GameDir
)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "FAILED: $msg" -ForegroundColor Red }

function Get-SteamAppsRoots {
    $roots = [System.Collections.Generic.List[string]]::new()
    foreach ($key in @("HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam")) {
        if (Test-Path $key) {
            $ip = (Get-ItemProperty -Path $key -Name InstallPath -ErrorAction SilentlyContinue).InstallPath
            if ($ip) { [void]$roots.Add((Join-Path $ip "steamapps")) }
        }
    }
    foreach ($guess in @("C:\SteamLibrary\steamapps", "D:\SteamLibrary\steamapps", "E:\SteamLibrary\steamapps")) {
        if (Test-Path -LiteralPath $guess) { [void]$roots.Add($guess) }
    }
    $vdfCandidates = $roots | ForEach-Object { Join-Path (Split-Path $_ -Parent) "config\libraryfolders.vdf" }
    foreach ($vdf in ($vdfCandidates | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $vdf)) { continue }
        $text = Get-Content -LiteralPath $vdf -Raw -ErrorAction SilentlyContinue
        if (-not $text) { continue }
        foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
            $p = $m.Groups[1].Value -replace '\\\\', '\'
            if ($p) {
                $apps = Join-Path $p "steamapps"
                if (Test-Path -LiteralPath $apps) { [void]$roots.Add($apps) }
            }
        }
    }
    return $roots | Select-Object -Unique
}

function Find-GameFolder {
    foreach ($apps in (Get-SteamAppsRoots)) {
        $candidate = Join-Path $apps "common\Gamble With Your Friends"
        $exe = Join-Path $candidate "Gamble With Your Friends.exe"
        if (Test-Path -LiteralPath $exe) { return $candidate }
    }
    return $null
}

if ($GameDir) {
    $exe = Join-Path $GameDir "Gamble With Your Friends.exe"
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Fail "No 'Gamble With Your Friends.exe' found in: $GameDir"
        exit 1
    }
    $gameDir = $GameDir
}
else {
    Write-Step "Looking for 'Gamble With Your Friends' across your Steam libraries..."
    $gameDir = Find-GameFolder
}

if (-not $gameDir) {
    Write-Fail "Could not find the game automatically."
    Write-Host ""
    Write-Host "Fix: in Steam, go to Gamble With Your Friends -> Manage -> Browse local files," -ForegroundColor Yellow
    Write-Host "then run this script again with:" -ForegroundColor Yellow
    Write-Host "  .\Install-GWYF.ps1 -GameDir `"PASTE_THE_FOLDER_PATH_HERE`"" -ForegroundColor Yellow
    exit 1
}
Write-Ok "Found game at: $gameDir"

if (Get-Process | Where-Object { $_.Name -like "*Gamble With Your Friends*" }) {
    Write-Step "Closing the game (it's currently running)..."
    Get-Process | Where-Object { $_.Name -like "*Gamble With Your Friends*" } | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$itemsToCopy = @("BepInEx", "winhttp.dll", "doorstop_config.ini", ".doorstop_version")
$missing = $itemsToCopy | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ScriptDir $_)) }
if ($missing.Count -eq $itemsToCopy.Count) {
    Write-Fail "This script isn't sitting next to the mod files (BepInEx\, winhttp.dll, ...)."
    Write-Host "Make sure Install-GWYF.ps1 is in the SAME folder as those, not moved out on its own." -ForegroundColor Yellow
    exit 1
}

Write-Step "Copying mod files into the game folder..."
try {
    foreach ($item in $itemsToCopy) {
        $src = Join-Path $ScriptDir $item
        if (-not (Test-Path -LiteralPath $src)) { continue }
        if (Test-Path -LiteralPath $src -PathType Container) {
            Copy-Item -LiteralPath $src -Destination $gameDir -Recurse -Force
        } else {
            Copy-Item -LiteralPath $src -Destination $gameDir -Force
        }
    }
}
catch {
    Write-Fail "Couldn't write to the game folder: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "This usually means the script needs to run as Administrator" -ForegroundColor Yellow
    Write-Host "(the game is under Program Files). Right-click Install-GWYF.bat -> Run as administrator." -ForegroundColor Yellow
    exit 1
}

$pluginDll = Join-Path $gameDir "BepInEx\plugins\GwyfUnlimitedPlayers.dll"
if (-not (Test-Path -LiteralPath $pluginDll)) {
    Write-Fail "Copy finished but BepInEx\plugins\GwyfUnlimitedPlayers.dll is missing from the game folder."
    exit 1
}

Write-Ok "Installed into: $gameDir"
Write-Host ""
Write-Host "Next: launch the game once, then quit, to confirm it starts cleanly." -ForegroundColor Green
Write-Host "You only need this if YOU are hosting the lobby - people joining you don't need it." -ForegroundColor Green
