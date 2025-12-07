<#
	    v 2.6
	    Correct filedate for .png files using regex, now supports both Date Created formats
        the filedate often fail when synching with iPhones etc..  this will correct that
        -----------------------------------------------------------------------------------
.SYNOPSIS
	- sets .png file CreationTime and LastWriteTime from EXIF Date/Time Created

.DESCRIPTION
	- scans scriptdir for .png files
	- extracts EXIF date/time from:
          1) "Date Created : YYYY:MM:DD HH:MM:SS"
          2) "Date Created : YYYY:MM:DD" + "Time Created : HH:MM:SS"
          3) "Date/Time Created : YYYY:MM:DD HH:MM:SS"
	- sets CreationTime and LastWriteTime

	Dependencies:
    	- exiftool.exe (https://exiftool.org/install.html#Windows)
        - "exiftool_files" subdir from the exiftool zipfile
          the above needs to be in the script folder
#>

# --------------------------
# Clear screen
# --------------------------
if (Get-Command Clear-Host -ErrorAction SilentlyContinue) { Clear-Host }

# --------------------------
# Script directory
# --------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# --------------------------
# Loop through all PNG files
# --------------------------
$PngFiles = Get-ChildItem -Path $ScriptDir -Filter *.png
foreach ($File in $PngFiles) {

    Write-Host "Processing file: $($File.Name)"

    $FilePath = $File.FullName

    # Extract EXIF output
    $ExifOutput = & "$ScriptDir\exiftool.exe" $FilePath
    $ExifOutput = $ExifOutput | ForEach-Object { $_.Trim() }
    $ExifOutput = $ExifOutput | Where-Object { $_ -notmatch '^--' }

    # --------------------------
    # 1: Try full "Date Created" (date + time)
    # --------------------------
    $DateCreatedFull = $ExifOutput | Where-Object { $_ -match '^Date Created\s*:\s*\d{4}:\d{2}:\d{2} \d{2}:\d{2}:' }

    # --------------------------
    # 2: Try split "Date Created" (date only) + "Time Created" (time)
    # --------------------------
    $DateCreatedDateOnly = $ExifOutput | Where-Object { $_ -match '^Date Created\s*:\s*\d{4}:\d{2}:\d{2}$' }
    $TimeCreatedLine     = $ExifOutput | Where-Object { $_ -match '^Time Created\s*:\s*\d{2}:\d{2}:' }

    # --------------------------
    # 3: Try "Date/Time Created"
    # --------------------------
    $DateTimeCreated = $ExifOutput | Where-Object { $_ -match '^Date/Time Created\s*:' }

    # --------------------------
    # Choose the best timestamp available
    # --------------------------
    $DateLine = $null

    if ($DateCreatedFull) {
        $DateLine = $DateCreatedFull
    }
    elseif ($DateCreatedDateOnly -and $TimeCreatedLine) {
        # merge into one line
        $DateOnly = ($DateCreatedDateOnly -replace '^Date Created\s*:\s*', '')
        $TimeOnly = ($TimeCreatedLine     -replace '^Time Created\s*:\s*', '')
        $DateLine = "Merged: $DateOnly $TimeOnly"
    }
    elseif ($DateTimeCreated) {
        $DateLine = $DateTimeCreated
    }

    if (-not $DateLine) {
        Write-Warning "No usable date fields found for $($File.Name), skipping."
        continue
    }

    Write-Host "Raw EXIF merged date: '$DateLine'"

    # --------------------------
    # Extract YYYY-MM-DD and HH:MM using regex
    # --------------------------
    if ($DateLine -match '(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2})') {

        $Year  = $Matches[1]
        $Month = $Matches[2]
        $Day   = $Matches[3]
        $Hour  = $Matches[4]
        $Min   = $Matches[5]

        $DateTimeObj = Get-Date -Year $Year -Month $Month -Day $Day -Hour $Hour -Minute $Min -Second 0

        Write-Host "Setting file date/time to: $DateTimeObj"
    }
    else {
        Write-Warning "Failed to extract valid date/time for $($File.Name)"
        continue
    }

    # --------------------------
    # Apply timestamps
    # --------------------------
    try {
        $File.CreationTime   = $DateTimeObj
        $File.LastWriteTime  = $DateTimeObj
        Write-Host "Updated $($File.Name)"
    }
    catch {
        Write-Warning "Failed to update dates for $($File.Name)"
    }
}

Write-Host "All PNG files processed."
