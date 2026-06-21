param(
    [double]$Width = 250,
    [double]$Depth = 250,
    [int]$MaxFaces = 50000,
    [string]$CenterX = "",
    [string]$CenterY = ""
)

$ErrorActionPreference = "Stop"

$DxfPath = "..\VilleMTP_MTP_Modele3D\Centre_BATIMENTS_2016.dxf"
$OutputPath = "assets\models\dxf_tile_centre_${Width}x${Depth}.obj"

if (-not (Test-Path $DxfPath)) {
    throw "DXF introuvable : $DxfPath"
}

$Args = @(
    "-Path", $DxfPath,
    "-OutputPath", $OutputPath,
    "-Width", $Width,
    "-Depth", $Depth,
    "-MaxFaces", $MaxFaces
)

if ($CenterX -ne "") {
    $Args += @("-CenterX", $CenterX)
}

if ($CenterY -ne "") {
    $Args += @("-CenterY", $CenterY)
}

& "$PSScriptRoot\dxf_extract_tile_obj.ps1" @Args

if (-not (Test-Path $OutputPath)) {
    throw "OBJ non genere : $OutputPath"
}

$SystemRoot = $env:SystemRoot
if (-not $SystemRoot) { $SystemRoot = "C:\Windows" }
$PowerShellExe = Join-Path $SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

& $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\run_windows.ps1" -ModelPath $OutputPath
