# Relevé quotidien de la mesure B8 (ux-backlog, B8 étape 1) : la replanification
# des rappels en tâche de fond (WorkManager, tâche « reminders-replan ») tourne-t-elle
# bien chaque jour sur le téléphone, application fermée ?
#
# Un relevé par jour, à peu près à la même heure, pendant au moins 10 jours (dont 3
# sans ouvrir AnKi, un redémarrage et une période hors ligne). Chaque relevé s'ajoute
# au CSV et se compare au précédent. Lecture seule : rien n'est changé sur le
# téléphone, sauf avec -Force (un passage forcé, pour le test du jour 0).
#
# Prérequis : l'APK debug installé par scripts\build_and_deploy.ps1 (pas flutter run,
# dont l'onglet arrête l'app de force), le téléphone branché en débogage USB, Python 3
# sur le PC (lecture de la base de WorkManager).
#
# Exemples :
#   .\scripts\b8_reading.ps1                      relevé du jour
#   .\scripts\b8_reading.ps1 -Note "redémarré"    relevé avec une note (redémarrage, hors ligne, AnKi pas ouvert…)
#   .\scripts\b8_reading.ps1 -Force               jour 0 : force un passage, puis relève
#                                                 (sauté avant l'échéance : WorkManager l'ignorerait)
param(
    [string]$Device = "",       # Numéro de série adb ; vide : le seul appareil branché
    [string]$Note = "",         # Ce qui s'est passé depuis le dernier relevé
    [switch]$Force = $false,    # Force un passage de la tâche avant le relevé (jour 0)
    [string]$CsvPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AnKi\b8-readings.csv')
)

$ErrorActionPreference = 'Stop'

$PackageName = 'com.github.nautiii.an_ki'
$TaskName = 'reminders-replan'
$MaxHoursBetweenRuns = 36

$AndroidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$AdbPath = "$AndroidSdk\platform-tools\adb.exe"
if (-not (Test-Path $AdbPath)) { $AdbPath = 'adb' }

function Stop-Reading([string]$Message) {
    Write-Host $Message -ForegroundColor Red
    exit 1
}

# --- Appareil ---------------------------------------------------------------

# adb et Python écrivent sur stderr (progression, « daemon started », traces) :
# Windows PowerShell en ferait des erreurs bloquantes, on les garde comme du texte.
function Invoke-Native([string]$Command) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Command @args 2>&1
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    return ($output | ForEach-Object { "$_" })
}

function Invoke-Adb { return (Invoke-Native $AdbPath -s $Device @args) }

if (-not $Device) {
    $serials = @(Invoke-Native $AdbPath devices | Select-Object -Skip 1 |
        Where-Object { $_ -match '^(\S+)\s+device$' } | ForEach-Object { $Matches[1] })
    if ($serials.Count -eq 0) { Stop-Reading "Aucun appareil : branche le téléphone et accepte le débogage USB." }
    if ($serials.Count -gt 1) { Stop-Reading "Plusieurs appareils ($($serials -join ', ')) : précise -Device <numéro de série>." }
    $Device = $serials[0]
}

$runAs = Invoke-Adb shell run-as $PackageName true
if ($LASTEXITCODE -ne 0) {
    Stop-Reading "Impossible de lire l'app ($runAs). Il faut l'APK debug : .\scripts\build_and_deploy.ps1"
}

# Le lanceur py d'abord ; python ensuite, sauf l'alias du Microsoft Store (WindowsApps),
# présent même sans Python installé.
$python = $null
$pythonArgs = @()
$launcher = Get-Command py -ErrorAction SilentlyContinue
if ($launcher) {
    $python = $launcher.Source
    $pythonArgs = @('-3')
} else {
    $candidate = Get-Command python -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notlike '*\WindowsApps\*' } | Select-Object -First 1
    if ($candidate) { $python = $candidate.Source }
}
if (-not $python) { Stop-Reading "Python 3 introuvable : il lit la base de WorkManager (installe-le depuis python.org)." }

# --- Base de WorkManager ------------------------------------------------------

$WorkDir = Join-Path $env:TEMP 'anki-b8'
New-Item -ItemType Directory -Force $WorkDir | Out-Null
$QueryPath = Join-Path $WorkDir 'query.py'
Set-Content -Path $QueryPath -Encoding ASCII -Value @'
import json, sqlite3, sys
db = sqlite3.connect(sys.argv[1])
row = db.execute(
    "select w.state, w.period_count, w.run_attempt_count, w.last_enqueue_time,"
    " (select system_id from SystemIdInfo s where s.work_spec_id = w.id)"
    " from WorkSpec w join WorkName n on n.work_spec_id = w.id where n.name = ?",
    (sys.argv[2],),
).fetchone()
keys = ["state", "runs", "attempts", "lastEnqueue", "jobId"]
print(json.dumps(dict(zip(keys, row)) if row else None))
'@

# Copiée par le shell de l'appareil (binaire intact), journal WAL compris.
function Read-WorkSpec {
    foreach ($file in 'androidx.work.workdb', 'androidx.work.workdb-wal', 'androidx.work.workdb-shm') {
        $remote = "/data/local/tmp/anki_b8_$file"
        Remove-Item (Join-Path $WorkDir $file) -ErrorAction SilentlyContinue
        Invoke-Adb shell "run-as $PackageName cat no_backup/$file > $remote 2>/dev/null" | Out-Null
        Invoke-Adb pull $remote (Join-Path $WorkDir $file) | Out-Null
        Invoke-Adb shell rm -f $remote | Out-Null
    }
    $json = Invoke-Native $python @pythonArgs $QueryPath (Join-Path $WorkDir 'androidx.work.workdb') $TaskName
    if ($LASTEXITCODE -ne 0) { Stop-Reading "Lecture de la base impossible : $($json -join "`n")" }
    return (($json | Select-Object -Last 1) | ConvertFrom-Json)
}

$work = Read-WorkSpec
if ($null -eq $work) {
    Stop-Reading "La tâche « $TaskName » n'est pas dans la base : ouvre AnKi une fois (elle s'enregistre au lancement)."
}

# --- Heure de l'appareil -------------------------------------------------------

# Toutes les heures à l'heure locale du téléphone, comme celles d'exit-info.
$offsetText = (Invoke-Adb shell date +%z | Select-Object -First 1).Trim()
$deviceOffset = New-TimeSpan -Hours ([int]$offsetText.Substring(0, 3)) -Minutes ([int]($offsetText.Substring(0, 1) + $offsetText.Substring(3, 2)))
$epoch = [DateTimeOffset]::FromUnixTimeSeconds(0)
function ConvertFrom-Epoch([double]$Seconds) { return $epoch.AddSeconds($Seconds).ToOffset($deviceOffset).DateTime }
function Get-DeviceNow { return (ConvertFrom-Epoch ([double](Invoke-Adb shell date +%s | Select-Object -First 1))) }

# --- Passage forcé (jour 0) ---------------------------------------------------

if ($Force) {
    if ($null -eq $work.jobId) { Stop-Reading "Pas d'identifiant de job : ouvre AnKi une fois, puis relance." }
    # WorkManager ignore un passage périodique lancé avant son échéance : forcer ne sert
    # que tant que la tâche n'a jamais tourné, ou une fois l'échéance passée.
    $due = (ConvertFrom-Epoch ($work.lastEnqueue / 1000)).AddHours(24)
    if ([int]$work.runs -gt 0 -and (Get-DeviceNow) -lt $due) {
        Write-Host "Pas de passage forcé : WorkManager l'ignorerait avant l'échéance ($($due.ToString('yyyy-MM-dd HH:mm'))). $($work.runs) passage(s) déjà comptés : la tâche tourne." -ForegroundColor Yellow
    } else {
        $before = $work.runs
        Write-Host "Passage forcé du job $($work.jobId)…" -ForegroundColor Yellow
        $started = Invoke-Adb shell cmd jobscheduler run -f -n androidx.work.systemjobscheduler $PackageName $work.jobId
        if (-not ($started -match '^Running job')) { Write-Host "  jobscheduler : $($started -join ' ')" -ForegroundColor Yellow }
        for ($i = 0; $i -lt 8 -and $work.runs -eq $before; $i++) {
            Start-Sleep -Seconds 15
            $work = Read-WorkSpec
        }
        if ($work.runs -eq $before) {
            Write-Host "Le compteur n'a pas bougé après 2 min : voir « À regarder » ci-dessous." -ForegroundColor Red
        } else {
            Write-Host "Passage terminé : le compteur est passé de $before à $($work.runs)." -ForegroundColor Green
        }
    }
}

# --- Autres relevés -----------------------------------------------------------

$now = Get-DeviceNow
$uptime = [double]((Invoke-Adb shell cat /proc/uptime | Select-Object -First 1).Split(' ')[0])
$bootTime = $now.AddSeconds(-$uptime)
$lastRun = ConvertFrom-Epoch ($work.lastEnqueue / 1000)
$hoursSinceRun = [math]::Round(($now - $lastRun).TotalHours, 1)

# 10 actif, 20 ensemble de travail, 30 fréquent, 40 rare, 45 restreint.
$bucket = (Invoke-Adb shell am get-standby-bucket $PackageName | Select-Object -First 1).Trim()

$jobScheduled = [bool](Invoke-Adb shell dumpsys jobscheduler |
    Select-String "JOB androidx\.work\.systemjobscheduler:\S+/$($work.jobId):.*$([regex]::Escape($PackageName))")

$alarms = @(Invoke-Adb shell dumpsys alarm |
    Select-String "Alarm\{.*$([regex]::Escape($PackageName))\}").Count

$forceStops = @(Invoke-Adb shell dumpsys activity exit-info $PackageName |
    Select-String 'timestamp=(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)' -Context 0, 1 |
    Where-Object { $_.Context.PostContext -match 'FORCE STOP' } |
    ForEach-Object { [datetime]::ParseExact($_.Matches[0].Groups[1].Value, 'yyyy-MM-dd HH:mm:ss', $null) })

# --- Comparaison au relevé précédent -----------------------------------------

$previous = $null
# Point-virgule : le séparateur qu'Excel en français ouvre et réenregistre tel quel.
if (Test-Path $CsvPath) { $previous = Import-Csv $CsvPath -Delimiter ';' | Select-Object -Last 1 }
# Premier relevé : les arrêts forcés des dernières 24 h, pas tout l'historique.
$since = if ($previous) { [datetime]::Parse($previous.date) } else { $now.AddDays(-1) }
$newRuns = if ($previous) { [int]$work.runs - [int]$previous.runs } else { '' }
$newForceStops = @($forceStops | Where-Object { $_ -gt $since -and $_ -le $now.AddMinutes(5) })
$futureForceStops = @($forceStops | Where-Object { $_ -gt $now.AddMinutes(5) })
$rebooted = $previous -and ($bootTime -gt [datetime]::Parse($previous.date))

$row = [pscustomobject]@{
    date                 = $now.ToString('yyyy-MM-dd HH:mm')
    runs                 = $work.runs
    new_runs             = $newRuns
    attempts             = $work.attempts
    state                = $work.state
    last_run             = $lastRun.ToString('yyyy-MM-dd HH:mm')
    hours_since_last_run = $hoursSinceRun
    standby_bucket       = $bucket
    force_stops          = $newForceStops.Count
    job_scheduled        = $jobScheduled
    alarms               = $alarms
    boot                 = $bootTime.ToString('yyyy-MM-dd HH:mm')
    rebooted             = [bool]$rebooted
    forced               = [bool]$Force
    note                 = $Note
}

New-Item -ItemType Directory -Force (Split-Path $CsvPath) | Out-Null
$row | Export-Csv -Path $CsvPath -Append -NoTypeInformation -Encoding UTF8 -Delimiter ';'

# --- Résumé -------------------------------------------------------------------

Write-Host ''
Write-Host "Relevé B8 du $($row.date) ($Device)" -ForegroundColor Cyan
Write-Host "  Passages        : $($work.runs)$(if ($previous) { " (+$newRuns depuis le $($previous.date))" })"
if ([int]$work.runs -eq 0) {
    Write-Host "  Dernier passage : aucun encore (tâche enregistrée le $($row.last_run))"
} else {
    Write-Host "  Dernier passage : $($row.last_run), il y a $hoursSinceRun h"
}
Write-Host "  Essais ratés    : $($work.attempts)"
Write-Host "  Mise en veille  : $bucket (10-20 bien, 30-40 espacé, 45 restreint)"
Write-Host "  Job planifié    : $(if ($jobScheduled) { 'oui' } else { 'non' }) · alarmes de rappel : $alarms"
Write-Host "  Démarrage       : $($row.boot)$(if ($rebooted) { ' (redémarré depuis le dernier relevé)' })"
if ($Note) { Write-Host "  Note            : $Note" }
Write-Host ''

$problems = @()
if (-not $jobScheduled) { $problems += "le job n'est plus planifié : arrêt forcé ou mise à jour de l'app ; il revient au prochain lancement d'AnKi" }
if ($hoursSinceRun -gt $MaxHoursBetweenRuns) { $problems += "aucun passage depuis $hoursSinceRun h (plus de $MaxHoursBetweenRuns h)" }
if ($hoursSinceRun -lt 0) { $problems += "dernier passage daté dans le futur : l'horloge a été avancée, la mesure n'est pas fiable" }
if ($newForceStops.Count -gt 0) { $problems += "$($newForceStops.Count) arrêt(s) forcé(s) $(if ($previous) { 'depuis le dernier relevé' } else { 'dans les dernières 24 h' }) : ils annulent la tâche et les alarmes" }
if ($futureForceStops.Count -gt 0) { $problems += "un arrêt forcé daté dans le futur (horloge avancée) : WorkManager arrête alors chaque passage" }
if ([int]$work.attempts -gt 0) { $problems += "$($work.attempts) essai(s) raté(s) : un passage échoue et WorkManager réessaie" }
if ($bucket -eq '45') { $problems += "AnKi est en veille restreinte (45) : regarde ses réglages de batterie et de lancement" }
if ($alarms -eq 0) { $problems += "aucune alarme de rappel programmée" }
if ($previous -and $newRuns -lt 0) { $problems += "compteur revenu à $($work.runs) : app réinstallée ou données effacées, la mesure repart de zéro" }
# États de WorkManager : 0 en attente, 1 en cours, 2 réussi, 3 échoué, 4 bloqué, 5 annulé.
if ([int]$work.state -in 3, 5) { $problems += "la tâche est $(if ([int]$work.state -eq 3) { 'en échec' } else { 'annulée' }) (état $($work.state)) : elle ne repassera pas seule" }

if ($problems.Count -eq 0) {
    Write-Host "OK : la tâche tourne. Relevé ajouté à $CsvPath" -ForegroundColor Green
} else {
    Write-Host "À regarder :" -ForegroundColor Yellow
    $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "Relevé ajouté à $CsvPath" -ForegroundColor Gray
}
