# Lance l'app en debug avec les secrets de secrets.json. Les arguments sont
# transmis à `flutter run`, par exemple : scripts/run.ps1 -d emulator-5554
# -Example prend secrets.example.json (clé Google Books factice) : c'est ce que
# lancent les agents sur l'émulateur, sans jamais toucher au vrai secrets.json.
param([switch]$Example)

# Définition dynamique du chemin du projet (un dossier au-dessus du script)
$ProjectPath = (Get-Item "$PSScriptRoot\..").FullName

Set-Location $ProjectPath

# Chemin vers le fichier de configuration (secrets)
$ConfigPath = if ($Example) { "secrets.example.json" } else { "secrets.json" }

if (Test-Path $ConfigPath) {
    flutter run --dart-define-from-file=$ConfigPath @args
} else {
    Write-Host "Fichier de configuration $ConfigPath non trouvé." -ForegroundColor Red
    exit 1
}
