param(
    [switch]$Run,
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\windows_env.ps1"

Initialize-MontpellierWindowsDevEnv | Out-Null

Write-Host "=== CONFIGURATION CMAKE ==="
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=$Configuration

Write-Host ""
Write-Host "=== BUILD ==="
cmake --build build --config $Configuration

Write-Host ""
Write-Host "=== EXECUTABLE ==="
$Exe = Get-ChildItem -Path .\build -Recurse -Filter "montpellier.exe" | Select-Object -First 1

if (-not $Exe) {
    throw "montpellier.exe introuvable."
}

Write-Host $Exe.FullName

if ($Run) {
    Write-Host ""
    Write-Host "=== RUN ==="
    & $Exe.FullName
}
