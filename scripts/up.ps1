# Start full Rased + Supabase stack

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

if (-not (Test-Path "supabase\docker\docker-compose.yml")) {
    Write-Host "Supabase docker files missing. Running setup..." -ForegroundColor Yellow
    & "$Root\scripts\setup-supabase-docker.ps1"
}

if (-not (Test-Path ".env")) {
    Write-Host "Creating .env from .env.example ..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host "Edit .env secrets before production use." -ForegroundColor Yellow
}

if (-not (Test-Path "frontend\build\web\index.html")) {
    Write-Warning "frontend/build/web not found. Build Flutter web first (see README)."
}

Write-Host "==> Starting Rased stack (Kong:8003, API:8002, UI:8082)..." -ForegroundColor Cyan
docker compose up -d --build @args

Write-Host ""
Write-Host "URLs:" -ForegroundColor Green
Write-Host "  Rased UI:        http://localhost:8082"
Write-Host "  Rased API:       http://localhost:8002/docs"
Write-Host "  Supabase (Kong): http://localhost:8003"
Write-Host ""
Write-Host "Run migration if first time: .\scripts\run-migration.ps1"
