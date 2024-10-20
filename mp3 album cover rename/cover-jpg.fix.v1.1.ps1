<#
cover-jpg.fix.v1.1.ps1 - v1.1 bulk cover jpg files renamer

This script takes care of .jpg files in mp3 album directories, so that the naming
of said files work with media frontends like jellyfin, emby and plex.

A little bit of house cleaning.

Give it a directory and it will plow throgh all subdirs and name the .jpg files to cover.jpg
If You have multiple .jpg files You need to decide which one to keep.
#>


# Clear the screen
Clear-Host

# Start measure time for the script
$StartTime = Get-Date

# Input directory
$rootDirectory = "x:\your mp3 dir\"

# Define the log file path and name
$logFile = $PSScriptRoot + "\" + $MyInvocation.MyCommand.Name.Replace(".ps1", ".log")

# Initialize the log file
Add-Content -Path $logFile -Value "Log file for $($MyInvocation.MyCommand.Name) - $(Get-Date)"
Add-Content -Path $logFile -Value ("=" * 60)

# Function to rename the .jpg files
function Rename-JPGFiles {
    param (
        [Parameter(Mandatory=$true)]
        [string]$directory
    )

    $jpgFiles = Get-ChildItem -Path $directory -Filter "*.jpg" -File
    $jpgCount = $jpgFiles.Count

    if ($jpgCount -eq 1) {
        $oldFileName = $jpgFiles[0].FullName
        $newFileName = Join-Path -Path $directory -ChildPath "cover.jpg"
        
        if ($oldFileName -ne $newFileName) {
            Write-Host "Rename: $($jpgFiles[0].FullName) --> $($newFileName)"
            Add-Content -Path $logFile -Value "Rename: $($jpgFiles[0].FullName) --> $($newFileName)"

            # Rename the file (Tagged with # to run in safe mode)
            Rename-Item -Path $oldFileName -NewName "cover.jpg"
        }
        else {
            Write-Host "File $($jpgFiles[0].FullName) is already named cover.jpg. Skipping."
        }
    } elseif ($jpgCount -eq 0) {
        Write-Host "No .jpg file found in $($directory)"
    } else {
        Write-Host "Multiple .jpg files found in $($directory)"
    }
}

# Recursively scan and rename .jpg files
$allDirectories = Get-ChildItem -Path $rootDirectory -Directory -Recurse
foreach ($directory in $allDirectories) {
    Rename-JPGFiles -directory $directory.FullName
}

# End measure time and calculate script execution time
$EndTime = Get-Date
$TotalTime = $EndTime - $StartTime

Write-Host "Script execution time: " + $TotalTime.ToString('hh\:mm\:ss')
