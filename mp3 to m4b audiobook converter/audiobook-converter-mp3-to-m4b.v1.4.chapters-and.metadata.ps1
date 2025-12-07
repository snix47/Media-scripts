<#
    === Audiobook re-encoder .mp3 -> .m4b === 

Version 1.4

This script re-encodes all .mp3 files in a subdir to one single
AAC .m4b (128 kbps) iOS Book file, the ones you play in your iphone.

It ads the following metadata to the file: authour, title, year and chapters.

The information is extracet from the subdir name itself, and the .mp3 files.
  it expects this format: <author> - <title> (<year>) on subdir.

Dependecies:
        ffprobe.exe (full build https://www.gyan.dev/ffmpeg/builds/)
        ffmpeg.exe (full build https://www.gyan.dev/ffmpeg/builds/)

A SIMPLE tool to synch PC <-> iPhone media with is: 3uTools (https://www.3u.com)
#>

# Path to ffmpeg.exe
$ffmpeg_path = "m:\mp3-old\!script\ffmpeg.exe"

# Automatically detect ffprobe in the same directory as ffmpeg
$ffprobe_path = Join-Path (Split-Path $ffmpeg_path) "ffprobe.exe"

# Input directory containing subfolders with MP3 files
$input_directory = "m:\mp3-old\!convertebooks\"

# Verify tools exist
if (-not (Test-Path $ffmpeg_path)) {
    Write-Error "ffmpeg not found at $ffmpeg_path"
    exit 1
}
if (-not (Test-Path $ffprobe_path)) {
    Write-Error "ffprobe not found at $ffprobe_path"
    exit 1
}

# Go through all subdirectories in the input directory
Get-ChildItem -Path $input_directory -Directory | ForEach-Object {
    $bookDir = $_.FullName
    $bookName = $_.Name

    # Extract metadata from directory name
    # Expected format: "Author - Title (Year)" or "Author - Title"
    $author = ""
    $title = ""
    $year = ""

    if ($bookName -match '^(.*?)\s*-\s*(.*?)\s*\((\d{4})\)$') {
        $author = $matches[1].Trim()
        $title = $matches[2].Trim()
        $year = $matches[3].Trim()
    } elseif ($bookName -match '^(.*?)\s*-\s*(.*)$') {
        $author = $matches[1].Trim()
        $title = $matches[2].Trim()
    } else {
        $title = $bookName.Trim()
    }

    # Collect all mp3 files in this subdir
    $mp3Files = Get-ChildItem -Path $bookDir -Filter *.mp3 | Sort-Object Name

    if ($mp3Files.Count -eq 0) {
        Write-Output "No mp3 files found in $bookDir"
        return
    }

    # Paths for temporary and output files
    $outputFile = Join-Path $bookDir "$bookName.m4b"
    $listFile = Join-Path $bookDir "file_list.txt"
    $metaFile = Join-Path $bookDir "metadata.txt"

    # Clean up any old temp files
    Remove-Item $listFile, $metaFile -ErrorAction SilentlyContinue

    # Create concat list for ffmpeg
    $mp3Files | ForEach-Object {
        "file '$($_.FullName)'" | Out-File -FilePath $listFile -Append -Encoding ASCII
    }

    # Generate chapter metadata
    $chapterIndex = 0
    $currentStart = 0
    foreach ($mp3 in $mp3Files) {
        # Get duration of this MP3 using ffprobe
        $duration = & $ffprobe_path -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -i $mp3.FullName 2>$null
        try {
            $duration = [double]::Parse($duration, [System.Globalization.CultureInfo]::InvariantCulture)
        } catch {
            Write-Warning "Could not read duration for $($mp3.Name). Skipping chapter length."
            $duration = 0
        }

        $chapterIndex++
        $chapterStart = [math]::Round($currentStart * 1000)
        $chapterEnd   = [math]::Round(($currentStart + $duration) * 1000)
        $chapterTitle = [System.IO.Path]::GetFileNameWithoutExtension($mp3.Name)

        Add-Content -Path $metaFile -Value "[CHAPTER]"
        Add-Content -Path $metaFile -Value "TIMEBASE=1/1000"
        Add-Content -Path $metaFile -Value "START=$chapterStart"
        Add-Content -Path $metaFile -Value "END=$chapterEnd"
        Add-Content -Path $metaFile -Value "title=$chapterTitle"

        $currentStart += $duration
    }

    Write-Output "Encoding and merging $($mp3Files.Count) MP3s into $outputFile ..."
    Write-Output "Author: $author | Title: $title | Year: $year"

    # Build ffmpeg metadata arguments (for iOS Books compatibility)
    $metadataArgs = @()
    if ($author) { $metadataArgs += "-metadata"; $metadataArgs += "artist=$author" }
    if ($title)  { $metadataArgs += "-metadata"; $metadataArgs += "album=$title" }
    if ($title)  { $metadataArgs += "-metadata"; $metadataArgs += "title=$title" }
    if ($year)   { $metadataArgs += "-metadata"; $metadataArgs += "date=$year" }

    # Run ffmpeg with chapters and metadata
    & $ffmpeg_path -f concat -safe 0 -i $listFile -i $metaFile -map_metadata 1 @metadataArgs -c:a aac -b:a 128k -vn -movflags +faststart $outputFile

    if ($LASTEXITCODE -eq 0 -and (Test-Path $outputFile)) {
        Write-Output "✅ Successfully created $outputFile"
        # Remove mp3 files
        $mp3Files | Remove-Item -Force
        # Remove temporary files
        Remove-Item $listFile, $metaFile -Force
    } else {
        Write-Error "❌ Failed to create $outputFile"
    }
}
