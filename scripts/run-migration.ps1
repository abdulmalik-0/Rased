# Applies Rased SQL migration to local Supabase Postgres

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SqlFile = Join-Path $Root "supabase\migrations\001_initial.sql"

if (-not (Test-Path $SqlFile)) {
    Write-Error "Migration not found: $SqlFile"
}

$running = docker ps --filter "name=supabase-db" --format "{{.Names}}" 2>$null
if (-not $running) {
    Write-Error "Container supabase-db is not running. Start stack first: docker compose up -d"
}

Write-Host "==> Applying Rased migration to supabase-db..." -ForegroundColor Cyan
Get-Content $SqlFile -Raw | docker exec -i supabase-db psql -U postgres -d postgres
Write-Host "    Migration complete." -ForegroundColor Green
