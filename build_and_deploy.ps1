# Build and Deploy Script for An Ki App
param(
    [switch]$Clean = $false
)

$ProjectPath = "C:\Users\qmaillard\Projets\PERSO\kairos"
$AdbPath = "C:\Users\qmaillard\AppData\Local\Android\sdk\platform-tools\adb.exe"
$PackageName = "com.github.nautiii.an_ki"
$Activity = "$PackageName/$PackageName.MainActivity"
$ApkPath = "$ProjectPath\build\app\outputs\flutter-apk\app-debug.apk"

Set-Location $ProjectPath

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building An Ki App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Clean if requested
if ($Clean) {
    Write-Host "`n[1/5] Cleaning project..." -ForegroundColor Yellow
    flutter clean
    Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
}

# Generate launcher icons
Write-Host "`n[2/5] Generating launcher icons..." -ForegroundColor Yellow
flutter pub run flutter_launcher_icons:main

# Get dependencies
Write-Host "`n[3/5] Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build APK
Write-Host "`n[4/5] Building APK..." -ForegroundColor Yellow
flutter build apk --debug

# Check if build succeeded
if (-not (Test-Path $ApkPath)) {
    Write-Host "`n❌ Build failed! APK not found at $ApkPath" -ForegroundColor Red
    exit 1
}

# Install APK
Write-Host "`n[5/5] Installing and launching app..." -ForegroundColor Yellow
& $AdbPath install -r $ApkPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ APK installed successfully!" -ForegroundColor Green
    & $AdbPath shell am start -n "$Activity"
    Write-Host "✅ App launched!" -ForegroundColor Green
} else {
    Write-Host "❌ Installation failed!" -ForegroundColor Red
    exit 1
}
