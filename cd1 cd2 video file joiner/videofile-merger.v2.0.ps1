<#
Version 2.0 by snix 2024-11-25

This script merges split video files.
It will look for video files in subdirs containing cd1 and cd2,
and merge them into one video file.

Dependencies:
 ffmpeg.exe is needed

 Filenames containing [ ] do not fly with powershell, you need to rename them before running the script.
 Also if script finds no files, it gives null errors onscreen (looks like it doesen´t work) but this is fine.

Please update variables below to suit your environment.
#>

# Define script variables
$ffmpegPath = "c:\ffmpeg.exe"
$scandirectory = "c:\movies\"
$splitfiles = Join-Path $scandirectory "splitfiles.txt"
$joinedfiles = Join-Path $scandirectory "joinedfiles.txt"
$scanfilestype = @(".avi", ".mp4", ".mkv")

# Create and populate the splitfiles.txt file with all split files
$splitfileList = Get-ChildItem -Path $scandirectory -Recurse -File | Where-Object { $_.Name -match "cd1|cd2" -and $scanfilestype -contains $_.Extension }

# Write the file paths to splitfiles.txt, ensuring paths with spaces are enclosed in single quotes
$splitfileList | ForEach-Object {
    $filePath = "'$($_.FullName.Trim())'"
    Write-Host "Adding to splitfiles.txt: $filePath"  # Display the file path on the screen
    Add-Content -Path $splitfiles -Value $filePath
}

# Remove BOM (Byte Order Mark) from splitfiles.txt if it exists
$encoding = [System.Text.Encoding]::UTF8
[System.IO.File]::WriteAllText($splitfiles, [System.IO.File]::ReadAllText($splitfiles, $encoding), $encoding)

# Display the menu options with colors
$splitfileList = Get-Content -Path $splitfiles

# Display the first two files for merging in yellow
Write-Host "1 merge only the first video files" -ForegroundColor Green
Write-Host "'$($splitfileList[0])'" -ForegroundColor Yellow
Write-Host "'$($splitfileList[1])'" -ForegroundColor Yellow

# Display the full list of options in green
Write-Host "2 merge all the videos" -ForegroundColor Green
Write-Host "3 quit the script without merging any files" -ForegroundColor Green

# Prompt for user input
$menuChoice = Read-Host "Please select an option (1, 2, or 3)"

# Section Locked: Verified as working. Do not edit without explicit instructions.

# Merge the cd1 and cd2 files in each subdir
$splitfileList = Get-Content -Path $splitfiles

switch ($menuChoice) {
    1 {
        Write-Host "You selected to merge only the first video files." -ForegroundColor Green
        # Code to merge only the first pair of video files
        $firstFileProcessed = $false
        foreach ($splitfile in $splitfileList) {
            Write-Host "Processing file: '$splitfile'" -ForegroundColor Cyan

            # Remove extra quotes around the file paths and trim spaces
            $splitfile = $splitfile.Trim("'").Trim()  # Trim both single quotes and spaces

            # Extract the cd1 and cd2 file paths
            if ($splitfile -match "(.*?)(cd1)(.*)$") {
                $cd1File = $splitfile
                $cd2File = $splitfile -replace "cd1", "cd2"

                Write-Host "Checking existence of cd1: '$cd1File' and cd2: '$cd2File'" -ForegroundColor Yellow

                # Ensure both cd1 and cd2 files exist by checking them separately
                if (Test-Path $cd1File) {
                    Write-Host "cd1 file exists: '$cd1File'" -ForegroundColor Green
                    if (Test-Path $cd2File) {
                        Write-Host "cd2 file exists: '$cd2File'" -ForegroundColor Green

                        # Remove spaces before "cd1" and "cd2" from the filename
                        $outputFile = $cd1File -replace "\s*cd1", "" | ForEach-Object { $_.Trim() } | ForEach-Object { $_.Replace("\\", "\") }

                        # Remove any trailing spaces in the filename
                        $outputFile = $outputFile.Trim()

                        # Display the merging action
                        Write-Host "Merging files: '$cd1File' and '$cd2File'" -ForegroundColor Green

                        # Run ffmpeg to merge the files
                        & "$ffmpegPath" -i "concat:$cd1File|$cd2File" -c copy $outputFile

                        Write-Host "Merged output file: '$outputFile'" -ForegroundColor Green

                        # Mark the first file as processed and exit the loop
                        $firstFileProcessed = $true
                        break
                    } else {
                        Write-Host "cd2 file does not exist: '$cd2File'" -ForegroundColor Red
                    }
                } else {
                    Write-Host "cd1 file does not exist: '$cd1File'" -ForegroundColor Red
                }
            }
        }
        # Inform the user if the first video pair was processed
        if (-not $firstFileProcessed) {
            Write-Host "No files were merged. Please check the input files." -ForegroundColor Red
        }
    }
    2 {
        Write-Host "You selected to merge all the videos." -ForegroundColor Green

        # Loop through all the split files and merge them in pairs
        foreach ($splitfile in $splitfileList) {
            Write-Host "Processing file: '$splitfile'" -ForegroundColor Cyan

            # Remove extra quotes around the file paths and trim spaces
            $splitfile = $splitfile.Trim("'").Trim()

            # Extract the cd1 and cd2 file paths
            if ($splitfile -match "(.*?)(cd1)(.*)$") {
                $cd1File = $splitfile
                $cd2File = $splitfile -replace "cd1", "cd2"

                Write-Host "Checking existence of cd1: '$cd1File' and cd2: '$cd2File'" -ForegroundColor Yellow

                # Ensure both cd1 and cd2 files exist by checking them separately
                if (Test-Path $cd1File) {
                    Write-Host "cd1 file exists: '$cd1File'" -ForegroundColor Green
                    if (Test-Path $cd2File) {
                        Write-Host "cd2 file exists: '$cd2File'" -ForegroundColor Green

                        # Remove spaces before "cd1" and "cd2" from the filename
                        $outputFile = $cd1File -replace "\s*cd1", "" | ForEach-Object { $_.Trim() } | ForEach-Object { $_.Replace("\\", "\") }

                        # Remove any trailing spaces in the filename
                        $outputFile = $outputFile.Trim()

                        # Display the merging action
                        Write-Host "Merging files: '$cd1File' and '$cd2File'" -ForegroundColor Green

                        # Run ffmpeg to merge the files
                        & "$ffmpegPath" -i "concat:$cd1File|$cd2File" -c copy $outputFile

                        Write-Host "Merged output file: '$outputFile'" -ForegroundColor Green

                        # Add the merged file path to the joinedfiles.txt
                        Add-Content -Path $joinedfiles -Value $outputFile

                    } else {
                        Write-Host "cd2 file does not exist: '$cd2File'" -ForegroundColor Red
                    }
                } else {
                    Write-Host "cd1 file does not exist: '$cd1File'" -ForegroundColor Red
                }
            }
        }
    }
    3 {
        Write-Host "Exiting the script without merging any files." -ForegroundColor Green
        exit
    }
    default {
        Write-Host "Invalid option selected. Exiting the script." -ForegroundColor Green
        exit
    }
}

