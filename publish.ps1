#### Configuration
$deleteExistingFiles = $false
$configuration  = "Debug"

$publishsettings = ".\publishsettings.targets"
$envSpecificConfig = ".\zzz.Sitecore.Utilities.config"
####

function Resolve-MsBuild {
	$msb2017 = Resolve-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\MSBuild\*\bin\msbuild.exe" -ErrorAction SilentlyContinue
	if($msb2017) {
		Write-Host "Found MSBuild 2017 (or later)."
		Write-Host $msb2017
		return $msb2017 | Select-Object -First 1
	}

	$msBuild2015 = "${env:ProgramFiles(x86)}\MSBuild\14.0\bin\msbuild.exe"

	if(-not (Test-Path $msBuild2015)) {
		throw 'Could not find MSBuild 2015 or later.'
	}

	Write-Host "Found MSBuild 2015."
	Write-Host $msBuild2015

	return $msb2017 | Select-Object -First 1
}

function Test-ConfigExists($configName){
    if(Test-Path $configName){
        $true
    }else{
        Write-Warning "Could not find config: '$($configName)"
        Write-Warning "Make a copy of '$($currentDirectory)\$($configName).example' file. "
        Write-Warning "Then remove '.example' from the file name and fill its content with your settings."
        $false
    }
}

$MSBuildCall = Resolve-MsBuild

if(-not (Test-ConfigExists $envSpecificConfig) -or -not(Test-ConfigExists $publishsettings)){
    exit
}

[xml]$targets = Get-Content -Path $publishsettings
$publishUrl = $targets.Project.PropertyGroup.publishUrl
$siteName = (Split-Path $publishUrl -NoQualifier).TrimStart("\").TrimStart("/")

$sxa_site = Get-Website | ? { $_.Name -eq $siteName }
$publishPath = $sxa_site.physicalPath
$currentDirectory = Get-Item .

clear

Write-Host "1. Restoring Nuget packages" -ForegroundColor "Green"
.\nuget\nuget.exe restore .\Sitecore.Utilities.sln 

Write-Host "2. Building projects" -ForegroundColor "Green"
Get-ChildItem $currentDirectory.FullName -Recurse -Filter "*.csproj"| %{
    $projectPath = $_.FullName.Replace($currentDirectory.FullName,".")
    Write-Host "`tBuilding project $($_.Name)" -ForegroundColor "Cyan"
    & $MSBuildCall $projectPath /p:Configuration=$configuration /p:Platform=AnyCPU /t:WebPublish /p:WebPublishMethod=FileSystem /p:DeleteExistingFiles=$deleteExistingFiles /p:publishUrl=$publishPath /v:q
}


Write-Host "3. Deploying '$envSpecificConfig'" -ForegroundColor "Green"
Copy-Item $envSpecificConfig "$($publishPath)\App_Config\Include"