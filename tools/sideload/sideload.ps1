# Builds a Connect IQ app and copies it to the Garmin watch's GARMIN\APPS folder.
#
#   -Check    Only report whether the watch is connected and whether the app is already on it.
#   -Replace  Overwrite the app already on the watch. Without it, an existing copy is left alone.
#   -Product  Device id, e.g. venu3s. Default: the single product in manifest.xml.
#   -Output   Output .prg name. Default: <project folder name>.prg in bin\.
#
# Exit codes: 0 done, 1 error, 2 watch not connected, 3 app already on the watch (use -Replace).

param(
    [switch]$Check,
    [switch]$Replace,
    [string]$Product,
    [string]$Output
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..\..").Path
$appName = Split-Path $root -Leaf
if (-not $Output) { $Output = "$appName.prg" }
$prg = Join-Path $root "bin\$Output"

# Find the device id in manifest.xml if it isn't given.
if (-not $Product) {
    $ids = @([regex]::Matches((Get-Content (Join-Path $root "manifest.xml") -Raw), '<iq:product id="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    if ($ids.Count -ne 1) { throw "manifest.xml lists $($ids.Count) products ($($ids -join ', ')). Pass -Product." }
    $Product = $ids[0]
}

# The watch shows up as a drive with a GARMIN folder on it.
$watches = @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -and (Test-Path (Join-Path $_.Root "GARMIN")) })
if ($watches.Count -eq 0) {
    Write-Output "Watch not connected. Connect it over USB and unlock it."
    exit 2
}
if ($watches.Count -gt 1) { throw "Several drives have a GARMIN folder: $($watches.Root -join ', '). Unplug all but the watch." }
$apps = Join-Path $watches[0].Root "GARMIN\APPS"
$onWatch = Join-Path $apps $Output
$exists = Test-Path $onWatch
Write-Output "Watch: $($watches[0].Root)"
Write-Output ("App on watch: " + $(if ($exists) { "yes, $(Get-Item $onWatch | ForEach-Object { $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm') })" } else { "no" }))

if ($Check) { exit 0 }
if ($exists -and -not $Replace) {
    Write-Output "$Output is already on the watch. Re-run with -Replace to overwrite it."
    exit 3
}

# The SDK location is stored by the Connect IQ SDK Manager.
$sdk = (Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg" -Raw).Trim()
$monkeyc = Join-Path $sdk "bin\monkeyc.bat"

# Developer key: the default location first, then anything under %USERPROFILE%\.garmin.
$key = Join-Path $env:USERPROFILE ".garmin\developer_key"
if (-not (Test-Path $key)) {
    $found = @(Get-ChildItem (Join-Path $env:USERPROFILE ".garmin") -Recurse -File | Where-Object { $_.Name -eq "developer_key" -or $_.Extension -eq ".der" })
    if ($found.Count -eq 0) { throw "No developer key found in $env:USERPROFILE\.garmin." }
    $key = $found[0].FullName
}

Push-Location $root
try {
    Write-Output "Building $Output for $Product..."
    & $monkeyc -d $Product -f monkey.jungle -o $prg -y $key
    if ($LASTEXITCODE -ne 0) { throw "Build failed (exit code $LASTEXITCODE)." }
} finally {
    Pop-Location
}

if (-not (Test-Path $apps)) { New-Item -ItemType Directory -Path $apps | Out-Null }
Copy-Item -Path $prg -Destination $onWatch -Force
Write-Output "Copied $Output to $apps"
Write-Output "Eject the watch from File Explorer before unplugging it."
