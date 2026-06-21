param(
    [double]$Width = 250,
    [double]$Depth = 250,
    [int]$MaxFaces = 50000,
    [string]$DxfPath = "..\VilleMTP_MTP_Modele3D\Centre_BATIMENTS_2016.dxf",
    [string]$OutputPath = "assets\models\dxf_tile_centre.obj"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DxfPath)) {
    throw "DXF introuvable : $DxfPath"
}

$ExtractScript = Join-Path $PSScriptRoot "dxf_extract_tile_obj.ps1"
$RunScript = Join-Path $PSScriptRoot "run_windows.ps1"

if (-not (Test-Path $ExtractScript)) {
    throw "Script extracteur introuvable : $ExtractScript"
}

if (-not (Test-Path $RunScript)) {
    throw "Script run_windows introuvable : $RunScript"
}

Write-Host "=== DXF TILE CENTRE ==="
Write-Host "DXF : $DxfPath"
Write-Host "Output : $OutputPath"
Write-Host "Width : $Width"
Write-Host "Depth : $Depth"
Write-Host "MaxFaces : $MaxFaces"

& $ExtractScript -Path $DxfPath -OutputPath $OutputPath -Width $Width -Depth $Depth -MaxFaces $MaxFaces

if ($LASTEXITCODE -ne 0) {
    throw "Extraction tuile échouée."
}

& $RunScript -ModelPath $OutputPath
