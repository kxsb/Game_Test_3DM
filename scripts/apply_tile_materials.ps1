param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function Parse-FloatInvariant {
    param([string]$Value)

    return [double]::Parse(
        $Value.Replace(",", "."),
        [System.Globalization.NumberStyles]::Float,
        $InvariantCulture
    )
}

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

$vertices = New-Object System.Collections.Generic.List[object]

foreach ($line in $originalLines) {
    if ($line -match '^v\s+') {
        $parts = $line -split '\s+'

        if ($parts.Count -ge 4) {
            $vertices.Add([pscustomobject]@{
                X = Parse-FloatInvariant $parts[1]
                Y = Parse-FloatInvariant $parts[2]
                Z = Parse-FloatInvariant $parts[3]
            })
        }
    }
}

function Get-FaceVertexIndex {
    param([string]$Token)

    $raw = ($Token -split '/')[0]
    return [int]$raw
}

function Get-FaceMaterial {
    param([string]$FaceLine)

    $parts = $FaceLine -split '\s+'

    if ($parts.Count -lt 4) {
        return "building_generic"
    }

    $ys = New-Object System.Collections.Generic.List[double]

    for ($i = 1; $i -lt $parts.Count; $i++) {
        $idx = Get-FaceVertexIndex $parts[$i]

        if ($idx -lt 0) {
            $idx = $vertices.Count + $idx + 1
        }

        $zero = $idx - 1

        if ($zero -ge 0 -and $zero -lt $vertices.Count) {
            $ys.Add($vertices[$zero].Y)
        }
    }

    if ($ys.Count -eq 0) {
        return "building_generic"
    }

    $minY = ($ys | Measure-Object -Minimum).Minimum
    $maxY = ($ys | Measure-Object -Maximum).Maximum
    $spreadY = $maxY - $minY

    # Le sol et les bases très basses restent lisibles.
    if ($maxY -le 0.35) {
        return "ground_low"
    }

    # Surfaces horizontales / toitures / terrasses.
    if ($spreadY -le 0.65) {
        if ($minY -le 3.0) {
            return "ground_slope"
        }

        if ($minY -gt 18.0) {
            return "roof_high"
        }

        return "roof"
    }

    # Façades, murs et grands pans verticaux.
    if ($spreadY -gt 3.0) {
        return "wall"
    }

    return "building_generic"
}

$newLines.Add("mtllib $mtlName")

$currentMaterial = ""
$faceIndex = 0
$counts = @{}

foreach ($line in $originalLines) {
    if ($line -match '^mtllib\s+') {
        continue
    }

    if ($line -match '^usemtl\s+') {
        continue
    }

    if ($line -match '^f\s+') {
        $faceIndex++
        $material = Get-FaceMaterial $line

        if (-not $counts.ContainsKey($material)) {
            $counts[$material] = 0
        }

        $counts[$material]++

        if ($material -ne $currentMaterial) {
            $newLines.Add("usemtl $material")
            $currentMaterial = $material
        }
    }

    $newLines.Add($line)
}

Set-Content -Path $resolvedObj -Value $newLines -Encoding ASCII

@(
    "# Montpellier Game tile materials",
    "",
    "newmtl ground_low",
    "Ka 0.25 0.32 0.25",
    "Kd 0.42 0.54 0.42",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1",
    "",
    "newmtl ground_slope",
    "Ka 0.30 0.34 0.30",
    "Kd 0.48 0.56 0.48",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1",
    "",
    "newmtl wall",
    "Ka 0.50 0.49 0.46",
    "Kd 0.74 0.72 0.66",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1",
    "",
    "newmtl roof",
    "Ka 0.42 0.39 0.36",
    "Kd 0.62 0.58 0.52",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1",
    "",
    "newmtl roof_high",
    "Ka 0.36 0.36 0.38",
    "Kd 0.54 0.54 0.58",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1",
    "",
    "newmtl building_generic",
    "Ka 0.46 0.46 0.44",
    "Kd 0.68 0.68 0.64",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1"
) | Set-Content -Path $mtlPath -Encoding ASCII

Write-Host "=== APPLY TILE MATERIALS ==="
Write-Host "OBJ : $resolvedObj"
Write-Host "MTL : $mtlPath"
Write-Host "Faces found : $faceIndex"

foreach ($key in ($counts.Keys | Sort-Object)) {
    Write-Host ("{0} : {1}" -f $key, $counts[$key])
}
