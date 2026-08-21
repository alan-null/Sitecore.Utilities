<#
.SYNOPSIS
    Generates one Sitecore resource package (.dat) per module using Sitecore CLI.
.DESCRIPTION
    Discovers all *.module.json files under modules/ and runs
    'dotnet sitecore res-pkg create' for each namespace, outputting to _out/.
    Run Generate-Modules.ps1 first to ensure module files are up to date.
#>

Push-Location $PSScriptRoot

$repoRoot    = Resolve-Path (Join-Path $PSScriptRoot "..")
$modulesRoot = Join-Path $repoRoot "modules"
$outRoot     = Join-Path $repoRoot "_out"

# Ensure the Sitecore CLI local tool is available
Push-Location $repoRoot
dotnet tool restore
Pop-Location

# Remove stale serialization index files to avoid caching issues
Get-ChildItem -Path $repoRoot -Recurse -Filter ".scindex" -ErrorAction SilentlyContinue | Remove-Item -Force

New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$moduleFiles = Get-ChildItem -Path $modulesRoot -Recurse -Filter "*.module.json" -File
if (-not $moduleFiles) {
    Write-Warning "No module files found under $modulesRoot. Run Generate-Modules.ps1 first."
    Pop-Location
    exit 1
}

foreach ($moduleFile in $moduleFiles) {
    $module    = Get-Content -Raw $moduleFile.FullName | ConvertFrom-Json
    $namespace = $module.namespace
    $outPath   = Join-Path $outRoot $namespace

    Write-Host "Packaging: $namespace" -ForegroundColor Cyan
    dotnet sitecore res-pkg create -o $outPath --overwrite -i $namespace
}

Write-Host "`nDone. Packages written to: $outRoot" -ForegroundColor Yellow

Pop-Location
