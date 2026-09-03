<#
.SYNOPSIS
    Builds the streaming demo animation from source.

.DESCRIPTION
    Compiles tools\DemoRecorder and renders everything the README shows plus the
    GitHub social preview card: the two screenshots (docs\images\studio-light.png
    and studio-dark.png), docs\images\social-preview.png, and the frames that
    ffmpeg folds into a GIF and an MP4. Nothing is screen-captured, so the result
    is identical on every machine and can be rebuilt after a theme or layout
    change.

    The social preview card itself still has to be uploaded by hand: GitHub has
    no API for it, only Settings > General > Social preview in the browser.

    Needs a Delphi install (13 or 12) and ffmpeg on the PATH.

.PARAMETER FramesFolder
    Scratch folder for the PNG frames. Emptied on every run.

.PARAMETER GifPath
    Where the README animation lands.

.PARAMETER Mp4Path
    Where the social video lands. Skipped when empty.
#>
[CmdletBinding()]
param(
    [string]$FramesFolder = (Join-Path $env:TEMP 'Markdown4D-demo-frames'),
    [string]$GifPath = (Join-Path $PSScriptRoot '..\docs\images\streaming-demo.gif'),
    [string]$Mp4Path = (Join-Path $PSScriptRoot '..\docs\media\streaming-demo.mp4'),
    [int]$SourceFrameRate = 15,
    [int]$GifFrameRate = 12,
    [int]$GifWidth = 840,
    [string]$StudioRoot = 'C:\Program Files (x86)\Embarcadero\Studio'
)

$ErrorActionPreference = 'Stop'

function Resolve-Rsvars {
    param([string]$Root)

    # Newest supported Delphi first: 37.0 is Delphi 13, 23.0 is Delphi 12 Athens.
    foreach ($version in @('37.0', '23.0')) {
        $candidate = Join-Path $Root "$version\bin\rsvars.bat"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "No supported Delphi found under '$Root'. Looked for 37.0 and 23.0."
}

function Assert-Ffmpeg {
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($null -eq $ffmpeg) {
        throw 'ffmpeg was not found on the PATH. Install it with: winget install Gyan.FFmpeg'
    }

    return $ffmpeg.Source
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$projectFolder = Join-Path $repoRoot 'tools\DemoRecorder'
$project = Join-Path $projectFolder 'Markdown4D.DemoRecorder.dpr'
$buildFolder = Join-Path $FramesFolder 'build'
$exePath = Join-Path $buildFolder 'Markdown4D.DemoRecorder.exe'

$rsvars = Resolve-Rsvars -Root $StudioRoot
$ffmpegPath = Assert-Ffmpeg

Write-Host "[demo] Delphi:  $rsvars"
Write-Host "[demo] ffmpeg:  $ffmpegPath"

if (Test-Path $FramesFolder) {
    Remove-Item $FramesFolder -Recurse -Force
}
New-Item -ItemType Directory -Path $FramesFolder -Force | Out-Null
New-Item -ItemType Directory -Path $buildFolder -Force | Out-Null

$searchPath = @(
    (Join-Path $repoRoot 'Source\Core'),
    (Join-Path $repoRoot 'Source\Layout'),
    (Join-Path $repoRoot 'Source\Vcl')
) -join ';'

Write-Host '[demo] Compiling the recorder'

$compile = "call `"$rsvars`" && dcc32 -B -Q -U`"$searchPath`" -NU`"$buildFolder`" -E`"$buildFolder`" `"$project`""
$compileOutput = cmd.exe /c $compile
if ($LASTEXITCODE -ne 0) {
    $compileOutput | Write-Host
    throw "Compilation failed with exit code $LASTEXITCODE."
}

Write-Host '[demo] Rendering the screenshots'

$imagesFolder = Join-Path $repoRoot 'docs\images'
if (-not (Test-Path $imagesFolder)) {
    New-Item -ItemType Directory -Path $imagesFolder -Force | Out-Null
}

& $exePath $imagesFolder stills
if ($LASTEXITCODE -ne 0) {
    throw "The recorder failed while writing the stills, exit code $LASTEXITCODE."
}

Write-Host '[demo] Rendering the social preview card'

& $exePath $imagesFolder social
if ($LASTEXITCODE -ne 0) {
    throw "The recorder failed while writing the social card, exit code $LASTEXITCODE."
}

Write-Host '[demo] Rendering frames'

& $exePath $FramesFolder
if ($LASTEXITCODE -ne 0) {
    throw "The recorder failed with exit code $LASTEXITCODE."
}

$frameCount = (Get-ChildItem -Path $FramesFolder -Filter 'frame_*.png').Count
if ($frameCount -eq 0) {
    throw 'The recorder produced no frames.'
}

$framePattern = Join-Path $FramesFolder 'frame_%04d.png'

foreach ($target in @($GifPath, $Mp4Path)) {
    if (-not [string]::IsNullOrWhiteSpace($target)) {
        $folder = Split-Path -Parent $target
        if (-not (Test-Path $folder)) {
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        }
    }
}

Write-Host "[demo] Encoding the GIF ($GifWidth px, $GifFrameRate fps)"

# Two passes: one to work out a palette that suits these frames, one to map the
# frames onto it. A single pass would quantise to the default 256 web colours and
# band every gradient in the charts.
$palettePath = Join-Path $FramesFolder 'palette.png'
$paletteFilter = "fps=$GifFrameRate,scale=$($GifWidth):-1:flags=lanczos,palettegen=stats_mode=diff"
$gifFilter = "fps=$GifFrameRate,scale=$($GifWidth):-1:flags=lanczos[frames];[frames][1:v]paletteuse=dither=bayer:bayer_scale=3"

& ffmpeg -y -loglevel error -framerate $SourceFrameRate -i $framePattern -vf $paletteFilter $palettePath
if ($LASTEXITCODE -ne 0) { throw 'ffmpeg failed while building the palette.' }

& ffmpeg -y -loglevel error -framerate $SourceFrameRate -i $framePattern -i $palettePath -lavfi $gifFilter -loop 0 $GifPath
if ($LASTEXITCODE -ne 0) { throw 'ffmpeg failed while encoding the GIF.' }

if (-not [string]::IsNullOrWhiteSpace($Mp4Path)) {
    Write-Host '[demo] Encoding the MP4'

    # yuv420p and even dimensions, because that is what LinkedIn and every other
    # player expect. -r 30 duplicates frames up from the source rate.
    & ffmpeg -y -loglevel error -framerate $SourceFrameRate -i $framePattern `
        -vf 'scale=1280:-2:flags=lanczos,format=yuv420p' -r 30 -c:v libx264 -preset slow -crf 18 -movflags +faststart $Mp4Path
    if ($LASTEXITCODE -ne 0) { throw 'ffmpeg failed while encoding the MP4.' }
}

Write-Host ''
Write-Host "[demo] $frameCount frames rendered"

$gifSize = [math]::Round((Get-Item $GifPath).Length / 1MB, 2)
Write-Host "[demo] GIF: $GifPath ($gifSize MB)"

if (-not [string]::IsNullOrWhiteSpace($Mp4Path)) {
    $mp4Size = [math]::Round((Get-Item $Mp4Path).Length / 1MB, 2)
    Write-Host "[demo] MP4: $Mp4Path ($mp4Size MB)"
}
