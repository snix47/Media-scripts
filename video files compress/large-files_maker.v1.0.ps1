<#

 large-file_makerv.ps1 1.0 - working script
 
This script makes a list of all videofiles of a certain size, and is used
  with handbrake.cli so that it has input for batch re-encoding of large videofiles
  and make them smaller. The output is a textfile.

First run this script to make the list of large files
  then run the handbrake-v1.2.bat script to reduce them in size.

Enter path to files and the size of the files you´re after into the variables.

#>
clear

# Get the directory where the script resides
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# Set the directory to search in
$searchdir = "x:\your dir with videofiles"

# Set the size threshold in gigabytes
$size = 2

# Create or overwrite large-files.txt in the script directory
$outputFile = Join-Path -Path $scriptDirectory -ChildPath "large-files.txt"
Remove-Item -Path $outputFile -ErrorAction SilentlyContinue

# Initialize counters
$totalMovies = 0
$totalSizeGB = 0

# Function to calculate size in human-readable format
function Format-Size {
    param([double]$size)
    $units = "Bytes", "KB", "MB", "GB", "TB"
    $index = 3
    while ($size -ge 1024 -and $index -lt 4) {
        $size = $size / 1024
        $index++
    }
    "{0:N2} {1}" -f $size, $units[$index]
}

# Recursive function to search for large movie files
function Search-LargeMovies {
    param([string]$dir)
    
    $files = Get-ChildItem -Path $dir -File -Include *.avi, *.mkv, *.mp4 -Recurse
    
    $files | Where-Object { $_.Length -gt ($size * 1GB) } | Sort-Object -Property Name | ForEach-Object {
        $totalMovies++
        $totalSizeGB += $_.Length / 1GB  # Convert bytes to gigabytes
        $fileName = $_.Name
        Write-Host "$($_.DirectoryName.Replace($searchdir, ''))\$fileName" -ForegroundColor Green
        Add-Content -Path $outputFile -Value "$($_.DirectoryName.Replace($searchdir, ''))\$fileName"
    }
}

# Call the function to search for large movie files
Search-LargeMovies $searchdir

# Output summary
$summary = "Movies found exceeding $size Gigabyte."
Write-Host $summary
# Add-Content -Path $outputFile -Value $summary
