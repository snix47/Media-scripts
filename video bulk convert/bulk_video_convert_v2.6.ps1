<#
    v 2.6
    Bulk video file converter script
    --------------------------------
    Converts .avi, .mkv and .mp4 files that exceed a target resolution
    (480p, 720p, 1080p or 2160p) into target resolution using ffmpeg.exe
    accelerated by Nvidia CUDA.

    If cuda conversion is not possible it falls back to CPU conversion. 	

    480p  = 720 x 480p     max 1000 kbps   (SD)
    720p  = 1280 x 720p    max 2000 kbps   (HD)
    1080p = 1920 x 1080p   max 4000 kbps   (HD)
    2160p = 3840 x 2160p   max 8000 kbps   (Ultra HD)

    Dependencies:
    ffmpeg.exe   (full build 2025-10-30 or later) https://www.gyan.dev/ffmpeg/builds/
    ffprobe.exe  (full build 2025-10-30 or later) https://www.gyan.dev/ffmpeg/builds/
    NVIDIA GeForce GPU RTX with driver 581.80 or later

    Required variables:
    $ffmpeg_path  - Full path to ffmpeg.exe
    $ffprobe_path - Full path to ffprobe.exe
    $input_dir    - Directory to scan
    $resolution   - One of: 480, 720, 1080, 2160
    $audioquality - aac128, org
#>

Clear Screen

# --------------------------
# User variables
# --------------------------
$ffmpeg_path   = "c:\temp\ffmpeg.exe"
$ffprobe_path  = "c:\temp\ffprobe.exe"
$input_dir     = "c:\temp\videofiles\"
$resolution    = 720
$audioquality  = "aac128"  # "aac128" or "org"
$scriptver = "2.6"

# --------------------------
# Global error log setup
# --------------------------
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$dateStr = Get-Date -Format "yy-MM-dd_HH-mm"
$errorLogPath = Join-Path $scriptDir "error_$dateStr.txt"
$summaryLogPath = Join-Path $scriptDir "error_${dateStr}_summary.txt"

# Redirect all errors to transcript file
Start-Transcript -Path $errorLogPath -Append

# --------------------------
# Internal preset globals
# --------------------------
$presets = @{
    480  = @{ w = 720;  h = 480;  capKbps = 1000 }
    720  = @{ w = 1280; h = 720;  capKbps = 2000 }
    1080 = @{ w = 1920; h = 1080; capKbps = 4000 }
    2160 = @{ w = 3840; h = 2160; capKbps = 8000 }
}

if (-not $presets.ContainsKey($resolution)) {
    Write-Host "ERROR: \$resolution must be one of: 480, 720, 1080, 2160" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

$targetW = $presets[$resolution].w
$targetH = $presets[$resolution].h
$capKbps = $presets[$resolution].capKbps

if ($audioquality -eq "aac128") {
    $audioArgs = @("-c:a","aac","-b:a","128k")
} else {
    $audioArgs = @("-c:a","copy")
}

$lockedLines = 10

# --------------------------
# Helper: Show locked 10-line header
# --------------------------
function Show-LockedHeader {
    param(
        [string]$current,
        [string[]]$nextList,
        [int]$remainingCount
    )
    $lines = @()
    $lines += "-----------------------------------------"
    $lines += "Remaining files to convert ($remainingCount):"
    for ($k=0; $k -lt 8; $k++) {
        if ($k -lt $nextList.Length) { $lines += $nextList[$k] } else { $lines += "" }
    }
    $lines += ""
    $lines += "Currently converting:"
    $lines += $current
    $lines += "-----------------------------------------"

    for ($row = 0; $row -lt $lockedLines; $row++) {
        try {
            [Console]::SetCursorPosition(0, $row)
            $w = [Console]::WindowWidth
            $text = $lines[$row]; if ($null -eq $text) { $text = "" }
            if ($text.Length -gt $w) { $text = $text.Substring(0,$w) }
            [Console]::Write($text.PadRight($w))
        } catch { Write-Host $lines[$row] }
    }
    try { [Console]::SetCursorPosition(0,$lockedLines) } catch {}
}

# --------------------------
# Helper: Probe resolution
# --------------------------
function Probe-Resolution { param([string]$path)
    try {
        $out = & $ffprobe_path -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x $path 2>$null
        if (-not $out) { return $null }
        $parts = $out.Trim() -split "x"
        if ($parts.Count -ne 2) { return $null }
        return @{ Width=[int]$parts[0]; Height=[int]$parts[1] }
    } catch { return $null }
}

# --------------------------
# Helper: Probe bitrate
# --------------------------
function Probe-Bitrate { param([string]$path)
    try {
        $out = & $ffprobe_path -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 $path 2>$null
        if (-not $out) { return $null }
        return [int64]::Parse($out.Trim())
    } catch { return $null }
}

# --------------------------
# Helper: Probe codec
# --------------------------
function Probe-Codec { param([string]$path)
    try { return (& $ffprobe_path -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $path 2>$null).Trim() }
    catch { return $null }
}

# --------------------------
# Start scanning
# --------------------------
Clear-Host
Write-Host "Bulk Video Converter v$scriptver" -ForegroundColor Cyan
Write-Host "Input dir: $input_dir" -ForegroundColor Cyan
Write-Host "Target preset: ${resolution}p -> ${targetW}x${targetH} (cap ${capKbps} kbps)" -ForegroundColor Cyan
Write-Host "Audio mode: $audioquality" -ForegroundColor Cyan
Write-Host "-----------------------------------------"

$extensions = "*.mp4","*.mkv","*.avi"
$files = Get-ChildItem -Path $input_dir -Recurse -Include $extensions -File |
         Where-Object { $_.Name -notmatch '^TEMP_' } | Sort-Object FullName

if ($files.Count -eq 0) { Write-Host "No media files found in $input_dir" -ForegroundColor Yellow; Stop-Transcript; exit 0 }

# --------------------------
# Conversion loop
# --------------------------
foreach ($fileObj in $files) {
    $file = $fileObj.FullName
    $ncvMarker = [System.IO.Path]::ChangeExtension($file, ".ncv")
    $ncvSuccessMarker = [System.IO.Path]::ChangeExtension($file, ".ncv-success")

    # Skip if already marked
    if ((Test-Path $ncvMarker) -or (Test-Path $ncvSuccessMarker)) {
        Write-Host "`nℹ️  $([System.IO.Path]::GetFileName($file)) already has a marker, skipping." -ForegroundColor Gray
        continue
    }

    $res = Probe-Resolution -path $file
    if (-not $res) { 
        Write-Host "`n❌ Could not read resolution for $file — skipping..." -ForegroundColor Yellow
        Add-Content -Path $summaryLogPath -Value ("{0}  NCV-FAILED-PROBE  {1}" -f (Get-Date), $file)
        continue 
    }

    if ($res.Height -le $targetH) { 
        Write-Host "`nℹ️  $([System.IO.Path]::GetFileName($file)) is $($res.Width)x$($res.Height) — <= ${targetH}px, skipping."
        Add-Content -Path $summaryLogPath -Value ("{0}  NCV-SKIPPED-UNDERRES  {1}" -f (Get-Date), $file)
        # Create .ncv marker
        "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - Under target resolution" | Set-Content -Path $ncvMarker
        continue 
    }

    $origBitrate = Probe-Bitrate -path $file
    if (-not $origBitrate -or $origBitrate -le 0) { $origBitrate=2500000; Write-Host "`n⚠️ Using fallback bitrate 2.5 Mbps" }

    $capBps = [int64]($capKbps*1000)
    $targetBitrate = [Math]::Min($origBitrate,$capBps)
    if ($targetBitrate -lt 300000) { $targetBitrate=300000 }
    $bufsize = $targetBitrate*2

    Write-Host "`nProcessing file: $([System.IO.Path]::GetFileName($file))"
    Write-Host "Original resolution: $($res.Width)x$($res.Height), original bitrate: $([math]::Round($origBitrate/1000,1)) kbps"
    Write-Host "Target pixel dims: ${targetW}x${targetH}, target bitrate cap: $([math]::Round($targetBitrate/1000,1)) kbps"

    $codec = Probe-Codec -path $file
    $codecLower = if ($codec) { $codec.ToLower() } else { "" }
    $nvencAllowedCodecs = @("h264","hevc","mpeg4","vp9","vp8")
    $useNVENC = $false; foreach ($c in $nvencAllowedCodecs) { if ($codecLower -like "*$c*") { $useNVENC=$true } }

    $scalePadFilter = "scale='min(iw\,${targetW})':'min(ih\,${targetH})':force_original_aspect_ratio=decrease,pad=${targetW}:${targetH}:(ow-iw)/2:(oh-ih)/2"
    $tempPath = Join-Path (Split-Path $file -Parent) ("TEMP_" + [System.IO.Path]::GetFileName($file))
    if (Test-Path $tempPath) { Remove-Item -Force $tempPath -ErrorAction SilentlyContinue }

    $nvencArgs = @(
        "-y","-hwaccel","cuda","-hwaccel_output_format","cuda","-i",$file,
        "-vf",$scalePadFilter,"-c:v","h264_nvenc","-preset","p7","-rc","vbr","-tune","hq",
        "-b:v",$targetBitrate.ToString(),"-maxrate",$targetBitrate.ToString(),"-bufsize",$bufsize.ToString()
    ) + $audioArgs + @($tempPath)

    $cpuArgs = @(
        "-y","-i",$file,"-vf",$scalePadFilter,"-c:v","libx264","-preset","fast",
        "-b:v",$targetBitrate.ToString(),"-maxrate",$targetBitrate.ToString(),"-bufsize",$bufsize.ToString()
    ) + $audioArgs + @($tempPath)

    $converted = $false

    if ($useNVENC) {
        Write-Host "`n⏱ Attempting NVENC (h264_nvenc) ..."
        try { & $ffmpeg_path @nvencArgs 2>&1 | ForEach-Object { if ($_ -notmatch '^\s*frame=') { Write-Host $_ } } } catch { Write-Host "⚠️ NVENC run failed." }
        if (Test-Path $tempPath) { 
            $sizeTemp=(Get-Item $tempPath).Length; $sizeOrig=(Get-Item $file).Length
            if ($sizeTemp -gt 0 -and $sizeTemp -le $sizeOrig) { 
                Move-Item -Force $tempPath $file; Write-Host "✅ NVENC conversion accepted."; $converted=$true
                # Create success marker
                "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - Conversion successful" | Set-Content -Path $ncvSuccessMarker
            }
            elseif ($sizeTemp -gt $sizeOrig) { Remove-Item -Force $tempPath -ErrorAction SilentlyContinue; 
                Write-Host "⚠️ NVENC output larger, will retry CPU."
            }
            else { Write-Host "❌ NVENC produced no valid output, CPU fallback." }
        } else { Write-Host "❌ NVENC did not produce output, CPU fallback." }
    } else { Write-Host "`nℹ️ NVENC not used for codec: $codec (CPU fallback will be used)." }

    if (-not $converted) {
        Write-Host "`n⏱ Starting CPU fallback (libx264) ..."
        try { & $ffmpeg_path @cpuArgs 2>&1 | ForEach-Object { if ($_ -notmatch '^\s*frame=') { Write-Host $_ } } } catch { Write-Host "⚠️ CPU ffmpeg run threw an exception." }
        if (Test-Path $tempPath) { 
            $sizeTemp=(Get-Item $tempPath).Length; $sizeOrig=(Get-Item $file).Length
            if ($sizeTemp -gt 0 -and $sizeTemp -le $sizeOrig) { 
                Move-Item -Force $tempPath $file; Write-Host "✅ CPU conversion accepted."; $converted=$true
                # Create success marker
                "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - Conversion successful" | Set-Content -Path $ncvSuccessMarker
            }
            elseif ($sizeTemp -gt $sizeOrig) { Remove-Item -Force $tempPath -ErrorAction SilentlyContinue; 
                Write-Host "⚠️ CPU output larger, skipping."
                "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - CPU output larger than original" | Set-Content -Path $ncvMarker
                Add-Content -Path $summaryLogPath -Value ("{0}  CPU-LARGER-SKIPPED  {1}" -f (Get-Date), $file)
            }
            else { Write-Host "❌ CPU produced no valid output, skipping."
                "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - CPU failed to produce valid output" | Set-Content -Path $ncvMarker
                Add-Content -Path $summaryLogPath -Value ("{0}  CPU-FAILED  {1}" -f (Get-Date), $file)
            }
        } else { 
            Write-Host "❌ CPU did not produce output, skipping."
            "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - CPU did not produce output" | Set-Content -Path $ncvMarker
            Add-Content -Path $summaryLogPath -Value ("{0}  CPU-NOOUTPUT  {1}" -f (Get-Date), $file)
        }
    }

    Start-Sleep -Milliseconds 200
}

Write-Host "`n🎉 All done! v$scriptver" -ForegroundColor Green
Stop-Transcript

