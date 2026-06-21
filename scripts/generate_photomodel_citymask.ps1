param(
    [string]$CityObj = "assets\models\citygml_tile_centre_w250_d250.obj",
    [string]$PhotoObj = "data\raw\montpellier\photomodel_exports\C06_buildings\C06_buildings.obj",
    [string]$OutputDir = "data\raw\montpellier\photomodel_exports\C06_citymask",

    [double]$CellSize = 4.0,
    [int]$DilateCells = 2,
    [double]$MaxTriangleEdge = 42.0,
    [double]$MaxTriangleArea = 280.0
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
    param([double]$X, [double]$Y, [double]$Z)
    return [pscustomobject]@{ X = $X; Y = $Y; Z = $Z }
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

function Triangle-Area {
    param($A, $B, $C)
    $ab = Sub-Vec3 $B $A
    $ac = Sub-Vec3 $C $A
    return (Length-Vec3 (Cross-Vec3 $ab $ac)) * 0.5
}

function Cell-Key {
    param([double]$X, [double]$Z, [double]$CellSize)
    $ix = [int][Math]::Floor($X / $CellSize)
    $iz = [int][Math]::Floor($Z / $CellSize)
    return "$ix,$iz"
}

function Add-Cell {
    param([hashtable]$Mask, [double]$X, [double]$Z, [double]$CellSize)
    $key = Cell-Key -X $X -Z $Z -CellSize $CellSize
    $Mask[$key] = $true
}

function Has-Mask-Near {
    param(
        [hashtable]$Mask,
        [double]$X,
        [double]$Z,
        [double]$CellSize,
        [int]$Radius
    )

    $ix = [int][Math]::Floor($X / $CellSize)
    $iz = [int][Math]::Floor($Z / $CellSize)

    for ($dx = -$Radius; $dx -le $Radius; $dx++) {
        for ($dz = -$Radius; $dz -le $Radius; $dz++) {
            $key = "$($ix + $dx),$($iz + $dz)"
            if ($Mask.ContainsKey($key)) {
                return $true
            }
        }
    }

    return $false
}

function Read-ObjSimple {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "OBJ introuvable : $Path"
    }

    $vertices = New-Object System.Collections.Generic.List[object]
    $faces = New-Object System.Collections.Generic.List[object]
    $currentMaterial = ""

    Get-Content $Path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()

        if ($line.StartsWith("usemtl ")) {
            $currentMaterial = $line.Substring(7).Trim()
            return
        }

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
            if ($parts.Count -lt 4) { return }

            $idx = New-Object System.Collections.Generic.List[int]
            for ($i = 1; $i -lt $parts.Count; $i++) {
                $idx.Add((Convert-FaceToken $parts[$i]))
            }

            if ($idx.Count -ge 3) {
                for ($i = 1; $i -lt $idx.Count - 1; $i++) {
                    $faces.Add([pscustomobject]@{
                        A = $idx[0]
                        B = $idx[$i]
                        C = $idx[$i + 1]
                        Material = $currentMaterial
                    })
                }
            }
        }
    }

    return [pscustomobject]@{
        Vertices = $vertices
        Faces = $faces
    }
}

Write-Host "=== GENERATE PHOTOMODEL CITYMASK ===" -ForegroundColor Cyan
Write-Host "CityObj : $CityObj"
Write-Host "PhotoObj : $PhotoObj"
Write-Host "OutputDir : $OutputDir"
Write-Host "CellSize : $CellSize"
Write-Host "DilateCells : $DilateCells"
Write-Host "MaxTriangleEdge : $MaxTriangleEdge"
Write-Host "MaxTriangleArea : $MaxTriangleArea"

$city = Read-ObjSimple $CityObj
$photo = Read-ObjSimple $PhotoObj

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$outputObj = Join-Path $OutputDir "C06_citymask.obj"
$outputMtl = Join-Path $OutputDir "C06_citymask.mtl"

# ------------------------------------------------------------
# Masque bâti depuis CityGML hors citygml_ground
# ------------------------------------------------------------
$mask = @{}
$cityFacesUsed = 0

foreach ($face in $city.Faces) {
    if ($face.Material -eq "citygml_ground") {
        continue
    }

    $a = $city.Vertices[$face.A - 1]
    $b = $city.Vertices[$face.B - 1]
    $c = $city.Vertices[$face.C - 1]

    $minX = [Math]::Min($a.X, [Math]::Min($b.X, $c.X))
    $maxX = [Math]::Max($a.X, [Math]::Max($b.X, $c.X))
    $minZ = [Math]::Min($a.Z, [Math]::Min($b.Z, $c.Z))
    $maxZ = [Math]::Max($a.Z, [Math]::Max($b.Z, $c.Z))

    for ($x = $minX; $x -le $maxX; $x += $CellSize) {
        for ($z = $minZ; $z -le $maxZ; $z += $CellSize) {
            Add-Cell -Mask $mask -X $x -Z $z -CellSize $CellSize
        }
    }

    Add-Cell -Mask $mask -X (($a.X + $b.X + $c.X) / 3.0) -Z (($a.Z + $b.Z + $c.Z) / 3.0) -CellSize $CellSize
    $cityFacesUsed++
}

# ------------------------------------------------------------
# Filtrer photo
# ------------------------------------------------------------
$keptFaces = New-Object System.Collections.Generic.List[object]
$dropMask = 0
$dropLong = 0
$dropArea = 0
$dropDegenerate = 0

foreach ($face in $photo.Faces) {
    $a = $photo.Vertices[$face.A - 1]
    $b = $photo.Vertices[$face.B - 1]
    $c = $photo.Vertices[$face.C - 1]

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

    $area = Triangle-Area $a $b $c
    if ($area -gt $MaxTriangleArea) {
        $dropArea++
        continue
    }

    $cx = ($a.X + $b.X + $c.X) / 3.0
    $cz = ($a.Z + $b.Z + $c.Z) / 3.0

    if (-not (Has-Mask-Near -Mask $mask -X $cx -Z $cz -CellSize $CellSize -Radius $DilateCells)) {
        $dropMask++
        continue
    }

    $keptFaces.Add($face)
}

if ($keptFaces.Count -eq 0) {
    throw "Tous les triangles photo supprimés. Augmenter DilateCells ou MaxTriangleArea."
}

$used = @{}
foreach ($face in $keptFaces) {
    $used[$face.A] = $true
    $used[$face.B] = $true
    $used[$face.C] = $true
}

$selectedVertexKeys = @($used.Keys | ForEach-Object { [int]$_ } | Sort-Object)

$oldToNew = @{}
$out = New-Object System.Collections.Generic.List[string]
$out.Add("# C06 citymask photomodel minimal")
$out.Add("# Generated by scripts/generate_photomodel_citymask.ps1")
$out.Add("mtllib C06_citymask.mtl")
$out.Add("usemtl photomodel_citymask")

$newIndex = 1
foreach ($oldIndex in $selectedVertexKeys) {
    $v = $photo.Vertices[$oldIndex - 1]
    $oldToNew[$oldIndex] = $newIndex
    $out.Add(("v {0} {1} {2}" -f (Format-Double $v.X), (Format-Double $v.Y), (Format-Double $v.Z)))
    $newIndex++
}

foreach ($face in $keptFaces) {
    $a = $oldToNew[$face.A]
    $b = $oldToNew[$face.B]
    $c = $oldToNew[$face.C]
    if ($null -ne $a -and $null -ne $b -and $null -ne $c) {
        $out.Add("f $a $b $c")
    }
}

$out | Set-Content $outputObj -Encoding ASCII

@(
    "# C06 citymask material",
    "newmtl photomodel_citymask",
    "Ka 0.78 0.78 0.74",
    "Kd 0.96 0.94 0.86",
    "Ks 0.00 0.00 0.00",
    "d 0.42",
    "illum 1"
) | Set-Content $outputMtl -Encoding ASCII

Write-Host ""
Write-Host "=== Citymask generated ===" -ForegroundColor Cyan
Write-Host "Output OBJ : $outputObj"
Write-Host "Output MTL : $outputMtl"
Write-Host "City faces used for mask : $cityFacesUsed"
Write-Host "Mask cells : $($mask.Count)"
Write-Host "Photo input vertices : $($photo.Vertices.Count)"
Write-Host "Photo input triangles : $($photo.Faces.Count)"
Write-Host "Kept triangles : $($keptFaces.Count)"
Write-Host "Kept vertices : $($selectedVertexKeys.Count)"
Write-Host "Dropped by mask : $dropMask"
Write-Host "Dropped long triangles : $dropLong"
Write-Host "Dropped large area : $dropArea"
Write-Host "Dropped degenerate : $dropDegenerate"
Write-Host ""
Write-Host "Use this overlay:"
Write-Host ".\build\montpellier.exe $CityObj $outputObj"
