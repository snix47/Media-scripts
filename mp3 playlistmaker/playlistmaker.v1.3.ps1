<#

playlistmaker.v1.3.ps1 - v1.3 working script

This script makes playlists (.m3u) for mp3 albums

First it scans for playlists that do not fit the naming expected naming standard
 and removes them.

Therafter it creates new playslists for all albums it finds.
Naming convention it works after:
		00 - Album Name (year).mp3

Why? Well this is how old school apps and apliances expect to get the media.

#>


# Clear the screen
Clear-Host

# Start measure time for the script
$StartTime = Get-Date

# Input directory
$rootDirectory = "x:\mp3 directory\"

# Delete non-wanted old .m3u playlists
$pattern = "00 - *.m3u"
$filesToDelete = Get-ChildItem $rootDirectory -Recurse -Include "*.m3u" | Where-Object { $_.Name -notlike $pattern }

foreach ($file in $filesToDelete) {
    Write-Host "Deleting file: $($file.FullName)"
    $file | Remove-Item -Force
}

# Make new .m3u files for each directory, unless there is already one there.

# Initialize counters for skipped and made playlists
$skippedPlaylists = 0
$madePlaylists = 0

Get-ChildItem $rootDirectory -Recurse -Include *.mp3 |
ForEach-Object {
    $parent = $_.Directory.Parent.Name
    $directory = $_.Directory.Name

    $m3uName = if ($directory -like "disc*") {
        "00 - $parent $directory.m3u"
    } else {
        "00 - $directory.m3u"
    }

    $m3uPath = Join-Path $_.Directory.FullName $m3uName

    if (-not (Test-Path $m3uPath)) {
        Write-Host "Creating $m3uPath"

        # Increment the counter for made playlists
        $madePlaylists++

        # Write the playlist header and encoding information
        @("#EXTM3U", "#EXTENC: UTF-8") | Out-File -FilePath $m3uPath -Encoding utf8

        $mp3s = Get-ChildItem $_.Directory.FullName -Filter *.mp3 | Sort-Object Name | ForEach-Object {
            $_.Name
        }

        $mp3s | Out-File -FilePath $m3uPath -Encoding utf8 -Append

        # Add the last line with script name and date to the playlist
        $date = Get-Date -Format "yyyy-MM-dd"
        $scriptName = $MyInvocation.MyCommand.Name
        "# made with $scriptName on $date" | Out-File -FilePath $m3uPath -Encoding utf8 -Append
    } else {
        Write-Host "$m3uPath already exists, skipping"

        # Increment the counter for skipped playlists
        $skippedPlaylists++
    }
}

# End of script
$EndTime = Get-Date
$TotalTime = New-TimeSpan $StartTime $EndTime

# Output the summary of skipped and made playlists
Write-Host "Summary:"
Write-Host "Skipped playlists: $skippedPlaylists"
Write-Host "Made playlists: $madePlaylists"
Write-Host "Script execution time: " + $TotalTime.ToString('hh\:mm\:ss')
