$ErrorActionPreference = "Stop"

. "$PSScriptRoot\windows_env.ps1"

Initialize-MontpellierWindowsDevEnv -Quiet | Out-Null

$ModelPath = "assets/models/test_city.obj"

& "$PSScriptRoot\generate_test_city_obj.ps1" -OutputPath $ModelPath
& "$PSScriptRoot\build_windows.ps1"

if ($LASTEXITCODE -ne 0) {
    throw "Build échoué."
}

& "$PSScriptRoot\run_windows.ps1" -ModelPath $ModelPath
