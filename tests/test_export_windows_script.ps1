$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $projectRoot 'scripts/export_windows.ps1'
$presetPath = Join-Path $projectRoot 'export_presets.cfg'

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw 'Windows export script is missing.'
}
if (-not (Test-Path -LiteralPath $presetPath)) {
    throw 'Windows export preset is missing.'
}

$preset = Get-Content -Raw -LiteralPath $presetPath
if ($preset -notmatch 'name="Windows Desktop"' -or $preset -notmatch 'binary_format/embed_pck=true') {
    throw 'Windows preset must use the Windows Desktop platform and embed the PCK.'
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('music-dash-export-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tempRoot
try {
    $fakeGodot = Join-Path $tempRoot 'fake-godot.cmd'
    $fakeGodotBody = @'
@echo off
if /I "%~1"=="--version" (
  echo 4.7.2.stable.official.77dcf97d8
  exit /b 0
)
set "last="
for %%a in (%*) do set "last=%%~a"
> "%last%" echo fake-windows-binary
exit /b 0
'@
    Set-Content -LiteralPath $fakeGodot -Value $fakeGodotBody -Encoding Ascii
    $outputDirectory = Join-Path $tempRoot 'package'

    & $scriptPath -GodotPath $fakeGodot -OutputDirectory $outputDirectory -SkipSmokeTest | Out-Null

    $executable = Join-Path $outputDirectory 'MusicDash.exe'
    $archive = Join-Path $outputDirectory 'MusicDash-Windows-x64.zip'
    if (-not (Test-Path -LiteralPath $executable) -or (Get-Item -LiteralPath $executable).Length -eq 0) {
        throw 'Export script did not produce a non-empty executable.'
    }
    if (-not (Test-Path -LiteralPath $archive)) {
        throw 'Export script did not create a Windows ZIP.'
    }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    try {
        if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].Name -ne 'MusicDash.exe') {
            throw 'Windows ZIP must contain exactly MusicDash.exe.'
        }
    }
    finally {
        $zip.Dispose()
    }

    $wrongVersion = Join-Path $tempRoot 'wrong-version.cmd'
    Set-Content -LiteralPath $wrongVersion -Value @('@echo off', 'echo 4.6.0.stable.official.fake') -Encoding Ascii
    $rejected = $false
    try {
        & $scriptPath -GodotPath $wrongVersion -OutputDirectory (Join-Path $tempRoot 'wrong-version-output') | Out-Null
    }
    catch {
        $rejected = $_.Exception.Message -match 'requires Godot 4\.7\.2'
    }
    if (-not $rejected) {
        throw 'Export script must reject Godot versions other than 4.7.2 stable.'
    }

    $failedExportGodot = Join-Path $tempRoot 'failed-export.cmd'
    Set-Content -LiteralPath $failedExportGodot -Value @(
        '@echo off',
        'if /I "%~1"=="--version" (',
        '  echo 4.7.2.stable.official.77dcf97d8',
        '  exit /b 0',
        ')',
        'echo SIMULATED_EXPORT_FAILURE',
        'exit /b 1'
    ) -Encoding Ascii
    $exportFailureReported = $false
    try {
        & $scriptPath -GodotPath $failedExportGodot -OutputDirectory (Join-Path $tempRoot 'failed-export-output') | Out-Null
    }
    catch {
        $exportFailureReported = $_.Exception.Message -match 'SIMULATED_EXPORT_FAILURE' -and
            $_.Exception.Message -notmatch 'Install the matching'
    }
    if (-not $exportFailureReported) {
        throw 'Export failures must preserve Godot diagnostics without mislabeling them as missing templates.'
    }
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

Write-Output 'PASS: Windows export script contract'
