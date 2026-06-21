param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
    throw "OBJ not found: $Path"
}

$resolvedObj = (Resolve-Path $Path).Path
$objDir = Split-Path $resolvedObj
$objName = Split-Path $resolvedObj -Leaf
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($objName)
$mtlName = "$baseName.mtl"
$mtlPath = Join-Path $objDir $mtlName

$originalLines = Get-Content $resolvedObj
$newLines = New-Object System.Collections.Generic.List[string]

$hasMtllib = $false
foreach ($line in $originalLines) {
    if ($line -match '^mtllib\s+') {
        $hasMtllib = $true
        break
    }
}

if (-not $hasMtllib) {
    $newLines.Add("mtllib $mtlName")
}

$faceIndex = 0
$buildingMaterialInserted = $false
$groundMaterialInserted = $false

foreach ($line in $originalLines) {
    if ($line -match '^mtllib\s+') {
        $newLines.Add("mtllib $mtlName")
        continue
    }

    if ($line -match '^usemtl\s+') {
        continue
    }

    if ($line -match '^f\s+') {
        $faceIndex++

        if ($faceIndex -le 2) {
            if (-not $groundMaterialInserted) {
                $newLines.Add("usemtl ground")
                $groundMaterialInserted = $true
            }
        }
        else {
            if (-not $buildingMaterialInserted) {
                $newLines.Add("usemtl buildings")
                $buildingMaterialInserted = $true
            }
        }
    }

    $newLines.Add($line)
}

Set-Content -Path $resolvedObj -Value $newLines -Encoding ASCII

@(
    "# Montpellier Game tile materials",
    "newmtl ground",
    "Ka 0.35 0.35 0.35",
    "Kd 0.42 0.46 0.42",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1",
    "",
    "newmtl buildings",
    "Ka 0.55 0.55 0.55",
    "Kd 0.78 0.78 0.78",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1"
) | Set-Content -Path $mtlPath -Encoding ASCII

Write-Host "=== APPLY TILE MATERIALS ==="
Write-Host "OBJ : $resolvedObj"
Write-Host "MTL : $mtlPath"
Write-Host "Faces found : $faceIndex"
Write-Host "Ground faces : 2"
Write-Host "Building faces : $([Math]::Max(0, $faceIndex - 2))"
