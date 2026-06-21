param(
    [switch]$Run,
    [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

function Invoke-NativeCommand {
    param(
        [scriptblock]$Command,
        [string]$Label
    )

    Write-Host $Label
    & $Command

    if ($LASTEXITCODE -ne 0) {
        throw "$Label a échoué avec le code $LASTEXITCODE."
    }
}

. "$PSScriptRoot\windows_env.ps1"

Initialize-MontpellierWindowsDevEnv | Out-Null

Write-Host "=== CONFIGURATION CMAKE ==="
Invoke-NativeCommand {
    cmake -S . -B build -G "Ninja" "-DCMAKE_BUILD_TYPE=$Configuration"
} "cmake configure"

Write-Host ""
Write-Host "=== BUILD ==="
Invoke-NativeCommand {
    cmake --build build --config $Configuration
} "cmake build"

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
