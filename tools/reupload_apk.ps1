$token = (python -c "import subprocess; p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True); out, _ = p.communicate('protocol=https\nhost=github.com\n\n'); print(dict(l.split('=', 1) for l in out.splitlines() if '=' in l).get('password', ''))").Trim()

$headers = @{
    "Authorization" = "token $token"
    "User-Agent" = "DubaGest-Deploy"
}

Write-Host "Checking existing assets on release 422706125..."
$response = Invoke-RestMethod -Uri "https://api.github.com/repos/moromali223-png/DubaGest/releases/422706125/assets" -Headers $headers -Method Get
foreach ($asset in $response) {
    if ($asset.name -eq "dubagest-release.apk") {
        Write-Host "Deleting old asset $($asset.id)..."
        Invoke-RestMethod -Uri "https://api.github.com/repos/moromali223-png/DubaGest/releases/assets/$($asset.id)" -Headers $headers -Method Delete
    }
}

Write-Host "Uploading newly signed dubagest-release.apk (106.6MB)..."
& curl.exe -sS -X POST `
  -H "Authorization: token $token" `
  -H "Content-Type: application/vnd.android.package-archive" `
  --data-binary "@build/app/outputs/flutter-apk/dubagest-release.apk" `
  "https://uploads.github.com/repos/moromali223-png/DubaGest/releases/422706125/assets?name=dubagest-release.apk"

Write-Host "`nUpload finished with exit code: $LASTEXITCODE"
