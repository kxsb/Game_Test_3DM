param(
    [string]$ModelPath = ""
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\windows_env.ps1"

Initialize-MontpellierWindowsDevEnv -Quiet | Out-Null

$Exe = Get-ChildItem -Path .\build -Recurse -Filter "montpellier.exe" | Select-Object -First 1

if (-not $Exe) {
    Write-Host "Executable introuvable. Build préalable."
    & "$PSScriptRoot\build_windows.ps1"

    if ($LASTEXITCODE -ne 0) {
        throw "Build préalable échoué."
    }

    $Exe = Get-ChildItem -Path .\build -Recurse -Filter "montpellier.exe" | Select-Object -First 1
}

if (-not $Exe) {
    throw "montpellier.exe introuvable après build."
}

if ($ModelPath) {
    & $Exe.FullName $ModelPath
}
else {
    & $Exe.FullName
}
