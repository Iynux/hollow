# Hollow - hook up KV/Redis on vercel.com/hollow2/fuckmark
$ErrorActionPreference = "Stop"
$VercelDir = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "=== Hollow fuckmark KV setup ===" -ForegroundColor Cyan
Write-Host ""

$adminSecret = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
Write-Host "Generated ADMIN_SECRET:" -ForegroundColor Yellow
Write-Host $adminSecret
Write-Host "Copy into discord-bot/config.json as vercel_admin_secret" -ForegroundColor Yellow
Write-Host ""

Write-Host "STEP 1 - Create Redis on Vercel" -ForegroundColor Green
Write-Host "  1. Open https://vercel.com/hollow2/fuckmark/stores"
Write-Host "  2. Click Create Database -> Redis (Upstash)"
Write-Host "  3. Connect it to project fuckmark"
Write-Host "  4. Vercel adds KV_REST_API_URL and KV_REST_API_TOKEN automatically"
Write-Host ""

Write-Host "STEP 2 - Set ADMIN_SECRET on Vercel" -ForegroundColor Green
Write-Host "  1. Open https://vercel.com/hollow2/fuckmark/settings/environment-variables"
Write-Host "  2. Add ADMIN_SECRET with the value above"
Write-Host "  3. Enable for Production, Preview, Development"
Write-Host ""

$open = "n"
if ($args -notcontains "-NonInteractive") {
    $open = Read-Host "Open Vercel stores page in browser now? (y/n)"
}
if ($open -eq "y") {
    Start-Process "https://vercel.com/hollow2/fuckmark/stores"
}

Write-Host ""
Write-Host "STEP 3 - Pull env and seed KV" -ForegroundColor Green
Write-Host "  cd $VercelDir"
Write-Host "  vercel link --project fuckmark"
Write-Host "  vercel env pull .env.local"
Write-Host "  python scripts/seed-kv.py"
Write-Host ""

Write-Host "STEP 4 - Redeploy" -ForegroundColor Green
Write-Host "  cd $VercelDir"
Write-Host "  vercel deploy --prod"
Write-Host ""

Write-Host "STEP 5 - Verify" -ForegroundColor Green
Write-Host "  https://fuckmark.vercel.app/api/health should show kv: connected"
Write-Host ""

$secretFile = Join-Path $VercelDir ".admin-secret.txt"
Set-Content -Path $secretFile -Value $adminSecret -Encoding UTF8
Write-Host "ADMIN_SECRET saved to $secretFile" -ForegroundColor DarkGray
