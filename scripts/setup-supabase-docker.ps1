# Downloads official Supabase self-hosted Docker files into supabase/docker/
# Required once before: docker compose up -d

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Target = Join-Path $Root "supabase\docker"
$Temp = Join-Path $Root "supabase\_upstream"

Write-Host "==> Rased: Supabase Docker setup" -ForegroundColor Cyan

if (Test-Path (Join-Path $Target "docker-compose.yml")) {
    Write-Host "    supabase/docker already exists. Skipping clone." -ForegroundColor Yellow
    Write-Host "    Delete supabase/docker to re-fetch." -ForegroundColor Yellow
    exit 0
}

if (Test-Path $Temp) {
    Remove-Item -Recurse -Force $Temp
}

Write-Host "    Cloning supabase/supabase (docker folder only)..." -ForegroundColor Gray
git clone --depth 1 --filter=blob:none --sparse https://github.com/supabase/supabase.git $Temp
Push-Location $Temp
git sparse-checkout set docker
Pop-Location

New-Item -ItemType Directory -Force -Path (Split-Path $Target) | Out-Null
if (Test-Path $Target) {
    Remove-Item -Recurse -Force $Target
}
Move-Item (Join-Path $Temp "docker") $Target

Remove-Item -Recurse -Force $Temp

Write-Host "    Done: $Target" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. copy .env.example .env"
Write-Host "  2. (optional) cd supabase\docker && sh utils/generate-keys.sh"
Write-Host "  3. docker compose up -d"
Write-Host "  4. .\scripts\run-migration.ps1"
