param(
    [string]$InputObj = "data\raw\montpellier\photomodel_exports\C06_crop\C06_crop.obj",
    [string]$OutputDir = "data\raw\montpellier\photomodel_exports\C06_buildings",

    # Toute surface basse et plutôt horizontale est considérée comme terrain parasite.
    [double]$GroundCullHeight = 4.0,

    # 1 = horizontal parfait, 0 = vertical parfait.
    [double]$HorizontalNormalThreshold = 0.62,

    # Sécurité contre très grands triangles résiduels.
    [double]$MaxTriangleEdge = 55.0
)

$ErrorActionPreference = "Stop"
$Culture = [System.Globalization.CultureInfo]::InvariantCulture

function Parse-Double {
    param([string]$Value)
    return [double]::Parse($Value.Replace(",", "."), $Culture)
}

function Format-Double {
    param([double]$Value)
    return $Value.ToString("0.######", $Culture)
}

function New-Vec3 {
    param(
        [double]$X,
        [double]$Y,
        [double]$Z
    )

    return [pscustomobject]@{
        X = $X
        Y = $Y
        Z = $Z
    }
}

function Convert-FaceToken {
    param([string]$Token)
    return [int](($Token -split "/")[0])
}

function Sub-Vec3 {
    param($A, $B)

    return New-Vec3 -X ($A.X - $B.X) -Y ($A.Y - $B.Y) -Z ($A.Z - $B.Z)
}

function Cross-Vec3 {
    param($A, $B)

    return New-Vec3 `
        -X (($A.Y * $B.Z) - ($A.Z * $B.Y)) `
        -Y (($A.Z * $B.X) - ($A.X * $B.Z)) `
        -Z (($A.X * $B.Y) - ($A.Y * $B.X))
}

function Length-Vec3 {
    param($A)

    return [Math]::Sqrt(($A.X * $A.X) + ($A.Y * $A.Y) + ($A.Z * $A.Z))
}

function Distance-Vec3 {
    param($A, $B)

    return (Length-Vec3 (Sub-Vec3 $A $B))
}

function Get-AbsNormalY {
    param($A, $B, $C)

    $ab = Sub-Vec3 $B $A
    $ac = Sub-Vec3 $C $A
    $cross = Cross-Vec3 $ab $ac
    $len = Length-Vec3 $cross

    if ($len -le 0.000001) {
        return 1.0
    }

    return [Math]::Abs($cross.Y / $len)
}

function Get-ObjBounds {
    param($Vertices, $Faces)

    $minX = [double]::PositiveInfinity
    $minY = [double]::PositiveInfinity
    $minZ = [double]::PositiveInfinity
    $maxX = [double]::NegativeInfinity
    $maxY = [double]::NegativeInfinity
    $maxZ = [double]::NegativeInfinity

    foreach ($face in $Faces) {
        foreach ($idx in $face) {
            $v = $Vertices[$idx - 1]

            if ($v.X -lt $minX) { $minX = $v.X }
            if ($v.Y -lt $minY) { $minY = $v.Y }
            if ($v.Z -lt $minZ) { $minZ = $v.Z }
            if ($v.X -gt $maxX) { $maxX = $v.X }
            if ($v.Y -gt $maxY) { $maxY = $v.Y }
            if ($v.Z -gt $maxZ) { $maxZ = $v.Z }
        }
    }

    return [pscustomobject]@{
        MinX = $minX
        MinY = $minY
        MinZ = $minZ
        MaxX = $maxX
        MaxY = $maxY
        MaxZ = $maxZ
        SizeX = $maxX - $minX
        SizeY = $maxY - $minY
        SizeZ = $maxZ - $minZ
    }
}

Write-Host "=== GENERATE PHOTOMODEL BUILDINGS ONLY ===" -ForegroundColor Cyan
Write-Host "InputObj : $InputObj"
Write-Host "OutputDir : $OutputDir"
Write-Host "GroundCullHeight : $GroundCullHeight"
Write-Host "HorizontalNormalThreshold : $HorizontalNormalThreshold"
Write-Host "MaxTriangleEdge : $MaxTriangleEdge"

if (-not (Test-Path $InputObj)) {
    throw "Input OBJ introuvable : $InputObj"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$outputObj = Join-Path $OutputDir "C06_buildings.obj"
$outputMtl = Join-Path $OutputDir "C06_buildings.mtl"

$vertices = New-Object System.Collections.Generic.List[object]
$faces = New-Object System.Collections.Generic.List[object]

Get-Content $InputObj -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()

    if ($line.StartsWith("v ")) {
        $parts = $line -split "\s+"

        if ($parts.Count -ge 4) {
            $vertices.Add((New-Vec3 `
                -X (Parse-Double $parts[1]) `
                -Y (Parse-Double $parts[2]) `
                -Z (Parse-Double $parts[3])
            ))
        }

        return
    }

    if ($line.StartsWith("f ")) {
        $parts = $line -split "\s+"

        if ($parts.Count -lt 4) {
            return
        }

        $idx = New-Object System.Collections.Generic.List[int]

        for ($i = 1; $i -lt $parts.Count; $i++) {
            $idx.Add((Convert-FaceToken $parts[$i]))
        }

        if ($idx.Count -ge 3) {
            for ($i = 1; $i -lt $idx.Count - 1; $i++) {
                $faces.Add(@($idx[0], $idx[$i], $idx[$i + 1]))
            }
        }
    }
}

if ($vertices.Count -eq 0 -or $faces.Count -eq 0) {
    throw "OBJ invalide : vertices=$($vertices.Count) faces=$($faces.Count)"
}

$keptFaces = New-Object System.Collections.Generic.List[object]
$dropLowHorizontal = 0
$dropLong = 0
$dropDegenerate = 0

foreach ($face in $faces) {
    $a = $vertices[$face[0] - 1]
    $b = $vertices[$face[1] - 1]
    $c = $vertices[$face[2] - 1]

    $edgeAB = Distance-Vec3 $a $b
    $edgeBC = Distance-Vec3 $b $c
    $edgeCA = Distance-Vec3 $c $a
    $maxEdge = [Math]::Max($edgeAB, [Math]::Max($edgeBC, $edgeCA))

    if ($maxEdge -le 0.000001) {
        $dropDegenerate++
        continue
    }

    if ($maxEdge -gt $MaxTriangleEdge) {
        $dropLong++
        continue
    }

    $avgY = ($a.Y + $b.Y + $c.Y) / 3.0
    $absNormalY = Get-AbsNormalY $a $b $c

    $isLowHorizontal =
        $avgY -le $GroundCullHeight -and
        $absNormalY -ge $HorizontalNormalThreshold

    if ($isLowHorizontal) {
        $dropLowHorizontal++
        continue
    }

    $keptFaces.Add($face)
}

if ($keptFaces.Count -eq 0) {
    throw "Tous les triangles ont été supprimés. Paramètres trop agressifs."
}

$used = @{}

foreach ($face in $keptFaces) {
    $used[$face[0]] = $true
    $used[$face[1]] = $true
    $used[$face[2]] = $true
}

$selectedVertexKeys = @($used.Keys | ForEach-Object { [int]$_ } | Sort-Object)

$oldToNew = @{}
$out = New-Object System.Collections.Generic.List[string]
$out.Add("# C06 buildings-only photomodel minimal")
$out.Add("# Generated by scripts/generate_photomodel_buildings_only.ps1")
$out.Add("mtllib C06_buildings.mtl")
$out.Add("usemtl photomodel_buildings")

$newIndex = 1

foreach ($oldIndex in $selectedVertexKeys) {
    $v = $vertices[$oldIndex - 1]
    $oldToNew[$oldIndex] = $newIndex
    $out.Add(("v {0} {1} {2}" -f (Format-Double $v.X), (Format-Double $v.Y), (Format-Double $v.Z)))
    $newIndex++
}

foreach ($face in $keptFaces) {
    $a = $oldToNew[$face[0]]
    $b = $oldToNew[$face[1]]
    $c = $oldToNew[$face[2]]

    if ($null -ne $a -and $null -ne $b -and $null -ne $c) {
        $out.Add("f $a $b $c")
    }
}

$out | Set-Content $outputObj -Encoding ASCII

@(
    "# C06 buildings-only material",
    "newmtl photomodel_buildings",
    "Ka 0.78 0.78 0.74",
    "Kd 0.96 0.95 0.88",
    "Ks 0.00 0.00 0.00",
    "d 0.42",
    "illum 1"
) | Set-Content $outputMtl -Encoding ASCII

$bounds = Get-ObjBounds $vertices $keptFaces

Write-Host ""
Write-Host "=== Buildings-only generated ===" -ForegroundColor Cyan
Write-Host "Output OBJ : $outputObj"
Write-Host "Output MTL : $outputMtl"
Write-Host "Input vertices : $($vertices.Count)"
Write-Host "Input triangles : $($faces.Count)"
Write-Host "Kept triangles : $($keptFaces.Count)"
Write-Host "Kept vertices : $($selectedVertexKeys.Count)"
Write-Host "Dropped low horizontal : $dropLowHorizontal"
Write-Host "Dropped long triangles : $dropLong"
Write-Host "Dropped degenerate : $dropDegenerate"
Write-Host ""
Write-Host ("Bounds X {0} -> {1}" -f (Format-Double $bounds.MinX), (Format-Double $bounds.MaxX))
Write-Host ("Bounds Y {0} -> {1}" -f (Format-Double $bounds.MinY), (Format-Double $bounds.MaxY))
Write-Host ("Bounds Z {0} -> {1}" -f (Format-Double $bounds.MinZ), (Format-Double $bounds.MaxZ))
Write-Host ""
Write-Host "Use this overlay:"
Write-Host ".\build\montpellier.exe assets\models\citygml_tile_centre_w250_d250.obj $outputObj"
