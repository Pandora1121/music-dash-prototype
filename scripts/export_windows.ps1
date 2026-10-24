[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [string]$OutputDirectory = '',
    [switch]$SkipSmokeTest
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$presetPath = Join-Path $projectRoot 'export_presets.cfg'

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command 'Godot_v4.7.2-stable_win64_console.exe' -ErrorAction SilentlyContinue
    if (-not $godotCommand) {
        throw 'Godot console executable not found. Pass -GodotPath with the Godot 4.7.2 stable console executable.'
    }
    $GodotPath = $godotCommand.Source
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable was not found: $GodotPath"
}

$versionOutput = (& $GodotPath --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch '^4\.7\.2\.stable(?:\.|$)') {
    throw "Windows release export requires Godot 4.7.2 stable; found '$versionOutput'."
}
if (-not (Test-Path -LiteralPath $presetPath -PathType Leaf)) {
    throw "Windows export preset is missing: $presetPath"
}
$presetText = Get-Content -Raw -LiteralPath $presetPath
if ($presetText -notmatch '(?s)\[preset\.0\].*?name="Windows Desktop".*?platform="Windows Desktop"' -or
    $presetText -notmatch '(?s)\[preset\.0\.options\].*?binary_format/embed_pck=true') {
    throw 'export_presets.cfg must define the Windows Desktop preset with an embedded PCK.'
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot 'builds/windows'
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$null = New-Item -ItemType Directory -Path $OutputDirectory -Force
$executablePath = Join-Path $OutputDirectory 'MusicDash.exe'
$archivePath = Join-Path $OutputDirectory 'MusicDash-Windows-x64.zip'

$exportOutput = & $GodotPath --headless --path $projectRoot --export-release 'Windows Desktop' $executablePath 2>&1
$exportExitCode = $LASTEXITCODE
if ($exportExitCode -ne 0) {
    $details = ($exportOutput | Out-String).Trim()
    if ($details -match 'No export template found') {
        throw "Godot Windows export failed (exit $exportExitCode). Install the matching 4.7.2 stable export templates in Editor > Manage Export Templates, then retry.`n$details"
    }
    throw "Godot Windows export failed (exit $exportExitCode).`n$details"
}
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf) -or (Get-Item -LiteralPath $executablePath).Length -eq 0) {
    throw "Godot export reported success but the executable is missing or empty: $executablePath"
}

if (-not $SkipSmokeTest) {
    $smokeDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('music-dash-smoke-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $smokeDirectory
    $stdoutPath = Join-Path $smokeDirectory 'stdout.txt'
    $stderrPath = Join-Path $smokeDirectory 'stderr.txt'
    try {
        $smokeProcess = Start-Process -FilePath $executablePath -ArgumentList @('--headless', '--quit-after', '120') -WorkingDirectory $OutputDirectory -PassThru -Wait -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $smokeText = (@(Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue) + @(Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue)) -join "`n"
        if ($smokeProcess.ExitCode -ne 0 -or $smokeText -match 'ERROR:|SCRIPT ERROR:') {
            throw "Exported Windows build failed its headless startup check (exit $($smokeProcess.ExitCode)).`n$smokeText"
        }
    }
    finally {
        Remove-Item -LiteralPath $smokeDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
Compress-Archive -LiteralPath $executablePath -DestinationPath $archivePath -CompressionLevel Optimal
if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf) -or (Get-Item -LiteralPath $archivePath).Length -eq 0) {
    throw "ZIP packaging failed: $archivePath"
}

Write-Output "Windows executable: $executablePath"
Write-Output "Portable archive: $archivePath"
