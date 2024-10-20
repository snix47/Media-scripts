@echo off

rem  Handbrake.bat v1.2 WORKING
rem  This script uses Handbrake to bulk re-encode video files to a template (made by You in GUI version of Handbrake).
rem   You´ll need to make the list of the videofiles with another script named large-files_maker.v1.0.ps1
rem  
rem  Here were using (--preset-import-gui -Z "Fast 720 AAC 51 Forced"),
rem   Just put in whatever profile You need to use inbetween the " ".
rem 
rem I´m not sure if it´s necesarry, but I put the script in the same dir as the GUI version and it works.
rem  c:\Program Files\HandBrake\
rem 
rem This a working script with hardware enabled encoder NVENC (works with Nvidia RTX cards) and speeds up the encoding.
rem
rem The script needs to have HandBrakeCLI.exe in the same directory


cls 

setlocal enabledelayedexpansion

rem Set path to HandBrakeCLI.exe
set "HandBrakeCLIPath=%~dp0HandBrakeCLI.exe"

rem Set output directory
set "OutputDirectory=C:\where you want the converted file"

rem Read large-files.txt and process each file
for /f "tokens=* delims=" %%a in (large-files.txt) do (
    rem Extract file name and extension
    for %%b in ("%%a") do (
        set "FilePath=%%~dpb"
        set "FileName=%%~nxb"
        set "FileExtension=%%~xb"

        rem Extract directory name
        for %%c in ("%%~dpa.") do (
            set "DirectoryName=%%~nxc"
        )

        rem Set output directory for the converted file
        set "OutputFolder=%OutputDirectory%\!DirectoryName!"

        rem Create output directory if it doesn't exist
        if not exist "!OutputFolder!" mkdir "!OutputFolder!"

        rem Encode the file using HandBrakeCLI.exe with preset from GUI version of handbrake
        "%HandBrakeCLIPath%" -i "%%a" -o "!OutputFolder!\!FileName!" --preset-import-gui -Z "Fast 720 AAC 51 Forced"

    )
)

echo All files processed.
pause
