param(
    [string]$Rvpm = "rvpm",
    [switch]$Keep
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Push-Location $repo
try {
    docker compose up -d --wait
    $env:RAVEN_POSTGRES_E2E = "1"
    $env:RAVEN_POSTGRES_HOST = "127.0.0.1"
    $env:RAVEN_POSTGRES_PORT = if ($env:RAVEN_POSTGRES_PORT) { $env:RAVEN_POSTGRES_PORT } else { "55432" }
    $env:RAVEN_POSTGRES_USER = "raven"
    $env:RAVEN_POSTGRES_PASSWORD = "ravenpw"
    $env:RAVEN_POSTGRES_DATABASE = "ravendb"
    & $Rvpm test
    if ($LASTEXITCODE -ne 0) {
        throw "rvpm test failed with exit code $LASTEXITCODE"
    }
} finally {
    if (-not $Keep) {
        docker compose down --volumes
    }
    Pop-Location
}

