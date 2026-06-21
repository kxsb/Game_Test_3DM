$ErrorActionPreference = "Stop"

$DxfPath = "..\VilleMTP_MTP_Modele3D\Centre_BATIMENTS_2016.dxf"
$OutputPath = "assets\models\dxf_sample_centre.obj"

if (-not (Test-Path $DxfPath)) {
    throw "DXF introuvable : $DxfPath"
}

Write-Host "=== INSPECTION CENTRE — 10000 FACES ==="
& "$PSScriptRoot\dxf_inspect.ps1" -Path $DxfPath -MaxFaces 10000

Write-Host ""
Write-Host "=== EXTRACTION CENTRE — 5000 FACES ==="
& "$PSScriptRoot\dxf_extract_sample_obj.ps1" -Path $DxfPath -OutputPath $OutputPath -MaxFaces 5000

Write-Host ""
Write-Host "=== RUN SAMPLE CENTRE ==="
& "$PSScriptRoot\run_windows.ps1" -ModelPath $OutputPath
