#Requires -RunAsAdministrator

<# 
.SYNOPSIS
Links filter files from the NeverSink-Filter-for-PoE2 repository to your Path of Exile 2 filters folder.

.DESCRIPTION
This script creates either hard links or symbolic links (if run as Administrator) for .filter files (and, in the case of "customsounds", .mp3 files) from a NeverSink-Filter-for-PoE2 repository to your Path of Exile 2 filters folder.
Filters can be processed by style:
  - "default": .filter files in the repository root.
  - "darkmode": .filter files in the "(STYLE) DARKMODE" subfolder.
  - "customsounds": both .filter and .mp3 files in the "(STYLE) CUSTOMSOUNDS" subfolder.
Alternatively, the special value "all" will recursively search the entire repository for all .filter and .mp3 files.
Note that hard links require both source and destination to be on the same volume, and symbolic links require administrative privileges.

.PARAMETER SourceRepoPath
**(Mandatory, Positional 0)** The file system path to the root of the NeverSink-Filter-for-PoE2 repository.

.PARAMETER PoeFilterPath
The destination folder where the filters will be linked. Default is "$env:USERPROFILE\Documents\My Games\Path of Exile 2\".

.PARAMETER UseHardLinks
If specified, the script creates hard links instead of symbolic links.
Note: Hard links require that both the source and destination directories are on the same volume.

.PARAMETER FilterSet
Specifies which filter sets to link. Valid values are "default", "darkmode", "customsounds", and "all". Multiple values can be provided.
When "all" is specified, the script will search recursively in the repository for all .filter and .mp3 files.

.EXAMPLE
.\Create-Links.ps1 "C:\Repos\NeverSink-Filter-for-PoE2" -PoeFilterPath "C:\PathOfExile2" -FilterSet default,darkmode -UseHardLinks

.EXAMPLE
.\Create-Links.ps1 "C:\Repos\NeverSink-Filter-for-PoE2" -FilterSet all

.LINK
https://github.com/NeverSinkDev/NeverSink-Filter-for-PoE2

.LINK
https://github.com/ZeeWanderer/NeverSink-Filter-for-PoE2-Tools
#>

param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$SourceRepoPath,

    [Parameter(Mandatory = $false)]
    [string]$PoeFilterPath = "$env:USERPROFILE\Documents\My Games\Path of Exile 2\",

    [Parameter(Mandatory = $false)]
    [switch]$UseHardLinks,

    [Parameter(Mandatory = $false)]
    [ValidateSet("default","darkmode","customsounds","all")]
    [string[]]$FilterSet = "default"
)

if (-not (Test-Path -Path $SourceRepoPath)) {
    Write-Host "Source repository path not found: $SourceRepoPath" -ForegroundColor Red
    exit
}

if (-not (Test-Path -Path $PoeFilterPath)) {
    Write-Host "POE2 filter directory not found: $PoeFilterPath" -ForegroundColor Red
    exit
}

if ($UseHardLinks) {
    $sourceRoot = (Get-Item $SourceRepoPath).Root
    $destRoot   = (Get-Item $PoeFilterPath).Root
    
    if ($sourceRoot -ne $destRoot) {
        Write-Host "Hard links require both directories to be on the same volume." -ForegroundColor Red
        Write-Host "Source root: $sourceRoot" -ForegroundColor Red
        Write-Host "Destination root: $destRoot" -ForegroundColor Red
        exit
    }
}
else {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Symbolic links require administrator privileges. Please run the script as Administrator." -ForegroundColor Red
        exit
    }
}

$filesToLink = @()

if ($FilterSet -contains "all") {
    $filesToLink = Get-ChildItem -Path $SourceRepoPath -Recurse -Include *.filter, *.mp3 -File -ErrorAction SilentlyContinue
}
else {

    if ($FilterSet -contains "default") {
        $defaultFilters = Get-ChildItem -Path $SourceRepoPath -Filter *.filter -File -ErrorAction SilentlyContinue
        if ($defaultFilters) {
            $filesToLink += $defaultFilters
        }
        else {
            Write-Host "No default .filter files found in $SourceRepoPath" -ForegroundColor Yellow
        }
    }

    if ($FilterSet -contains "darkmode") {
        $darkmodeFolder = Join-Path -Path $SourceRepoPath -ChildPath "(STYLE) DARKMODE"
        if (Test-Path -Path $darkmodeFolder) {
            $darkmodeFilters = Get-ChildItem -Path $darkmodeFolder -Filter *.filter -File -ErrorAction SilentlyContinue
            if ($darkmodeFilters) {
                $filesToLink += $darkmodeFilters
            }
            else {
                Write-Host "No darkmode .filter files found in $darkmodeFolder" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "Darkmode folder not found: $darkmodeFolder" -ForegroundColor Red
        }
    }

    if ($FilterSet -contains "customsounds") {
        $customsoundsFolder = Join-Path -Path $SourceRepoPath -ChildPath "(STYLE) CUSTOMSOUNDS"
        if (Test-Path -Path $customsoundsFolder) {
            $customsoundsFilters = Get-ChildItem -Path $customsoundsFolder -Filter *.filter -File -ErrorAction SilentlyContinue
            if ($customsoundsFilters) {
                $filesToLink += $customsoundsFilters
            }
            else {
                Write-Host "No customsounds .filter files found in $customsoundsFolder" -ForegroundColor Yellow
            }
            
            $customsoundsMp3 = Get-ChildItem -Path $customsoundsFolder -Filter *.mp3 -File -ErrorAction SilentlyContinue
            if ($customsoundsMp3) {
                $filesToLink += $customsoundsMp3
            }
            else {
                Write-Host "No MP3 files found in $customsoundsFolder" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "Customsounds folder not found: $customsoundsFolder" -ForegroundColor Red
        }
    }
}

if ($filesToLink.Count -eq 0) {
    Write-Host "No files found for the selected filter sets." -ForegroundColor Yellow
    exit
}

# Define the link type for display and linking.
$linkType = if ($UseHardLinks) { "hard" } else { "symbolic" }

foreach ($file in $filesToLink) {
    $targetPath = Join-Path -Path $PoeFilterPath -ChildPath $file.Name
    
    if (Test-Path -Path $targetPath) {
        Write-Host "Skipping existing file: $($file.Name)" -ForegroundColor Yellow
        continue
    }

    try {
        if ($UseHardLinks) {
            New-Item -ItemType HardLink -Path $targetPath -Value $file.FullName | Out-Null
        }
        else {
            New-Item -ItemType SymbolicLink -Path $targetPath -Target $file.FullName | Out-Null
        }
        Write-Host "Created $linkType link for: $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create $linkType link for: $($file.Name)" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

Write-Host "`nLink creation process completed." -ForegroundColor Cyan
