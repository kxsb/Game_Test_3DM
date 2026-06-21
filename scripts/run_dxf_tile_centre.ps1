param(
    [double]$Width = 250.0,
    [double]$Depth = 250.0,
    [int]$MaxFaces = 50000,
    [string]$OutputPath = "assets/models/dxf_tile_centre.obj"
)

$ErrorActionPreference = "Stop"

$DxfPath = "..\VilleMTP_MTP_Modele3D\Centre_BATIMENTS_2016.dxf"

if (-not (Test-Path $DxfPath)) {
    throw "DXF introuvable : $DxfPath"
}

& "$PSScriptRoot\dxf_extract_tile_obj.ps1" `
    -Path $DxfPath `
    -OutputPath $OutputPath `
    -Width $Width `
    -Depth $Depth `
    -MaxFaces $MaxFaces `
    -FullFileCenter

& "$PSScriptRoot\run_windows.ps1" -ModelPath $OutputPath
