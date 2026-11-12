<#
.SYNOPSIS
    Script officiel de publication automatisée des mises à jour DubaGest (Android APK + PWA).
.DESCRIPTION
    1. Met à jour la version dans pubspec.yaml.
    2. Compile l'APK de production signé avec le Keystore officiel.
    3. Calcule l'empreinte cryptographique SHA-256 et la taille exacte en octets.
    4. Met à jour vitrine/version.json et web/version.json avec les nouvelles métadonnées.
    5. Copie l'APK dans vitrine/downloads/DubaGest-Android.apk.
.EXAMPLE
    .\scripts\publier_mise_a_jour.ps1 -Version "1.0.1" -Build 2 -Notes @("Verrouillage abonnement", "Correctifs visuels")
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [int]$Build,

    [Parameter(Mandatory=$false)]
    [string[]]$Notes = @("Amélioration des performances", "Mise à jour de sécurité et corrections"),

    [Parameter(Mandatory=$false)]
    [switch]$ForceUpdate = $false
)

$ErrorActionPreference = "Stop"
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  DubaGest — Procédure de publication de version v$Version+$Build" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

# 1. Mise à jour de pubspec.yaml
Write-Host "`n[1/5] Mise à jour de pubspec.yaml..." -ForegroundColor Cyan
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
$pubspecContent = $pubspecContent -replace "(?m)^version:\s*.*$", "version: $Version+$Build"
Set-Content -Path $pubspecPath -Value $pubspecContent -NoNewline
Write-Host "  -> Version positionnée à : $Version+$Build" -ForegroundColor DarkGreen

# 2. Compilation de l'APK signé
Write-Host "`n[2/5] Compilation de l'APK de production officiel..." -ForegroundColor Cyan
flutter build apk --release
$apkSource = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkSource)) {
    throw "Erreur: le fichier $apkSource est introuvable après compilation."
}

# 3. Calcul SHA-256 et taille
Write-Host "`n[3/5] Calcul de l'empreinte cryptographique SHA-256..." -ForegroundColor Cyan
$fileHash = (Get-FileHash -Path $apkSource -Algorithm SHA256).Hash.ToLower()
$fileSize = (Get-Item $apkSource).Length
Write-Host "  -> Taille : $fileSize octets ($([math]::Round($fileSize/1MB, 2)) Mo)" -ForegroundColor DarkGreen
Write-Host "  -> SHA-256 : $fileHash" -ForegroundColor DarkGreen

# 4. Copie de l'APK dans vitrine/downloads/
Write-Host "`n[4/5] Déploiement local de l'APK..." -ForegroundColor Cyan
$destinationApk = "vitrine\downloads\DubaGest-Android.apk"
if (-not (Test-Path "vitrine\downloads")) {
    New-Item -ItemType Directory -Path "vitrine\downloads" | Out-Null
}
Copy-Item -Path $apkSource -Destination $destinationApk -Force
Write-Host "  -> Copié vers : $destinationApk" -ForegroundColor DarkGreen

# 5. Mise à jour du manifeste version.json
Write-Host "`n[5/5] Mise à jour des manifestes Cloudflare (vitrine & web)..." -ForegroundColor Cyan
$today = (Get-Date).ToString("yyyy-MM-dd")
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$manifestObject = [ordered]@{
    version = 1
    updated_at = $timestamp
    android = [ordered]@{
        latest_version = $Version
        version_code = $Build
        minimum_supported_version = if ($ForceUpdate) { $Version } else { "1.0.0" }
        minimum_supported_code = if ($ForceUpdate) { $Build } else { 1 }
        apk_url = "https://dubagest.com/downloads/DubaGest-Android.apk"
        sha256 = $fileHash
        file_size = $fileSize
        force_update = [bool]$ForceUpdate
        release_date = $today
        release_notes = $Notes
    }
    pwa = [ordered]@{
        latest_version = $Version
        minimum_supported_version = if ($ForceUpdate) { $Version } else { "1.0.0" }
        force_update = [bool]$ForceUpdate
        release_date = $today
        release_notes = $Notes
    }
}

$manifestJson = $manifestObject | ConvertTo-Json -Depth 5
Set-Content -Path "vitrine\version.json" -Value $manifestJson -Encoding UTF8
Set-Content -Path "web\version.json" -Value $manifestJson -Encoding UTF8
Write-Host "  -> vitrine/version.json et web/version.json synchronisés avec succès !" -ForegroundColor DarkGreen

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  Publication locale prête ! Pour déployer sur Cloudflare :" -ForegroundColor Yellow
Write-Host "  git add ." -ForegroundColor White
Write-Host "  git commit -m `"release: publication de la version $Version+$Build`"" -ForegroundColor White
Write-Host "  git push origin feature/vitrine-portail-pwa" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
