param(
    [string]$ExportDir = "data\raw\montpellier\photomodel_exports\C06"
)

$ErrorActionPreference = "Stop"

Write-Host "=== AUDIT PHOTOMODEL EXPORT ===" -ForegroundColor Cyan
Write-Host "ExportDir : $ExportDir"
Write-Host ""

if (-not (Test-Path $ExportDir)) {
    throw "Dossier export introuvable : $ExportDir"
}

function Get-SizeMb {
    param([System.IO.FileInfo]$File)

    return [Math]::Round($File.Length / 1MB, 2)
}

$files = Get-ChildItem -Path $ExportDir -Recurse -File | Sort-Object FullName

if ($files.Count -eq 0) {
    Write-Host "Aucun fichier trouvé. Dépose d'abord l'export SketchUp ici." -ForegroundColor Yellow
    exit 0
}

$inventory = $files | ForEach-Object {
    [pscustomobject]@{
        Name = $_.Name
        Extension = $_.Extension.ToLowerInvariant()
        SizeMB = Get-SizeMb $_
        FullName = $_.FullName
    }
}

$summary = $inventory |
    Group-Object Extension |
    Sort-Object Name |
    ForEach-Object {
        [pscustomobject]@{
            Extension = $_.Name
            Count = $_.Count
            SizeMB = [Math]::Round((($_.Group | Measure-Object SizeMB -Sum).Sum), 2)
        }
    }

Write-Host "=== Extensions ===" -ForegroundColor Cyan
$summary | Format-Table -AutoSize

Write-Host ""
Write-Host "=== Fichiers principaux ===" -ForegroundColor Cyan
$inventory |
    Where-Object { $_.Extension -in @(".obj", ".mtl", ".dae", ".gltf", ".glb", ".fbx") } |
    Sort-Object SizeMB -Descending |
    Format-Table -AutoSize

Write-Host ""
Write-Host "=== Textures probables ===" -ForegroundColor Cyan
$inventory |
    Where-Object { $_.Extension -in @(".jpg", ".jpeg", ".png", ".tif", ".tiff", ".webp") } |
    Sort-Object SizeMB -Descending |
    Select-Object -First 20 |
    Format-Table -AutoSize

$reportDir = "_audit_photomodel_exports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csv = Join-Path $reportDir "photomodel_export_inventory_$stamp.csv"
$inventory | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Inventaire écrit : $csv" -ForegroundColor Green
