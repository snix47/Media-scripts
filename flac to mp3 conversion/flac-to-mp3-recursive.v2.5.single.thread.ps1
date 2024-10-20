
<#
flac-to-mp3-recursive.v2.5.single.thread.ps1 - v2.5 WORKING

This script converts .flac files to .mp3 files.
Give it working directories and that´s it.

Dependency:
	ffmpeg.exe

Get-ExecutionPolicy -list
Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy Bypass
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

*** Left to do
Look into GPU acceleration
The -hwaccel cuvid option enables CUDA acceleration for faster conversion on Nvidia GPUs
    $command = "$ffmpeg_path -hwaccel cuvid -i `"$($file.FullName)`" -c:a libmp3lame -q:a 0 -map_metadata 0 -id3v2_version 3 -write_id3v1 1 `"$output_file`""
#>

# Start measure time for the script
$StartTime = Get-Date

# Input directory
$input_directory = "x:\flacfiles\"

# Path to ffmpeg.exe
# $ffmpeg_path = "ffmpeg.exe"

$ffmpeg_path = Join-Path $PSScriptRoot "ffmpeg.exe"

# Get all FLAC files in the input directory and its subdirectories
$flac_files = Get-ChildItem -Path $input_directory -Recurse -Filter *.flac

# Loop through each FLAC file
foreach ($file in $flac_files) {

    # Create output file path by changing file extension to mp3 and putting it in the same directory as the input file
    $output_file = $file.FullName.Replace(".flac", ".mp3")

    # Command to run ffmpeg and convert the file, preserving all metadata
    #$command = "$ffmpeg_path -i `"$($file.FullName)`" -c:a libmp3lame -q:a 0 -map_metadata 0 `"$output_file`""

    # Command to run ffmpeg and convert the file, preserving all metadata and writing ID3v1 tags
    # $command = "$ffmpeg_path -i `"$($file.FullName)`" -c:a libmp3lame -q:a 0 -map_metadata 0 -id3v2_version 3 -write_id3v1 1 `"$output_file`""
    # 3D Cuda accelerated line below - does not improve speed, perhaps only video
    # $command = "$ffmpeg_path -hwaccel cuvid -i `"$($file.FullName)`" -c:a libmp3lame -q:a 0 -map_metadata 0 -id3v2_version 3 -write_id3v1 1 -c:v h264_nvenc `"$output_file`""
    $command = "$ffmpeg_path -i `"$($file.FullName)`" -c:a libmp3lame -q:a 0 -map_metadata 0 -id3v2_version 3 -write_id3v1 1 `"$output_file`""


    # Execute the command
    Invoke-Expression $command

    # Delete the original FLAC file
    Remove-Item $file.FullName
}

# End of script
$EndTime = Get-Date
$TotalTime = New-TimeSpan $StartTime $EndTime
"Script execution time: " + $TotalTime.ToString('hh\:mm\:ss')
