# When Plex Player HTPC Hangs/Freze, run this script to restart it from your 
#  (HAMA) IR Universal Mediaplayer remote (or any other PC IR Remote).
#
# From the remote there is a button that runs the windows default browser EDGE
#  This is the button we use to run this PS script by cathing the event.
# 
# You then enable process creation auditing en local group policy (success and failure) 
#
# From the task scheduler you run this script "On an event":
#   Log: Security.
#   Source: Microsoft-Windows-Security-Auditing.
#   Event ID: 4688
#
# This then runs the script which kills all plex instances and all edge instances and starts 
#  plex htpx again
#
# powershell -ExecutionPolicy Bypass -File "C:\Users\snix\Desktop\plexrestart.ps1"
# Set-ExecutionPolicy Unrestricted -Scope CurrentUser

#1 Terminate all running instances of Plex

# Get the process object(s) for Plex HTPC.exe
$process = Get-Process -Name "Plex HTPC" -ErrorAction SilentlyContinue

# Check if the process was found
if ($process) {
    # Kill the process
    $process | Stop-Process -Force
    Write-Host "Plex HTPC.exe process has been terminated."
} else {
    Write-Host "Plex HTPC.exe process not found."
}


#2 Terminate all running instances of Microsoft Edge

# Get all processes with the name 'msedge' (Microsoft Edge)
$edgeProcesses = Get-Process -Name "msedge" -ErrorAction SilentlyContinue

# Check if any Edge processes were found
if ($edgeProcesses) {
    # Terminate all found Edge processes
    foreach ($process in $edgeProcesses) {
        try {
            Stop-Process -Id $process.Id -Force
            Write-Host "Terminated Edge process with ID: $($process.Id)"
        } catch {
            Write-Host "Failed to terminate Edge process with ID: $($process.Id). Error: $($_.Exception.Message)"
        }
    }
} else {
    Write-Host "No running instances of Edge were found."
}


#3 Start Plex HTPC
$plexPath = "C:\Program Files\Plex\Plex HTPC\Plex HTPC.exe"

try {
    Start-Process -FilePath $plexPath
    Write-Host "Plex HTPC started successfully."
} catch {
    Write-Host "Failed to start Plex HTPC. Error: $($_.Exception.Message)"
}
