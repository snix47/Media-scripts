
<#
	v 2.6.1 	M4A to MP3 converter
	--------------------------------
	
	The script bulk converts those pesky .m4a files to mp3 files.

    	Dependencies:
    	ffmpeg.exe   (full build 2025-10-30 or later) https://www.gyan.dev/ffmpeg/builds/

	Required variables to set:
    	$input_directory - Directory to scan for MP4 files

#>

# Start measure time for the script
$StartTime = Get-Date

# Input directory
$input_directory = "c:\temp\mp4-files\"

# Path to ffmpeg.exe
$ffmpeg_path = Join-Path $PSScriptRoot "ffmpeg.exe"

# Get all MP4 files in the input directory and its subdirectories
$flac_files = Get-ChildItem -Path $input_directory -Recurse -Filter *.mp4

# Loop through each FLAC file
foreach ($file in $flac_files) {

    # Create output file path by changing file extension to mp3 and putting it in the same directory as the input file
    $output_file = $file.FullName.Replace(".mp4", ".mp3")

    # Command to run ffmpeg and convert the file, preserving all metadata
    #$command = "$ffmpeg_path -i `"$($file.FullName)`" -c:a libmp3lame -q:a 0 -map_metadata 0 `"$output_file`""

    # Command to run ffmpeg and convert the file, preserving all metadata and writing ID3v1 tags
    # $command = "$ffmpeg_path -i `"$($file.FullName)`" -c:a libmp3lame -q:a 0 -map_metadata 0 -id3v2_version 3 -write_id3v1 1 `"$output_file`""
    # 3D Cuda accelerated line below - does not improve speed, perhaps only video
    # $command = "$ffmpeg_path -hwaccel cuvid -i `"$($file.FullName)`" -c:a libmp3lame -q:a 0 -map_metadata 0 -id3v2_version 3 -write_id3v1 1 -c:v h264_nvenc `"$output_file`""
    $command = "$ffmpeg_path -i `"$($file.FullName)`" -c:a libmp3lame -q:a 0 -map_metadata 0 -id3v2_version 3 -write_id3v1 1 `"$output_file`""


    # Execute the command
    Invoke-Expression $command

    # Delete the original MP4 file
    Remove-Item $file.FullName
}

# End of script
$EndTime = Get-Date
$TotalTime = New-TimeSpan $StartTime $EndTime

"Script execution time: " + $TotalTime.ToString('hh\:mm\:ss')
