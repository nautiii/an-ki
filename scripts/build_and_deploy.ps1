# Script de Build et Déploiement pour l'application An Ki
param(
    [switch]$Clean = $false,                # Nettoyer le projet avant le build
    [switch]$Release = $false,              # Mode release (défaut: debug)
    [string]$ConfigPath = "secrets.json"    # Chemin vers le fichier de configuration (secrets)
)

# Définition dynamique du chemin du projet (un dossier au-dessus du script)
$ProjectPath = (Get-Item "$PSScriptRoot\..").FullName

# Recherche dynamique de ADB via les variables d'environnement
$AndroidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$AdbPath = "$AndroidSdk\platform-tools\adb.exe"

$PackageName = "com.github.nautiii.an_ki"
$Activity = "$PackageName/$PackageName.MainActivity"

# Détermination du type de build et du chemin de sortie
$BuildType = if ($Release) { "release" } else { "debug" }
$ArtifactPath = "$ProjectPath\build\app\outputs\flutter-apk\app-$BuildType.apk"

Set-Location $ProjectPath

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Build de l'application An Ki" -ForegroundColor Cyan
Write-Host "Racine du projet : $ProjectPath" -ForegroundColor Gray
Write-Host "Cible : APK ($BuildType)" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan

# 1. Nettoyage
if ($Clean) {
    Write-Host "`n[1/5] Nettoyage du projet..." -ForegroundColor Yellow
    flutter clean
    if (Test-Path "build") {
        Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 2. Icônes de lancement
Write-Host "`n[2/5] Génération des icônes de lancement..." -ForegroundColor Yellow
dart run flutter_launcher_icons

# 3. Dépendances
Write-Host "`n[3/5] Récupération des dépendances..." -ForegroundColor Yellow
flutter pub get

# 4. Build avec injection des secrets depuis le fichier
Write-Host "`n[4/5] Build de l'APK ($BuildType)..." -ForegroundColor Yellow
$BuildArgs = @("build", "apk", "--$BuildType")

# Ajout automatique du fichier de secrets s'il existe
if (Test-Path $ConfigPath) {
    $BuildArgs += "--dart-define-from-file=$ConfigPath"
    Write-Host "Injection des secrets depuis $ConfigPath" -ForegroundColor DarkGray
} else {
    Write-Host "Fichier de configuration $ConfigPath non trouvé." -ForegroundColor Yellow
}

& flutter $BuildArgs

# Vérification du succès du build
if (-not (Test-Path $ArtifactPath)) {
    Write-Host "`nÉchec du build ! Artefact non trouvé à l'emplacement : $ArtifactPath" -ForegroundColor Red
    exit 1
}

Write-Host "`nBuild réussi : $ArtifactPath" -ForegroundColor Green

# 5. Déploiement
if (-not (Test-Path $AdbPath)) {
    Write-Host "`nADB non trouvé. Déploiement annulé." -ForegroundColor Yellow
} else {
    Write-Host "`n[5/5] Installation et lancement de l'application..." -ForegroundColor Yellow
    & $AdbPath install -r $ArtifactPath

    if ($LASTEXITCODE -eq 0) {
        Write-Host "APK installé avec succès !" -ForegroundColor Green
        & $AdbPath shell am start -n "$Activity"
        Write-Host "Application lancée !" -ForegroundColor Green
    } else {
        Write-Host "Échec de l'installation !" -ForegroundColor Red
        exit 1
    }
}
