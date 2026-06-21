param(
    [string]$CityModel = "assets\models\citygml_tile_centre_w250_d250.obj",
    [string]$PhotoModel = "data\raw\montpellier\photomodel_exports\C06_citymask\C06_citymask.obj"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CityModel)) {
    throw "Modèle CityGML introuvable : $CityModel"
}

if (-not (Test-Path $PhotoModel)) {
    Write-Host "Photomodèle citymask absent, génération..." -ForegroundColor Yellow
    powershell -ExecutionPolicy Bypass -File .\scripts\generate_photomodel_citymask.ps1
}

if (-not (Test-Path $PhotoModel)) {
    throw "Photomodèle citymask toujours introuvable : $PhotoModel"
}

Write-Host "=== RUN PHOTOMODEL OVERLAY C06 CITYMASK ===" -ForegroundColor Cyan
Write-Host "CityGML : $CityModel"
Write-Host "Photo   : $PhotoModel"
Write-Host ""
Write-Host "Touches : P photo | X CityGML | V wireframe | N bounds | M log offset"

.\build\montpellier.exe $CityModel $PhotoModel
