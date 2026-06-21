param(
    [double]$Width = 250,
    [double]$Depth = 250,
    [int]$MaxFaces = 50000,
    [string]$DxfPath = "..\VilleMTP_MTP_Modele3D\Centre_BATIMENTS_2016.dxf",
    [string]$OutputPath = "assets\models\dxf_tile_centre.obj",
    [double]$CenterX = [double]::NaN,
    [double]$CenterY = [double]::NaN
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DxfPath)) {
    throw "DXF not found: $DxfPath"
}

$ExtractScript = Join-Path $PSScriptRoot "dxf_extract_tile_obj.ps1"
$RunScript = Join-Path $PSScriptRoot "run_windows.ps1"

if (-not (Test-Path $ExtractScript)) {
    throw "Extractor script not found: $ExtractScript"
}

if (-not (Test-Path $RunScript)) {
    throw "Run script not found: $RunScript"
}

Write-Host "=== DXF TILE CENTRE ==="
Write-Host "DXF : $DxfPath"
Write-Host "Output : $OutputPath"
Write-Host "Width : $Width"
Write-Host "Depth : $Depth"
Write-Host "MaxFaces : $MaxFaces"

$extractArgs = @{
    Path = $DxfPath
    OutputPath = $OutputPath
    Width = $Width
    Depth = $Depth
    MaxFaces = $MaxFaces
}

if (-not [double]::IsNaN($CenterX)) {
    $extractArgs["CenterX"] = $CenterX
}

if (-not [double]::IsNaN($CenterY)) {
    $extractArgs["CenterY"] = $CenterY
}

& $ExtractScript @extractArgs

if (-not (Test-Path $OutputPath)) {
    throw "Tile extraction did not create expected OBJ: $OutputPath"
}

Write-Host ""
Write-Host "=== RUN GENERATED TILE ==="
& $RunScript -ModelPath $OutputPath