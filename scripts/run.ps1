# Lance l'app en debug avec les secrets de secrets.json. Les arguments sont
# transmis à `flutter run`, par exemple : scripts/run.ps1 -d emulator-5554

# Définition dynamique du chemin du projet (un dossier au-dessus du script)
$ProjectPath = (Get-Item "$PSScriptRoot\..").FullName

Set-Location $ProjectPath

# Chemin vers le fichier de configuration (secrets)
$ConfigPath = "secrets.json"

if (Test-Path $ConfigPath) {
    flutter run --dart-define-from-file=$ConfigPath @args
} else {
    Write-Host "Fichier de configuration $ConfigPath non trouvé." -ForegroundColor Red
    exit 1
}
