param(
    [string]$CityModel = "assets\models\citygml_tile_centre_w250_d250.obj",
    [string]$PhotoModel = "data\raw\montpellier\photomodel_exports\C06\C06.obj"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CityModel)) {
    throw "Modèle CityGML introuvable : $CityModel"
}

if (-not (Test-Path $PhotoModel)) {
    throw "Photomodèle introuvable : $PhotoModel"
}

Write-Host "=== RUN PHOTOMODEL OVERLAY C06 ===" -ForegroundColor Cyan
Write-Host "CityGML : $CityModel"
Write-Host "Photo   : $PhotoModel"
Write-Host ""
Write-Host "Touches : P photo | X CityGML | I/J/K/L/U/O align | +/- scale"

.\build\montpellier.exe $CityModel $PhotoModel
