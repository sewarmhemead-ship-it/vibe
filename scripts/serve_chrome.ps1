# Build Flutter web and serve for Chrome (http://localhost:8765).
# Run from repo:  powershell -ExecutionPolicy Bypass -File .\scripts\serve_chrome.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$flutter = if ($env:FLUTTER_ROOT) {
  Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
} elseif (Test-Path "C:\flutter\bin\flutter.bat") {
  "C:\flutter\bin\flutter.bat"
} else {
  "flutter"
}

& $flutter pub get
& $flutter build web --release
Set-Location (Join-Path $root "build\web")
Write-Host "Open in Chrome: http://localhost:8765" -ForegroundColor Green
# Use cmd so npx.ps1 is not blocked by PowerShell ExecutionPolicy
$nodeDir = "${env:ProgramFiles}\nodejs"
if (Test-Path (Join-Path $nodeDir "npx.cmd")) {
  & (Join-Path $nodeDir "npx.cmd") --yes serve -l 8765
} else {
  cmd.exe /c "npx --yes serve -l 8765"
}
