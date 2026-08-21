<#
.SYNOPSIS
    Generates Sitecore CLI module.json files from Unicorn serialization config files.
.DESCRIPTION
    Scans Feature and Foundation layers under src/ for *.config files containing
    Unicorn configurations and outputs a corresponding *.module.json per configuration
    into modules/Feature/ and modules/Foundation/.
#>

Push-Location $PSScriptRoot

$repoRoot    = Resolve-Path (Join-Path $PSScriptRoot "..")
$sourceRoot  = Join-Path $repoRoot "src"
$modulesRoot = Join-Path $repoRoot "modules"

function Get-RelativePath {
    param([string]$from, [string]$to)
    $fromParts = $from.TrimEnd('\') -split '\\'
    $toParts   = $to.TrimEnd('\')  -split '\\'
    $i = 0
    while ($i -lt $fromParts.Count -and $i -lt $toParts.Count -and $fromParts[$i] -eq $toParts[$i]) { $i++ }
    $ups   = '../' * ($fromParts.Count - $i)
    $downs = $toParts[$i..($toParts.Count - 1)] -join '/'
    return ($ups + $downs).TrimEnd('/')
}

function Get-IncludeScope([System.Xml.XmlElement]$include) {
    if ($include.exclude.children -eq "true") {
        return "SingleItem"
    }
    return "ItemAndDescendants"
}

function New-ModuleJson {
    param(
        [System.Xml.XmlElement]$unicornConfig,
        [string]$outputFolder
    )

    $namespace = $unicornConfig.name
    if (-not $unicornConfig.targetDataStore) { return }

    # Translate $(sourceFolder) to absolute path, then make relative to sitecore.json dir
    # (~/  in module.json resolves to the sitecore.json directory, i.e. $repoRoot)
    $absSerializationPath = $unicornConfig.targetDataStore.physicalRootPath `
        -replace [regex]::Escape('$(sourceFolder)'), $sourceRoot
    $relPath = Get-RelativePath -from $repoRoot -to $absSerializationPath

    $includes = @($unicornConfig.predicate.include | ForEach-Object {
        [ordered]@{
            name     = $_.name
            database = $_.database
            path     = $_.path
            scope    = (Get-IncludeScope $_)
        }
    })

    $result = [ordered]@{
        namespace = $namespace
        items     = [ordered]@{
            path     = "~/$relPath"
            includes = $includes
        }
    }

    $outFile = Join-Path $outputFolder "$namespace.module.json"
    $result | ConvertTo-Json -Depth 10 | Set-Content $outFile -Encoding UTF8 -NoNewline
    Write-Host "  $namespace" -ForegroundColor Green
}

function Invoke-GenerateLayer {
    param([string]$layer)

    $layerSourcePath = Join-Path $sourceRoot $layer
    $layerOutputPath = Join-Path $modulesRoot $layer
    New-Item -ItemType Directory -Force -Path $layerOutputPath | Out-Null

    Write-Host "`n[$layer]" -ForegroundColor Cyan
    Get-ChildItem -Path $layerSourcePath -Recurse -Filter "*.config" | ForEach-Object {
        try {
            [xml]$xml = Get-Content -Raw $_.FullName
            $configs = $xml.configuration.sitecore.unicorn.configurations.configuration
            if (-not $configs) { return }
            @($configs) | Where-Object { $_ } | ForEach-Object {
                New-ModuleJson -unicornConfig $_ -outputFolder $layerOutputPath
            }
        } catch {
            Write-Warning "Skipping $($_.Name): $($_.Exception.Message)"
        }
    }
}

Invoke-GenerateLayer "Feature"
Invoke-GenerateLayer "Foundation"

Write-Host "`nDone. Module files written to: $modulesRoot" -ForegroundColor Yellow

Pop-Location
