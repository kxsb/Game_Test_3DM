param(
    [string]$GmlPath = "",

    [double]$CenterX = 770727.18,
    [double]$CenterY = 6279737.513,

    [double]$Width = 250.0,
    [double]$Depth = 250.0,

    [switch]$NoRun
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path ".").Path
$devRoot = Split-Path $projectRoot -Parent

if (-not $GmlPath) {
    $preferred = Join-Path $devRoot "MMM_MMM_Bat3D(1)\Batch5_bati_2020\Batch5_bati_2020.gml"
    $fallback = Join-Path $devRoot "MMM_MMM_Bat3D(1)\Batch4_bati_2020\Batch4_bati_2020.gml"

    if (Test-Path $preferred) {
        $GmlPath = $preferred
    }
    elseif (Test-Path $fallback) {
        $GmlPath = $fallback
    }
    else {
        throw "Aucun GML par défaut trouvé. Donne -GmlPath explicitement."
    }
}

$outputPath = "assets\models\citygml_tile_centre_w250_d250.obj"
$collisionPath = [System.IO.Path]::ChangeExtension($outputPath, ".collisions.txt")
$groundPath = [System.IO.Path]::ChangeExtension($outputPath, ".ground.txt")

Write-Host "=== CITYGML TILE CENTRE ===" -ForegroundColor Cyan
Write-Host "GML : $GmlPath"
Write-Host "OBJ : $outputPath"
Write-Host "Collisions : $collisionPath"
Write-Host "Ground : $groundPath"
Write-Host "CenterX : $CenterX"
Write-Host "CenterY : $CenterY"
Write-Host "Width : $Width"
Write-Host "Depth : $Depth"

powershell -ExecutionPolicy Bypass -File .\scripts\citygml_extract_tile_obj.ps1 `
    -Path $GmlPath `
    -OutputPath $outputPath `
    -CenterX $CenterX `
    -CenterY $CenterY `
    -Width $Width `
    -Depth $Depth `
    -GroundCellSize 6.0

powershell -ExecutionPolicy Bypass -File .\scripts\generate_collision_sidecar_from_obj.ps1 `
    -Path $outputPath `
    -OutputPath $collisionPath `
    -MinWallHeight 1.8 `
    -BaseVertexTolerance 0.45 `
    -SegmentThickness 0.35 `
    -MaxBoxes 8000

if (-not $NoRun) {
    .\build\montpellier.exe $outputPath
}
else {
    Write-Host "NoRun enabled. Generated CityGML assets are ready."
}
