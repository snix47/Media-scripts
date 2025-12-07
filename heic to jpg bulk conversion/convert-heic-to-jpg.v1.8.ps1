<#
        v 1.8
        heictojpeg.exe powershell wrapper with .jpg correct file date corresponding to Date/Time Original
        -------------------------------------------------------------------------------------------------
.SYNOPSIS
    - Converts .heic files to .jpg files and sets Creation/Modified time from JPG EXIF Date Taken

.DESCRIPTION
    - Scans script directory for .heic files
    - Converts .heic to .jpg using heictojpeg.exe
    - Uses exiftool.exe to read Date Taken (Date/Time Original)
    - Sets JPG CreationTime and LastWriteTime to the Date Taken (Date/Time Original)

Dependencies:
    - heictojpeg.exe (https://github.com/cckalen/heictojpeg/blob/main/heictojpeg.exe)
    - exiftool.exe (https://exiftool.org) and the whole "exiftool_files" subdir

Required:
    - script, heictojpeg.exe, exiftool.exe and "exiftool_files" dir needs to be in the same folder as the .heic files
      so copy convert-heic-to-jpg.v1.8.ps1, heictojpeg.exe, exiftool.exe and exiftool_files into the foto dir and
      then run it.
#>

Clear-Host

# --------------------------
# Determine script directory
# --------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# --------------------------
# Remove the "downloaded from internet" mark - only works on local drives
# --------------------------
Unblock-File -Path "$scriptDir\heictojpeg.exe" -ErrorAction SilentlyContinue
Unblock-File -Path "$scriptDir\exiftool.exe" -ErrorAction SilentlyContinue

# --------------------------
# Check for required binaries
# --------------------------
$heictojpeg = Join-Path $scriptDir "heictojpeg.exe"
$exiftool   = Join-Path $scriptDir "exiftool.exe"

if (-Not (Test-Path $heictojpeg)) {
    Write-Host "heictojpeg.exe not found in script directory!" -ForegroundColor Red
    exit
}

if (-Not (Test-Path $exiftool)) {
    Write-Host "exiftool.exe not found in script directory!" -ForegroundColor Red
    exit
}

# --------------------------
# Run heictojpeg.exe
# --------------------------
Write-Host "Running heictojpeg.exe to convert HEIC files..."
Start-Process -FilePath $heictojpeg -Wait

# --------------------------
# Move and fix JPGs
# --------------------------
$jpegsDir = Join-Path $scriptDir "jpegs"
if (-Not (Test-Path $jpegsDir)) {
    Write-Host "No jpegs directory found after conversion. Exiting." -ForegroundColor Red
    exit
}

$jpgFiles = Get-ChildItem -Path $jpegsDir -Filter *.jpg -File -ErrorAction SilentlyContinue

foreach ($jpg in $jpgFiles) {
    $originalHeic = Join-Path $scriptDir ($jpg.BaseName + ".heic")
    if (-Not (Test-Path $originalHeic)) {
        Write-Host "Original HEIC not found for $($jpg.Name). Skipping." -ForegroundColor Yellow
        continue
    }

    # --------------------------
    # Move JPG to original directory
    # --------------------------
    $destination = Join-Path $scriptDir $jpg.Name
    Move-Item -Path $jpg.FullName -Destination $destination -Force

    # --------------------------
    # Setting file date using JPG EXIF Date Taken (Date/Time Original)
    # --------------------------
    try {
        # Read DateTimeOriginal from the JPG itself in EXACT format "yyyy:MM:dd HH:mm:ss"
        # Suppress warnings and stderr
        $dateTakenStr = & $exiftool -m -s -s -s -DateTimeOriginal -d "%Y:%m:%d %H:%M:%S" $destination 2>$null

        if ([string]::IsNullOrWhiteSpace($dateTakenStr)) {
            # if DateTimeOriginal empty, try a small prioritized fallback list (but you asked to prefer DateTimeOriginal)
            $fallbackFields = @("CreateDate","DateCreated","MediaCreateDate","TrackCreateDate","ModifyDate")
            foreach ($f in $fallbackFields) {
                $val = & $exiftool -m -s -s -s "-$f" -d "%Y:%m:%d %H:%M:%S" $destination 2>$null
                if (-not [string]::IsNullOrWhiteSpace($val)) { $dateTakenStr = $val; break }
            }
        }

        if ([string]::IsNullOrWhiteSpace($dateTakenStr)) {
            # final fallback: use file LastWriteTime
            Write-Host "DateTimeOriginal (and fallbacks) missing for $($destination). Using file LastWriteTime." -ForegroundColor Yellow
            $dt = (Get-Item $destination).LastWriteTime
        } else {
            # parse exact format like: 2025:01:13 14:20:52
            $dt = [datetime]::ParseExact($dateTakenStr, "yyyy:MM:dd HH:mm:ss", $null)
        }
    } catch {
        Write-Host "Could not read/parse Date Taken for $($destination), using file LastWriteTime." -ForegroundColor Yellow
        $dt = (Get-Item $destination).LastWriteTime
    }

    # --------------------------
    # Apply Date Taken timestamp
    # --------------------------
    Set-ItemProperty -Path $destination -Name CreationTime -Value $dt
    Set-ItemProperty -Path $destination -Name LastWriteTime -Value $dt

    # --------------------------
    # Remove original HEIC
    # --------------------------
    Remove-Item $originalHeic -Force

    Write-Host "Converted $($originalHeic) → $($destination) | Date Taken applied: $dt" -ForegroundColor Green
}

# --------------------------
# Cleanup jpegs directory
# --------------------------
Remove-Item $jpegsDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nAll conversions completed!" -ForegroundColor Cyan
