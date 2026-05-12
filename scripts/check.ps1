$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$courseStudio = Join-Path $repoRoot "course-studio"
$domainPackage = Join-Path $repoRoot "ios\TrueCaddieDomain"

function Invoke-Step {
    param(
        [Parameter(Mandatory)][string] $Label,
        [Parameter(Mandatory)][scriptblock] $Action
    )

    Write-Host ""
    Write-Host "==> $Label" -ForegroundColor Cyan
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed: $Label (exit $LASTEXITCODE)"
    }
}

Push-Location $courseStudio
try {
    if (-not (Test-Path (Join-Path $courseStudio "node_modules"))) {
        Invoke-Step "Installing course-studio dependencies" { npm install --silent }
    }

    Invoke-Step "Publishing pilot bundle" { npm run --silent publish:pilot }
    Invoke-Step "Validating published bundle against shared schema" { npm run --silent validate:bundle }
} finally {
    Pop-Location
}

if (Get-Command swift -ErrorAction SilentlyContinue) {
    Push-Location $domainPackage
    try {
        Invoke-Step "Running Swift domain tests" { swift test }
    } finally {
        Pop-Location
    }
} else {
    Write-Host ""
    Write-Host "==> Skipping Swift domain tests (swift CLI not found on PATH)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "All checks passed." -ForegroundColor Green
