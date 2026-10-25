# Teste firestore.rules dans l'émulateur Firestore, sur le projet de
# démonstration `demo-anki` : jamais la production. Les arguments sont
# transmis à `flutter test`, par exemple :
#   scripts/test_firestore_rules.ps1 --plain-name "birthday"
# En tête, `-Config <firebase.json>` prend une autre configuration : des règles
# affaiblies dans une copie, pour vérifier qu'un test les refuse (skill firebase).
#
# Prérequis : le CLI Firebase (npm install -g firebase-tools) et un JDK 21+
# (dans le PATH, JAVA_HOME ou ~/.jdks). Le premier lancement télécharge
# l'émulateur (~140 Mo, dans ~/.cache/firebase/emulators).

$ProjectPath = (Get-Item "$PSScriptRoot\..").FullName
Set-Location $ProjectPath

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host "CLI Firebase introuvable : npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}

# Version majeure d'un exécutable java, 0 s'il ne répond pas.
function Get-JavaMajor([string]$Java) {
    try {
        foreach ($line in (& $Java -version 2>&1 | ForEach-Object { "$_" })) {
            if ($line -match 'version "(\d+)') { return [int]$Matches[1] }
        }
    } catch {}
    return 0
}

# L'émulateur exige Java 21+ : celui du PATH, sinon JAVA_HOME, sinon ~/.jdks.
$java = Get-Command java -ErrorAction SilentlyContinue
if (-not $java -or (Get-JavaMajor $java.Source) -lt 21) {
    $homes = @($env:JAVA_HOME) + @(Get-ChildItem "$HOME\.jdks" -Directory -ErrorAction SilentlyContinue |
        ForEach-Object FullName) | Where-Object { $_ }
    $jdk = $homes | Where-Object { (Get-JavaMajor "$_\bin\java.exe") -ge 21 } | Select-Object -First 1
    if (-not $jdk) {
        Write-Host "Aucun JDK 21+ trouvé (PATH, JAVA_HOME, ~/.jdks) : l'émulateur Firestore en a besoin." -ForegroundColor Red
        exit 1
    }
    $env:JAVA_HOME = $jdk
    $env:Path = "$jdk\bin;$env:Path"
}

# Shells de Claude desktop (paquet MSIX) : Java n'y ouvre pas de socket AF_UNIX
# sous AppData. On lui donne un dossier hors AppData.
if ($env:CLAUDECODE -and -not $env:JAVA_TOOL_OPTIONS) {
    $socketDir = "$HOME\.cache\firebase\af"
    New-Item -ItemType Directory -Force $socketDir | Out-Null
    $env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=$socketDir"
}

# Pas de bloc param : un `--plain-name` se lierait à -Config par position.
$rest = @($args)
$configArgs = @()
if ($rest.Count -ge 2 -and $rest[0] -eq '-Config') {
    $configArgs = @('--config', (Resolve-Path $rest[1]).Path)
    $rest = @($rest | Select-Object -Skip 2)
}

# emulators:exec lance son script avec cmd : les arguments de flutter test
# passent par une variable que cmd développe, sans guillemets imbriqués que
# PowerShell 5.1 abîmerait en appelant le CLI.
$script = 'flutter test test/firestore'
if ($rest.Count -gt 0) {
    $env:ANKI_FLUTTER_TEST_ARGS = ($rest | ForEach-Object { if ("$_" -match '\s') { "`"$_`"" } else { "$_" } }) -join ' '
    $script += ' %ANKI_FLUTTER_TEST_ARGS%'
}

# Processus Java de l'émulateur Firestore, lancés depuis [Since] si donné.
function Get-FirestoreEmulators([datetime]$Since = [datetime]::MinValue) {
    Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" |
        Where-Object { $_.CommandLine -like '*cloud-firestore-emulator*' -and $_.CreationDate -ge $Since }
}

$port = 8080 # emulators.firestore.port de firebase.json
$busy = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($busy) {
    $owner = Get-FirestoreEmulators | Where-Object ProcessId -eq $busy.OwningProcess
    if ($owner) {
        Write-Host "Un émulateur Firestore occupe déjà le port $port (pid $($owner.ProcessId)), sans doute laissé par un lancement interrompu. L'arrêter : Stop-Process -Id $($owner.ProcessId)" -ForegroundColor Red
    } else {
        Write-Host "Le port $port est pris (pid $($busy.OwningProcess)) : libérer le port ou changer emulators.firestore.port dans firebase.json." -ForegroundColor Red
    }
    exit 1
}

# Le CLI pousse parfois les règles pendant le démarrage (« Change detected,
# updating rules… ») et s'arrête sur « Failed to make request … securityRules »
# en laissant l'émulateur tourner : on arrête ce que ce lancement a démarré et
# on réessaie une fois. Un second échec vient en général de règles invalides.
for ($attempt = 1; $attempt -le 2; $attempt++) {
    $started = Get-Date
    firebase emulators:exec @configArgs --only firestore --project demo-anki $script 2>&1 |
        ForEach-Object { "$_" } | Tee-Object -Variable lines | Out-Host
    $code = $LASTEXITCODE
    Start-Sleep -Seconds 2
    Get-FirestoreEmulators -Since $started | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    if ($code -eq 0 -or -not ($lines -match 'securityRules')) { break }
    if ($attempt -eq 1) {
        Write-Host "Chargement des règles interrompu au démarrage : nouvel essai." -ForegroundColor Yellow
    } else {
        Write-Host "Les règles ne se chargent pas : erreur de syntaxe ? Compiler sur le serveur, sans rien publier : firebase deploy --only firestore:rules --dry-run --non-interactive --project an-ki-9b02b" -ForegroundColor Red
    }
}
exit $code
