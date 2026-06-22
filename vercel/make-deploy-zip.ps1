# Build a clean fuckmark deploy zip (no secrets, no node_modules).
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$VercelDir = Join-Path $RepoRoot "vercel"
$Staging = Join-Path $env:TEMP "hollow-fuckmark-deploy"
$ZipPath = Join-Path $RepoRoot "fuckmark-deploy.zip"

& (Join-Path $RepoRoot "sync-to-vercel.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (Test-Path $Staging) { Remove-Item $Staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Staging | Out-Null

$excludeNames = @(
    ".env",
    ".env.local",
    ".env.example",
    ".admin-secret.txt",
    ".vercel",
    "node_modules",
    "make-deploy-zip.ps1"
)

function Copy-TreeFiltered {
    param([string]$Source, [string]$Dest)
    Get-ChildItem -Path $Source -Force | ForEach-Object {
        if ($excludeNames -contains $_.Name) { return }
        $target = Join-Path $Dest $_.Name
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Force -Path $target | Out-Null
            Copy-TreeFiltered -Source $_.FullName -Dest $target
        } else {
            Copy-Item -Path $_.FullName -Destination $target -Force
        }
    }
}

Copy-TreeFiltered -Source $VercelDir -Dest $Staging

if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path (Join-Path $Staging "*") -DestinationPath $ZipPath -Force
Remove-Item $Staging -Recurse -Force

$fileCount = (Get-ChildItem -Path $VercelDir -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($VercelDir.Length + 1)
    $top = $rel.Split('\')[0]
    $name = $_.Name
    -not ($excludeNames -contains $name) -and $top -ne "node_modules" -and $top -ne ".vercel"
}).Count

Write-Host ""
Write-Host "Created: $ZipPath" -ForegroundColor Green
Write-Host "Deploy files: $fileCount (under GitHub's 100-file web limit if you upload the vercel folder)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Option A - GitHub web (easiest):" -ForegroundColor Yellow
Write-Host "  Upload ONLY the folder: $VercelDir"
Write-Host "  (not the whole Hollow folder - that has 100+ files)"
Write-Host ""
Write-Host "Option B - Git push:" -ForegroundColor Yellow
Write-Host "  cd $VercelDir"
Write-Host "  git init"
Write-Host "  git add ."
Write-Host "  git commit -m ""update hollow script"""
Write-Host "  git remote add origin YOUR_FUCKMARK_REPO_URL"
Write-Host "  git push -u origin main"
Write-Host ""
Write-Host "Option C - Vercel CLI:" -ForegroundColor Yellow
Write-Host "  cd $VercelDir"
Write-Host "  vercel --prod"
