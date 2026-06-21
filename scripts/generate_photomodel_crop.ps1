param(
    [string]$CityObj = "assets\models\citygml_tile_centre_w250_d250.obj",
    [string]$PhotoObj = "data\raw\montpellier\photomodel_exports\C06_minimal\C06_minimal.obj",
    [string]$OutputDir = "data\raw\montpellier\photomodel_exports\C06_crop",

    [double]$OffsetX = -264.68,
    [double]$OffsetY = 0.0,
    [double]$OffsetZ = -173.27,
    [double]$Scale = 1.0,

    [double]$Margin = 18.0
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

function Get-ObjBounds {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "OBJ introuvable : $Path"
    }

    $minX = [double]::PositiveInfinity
    $minY = [double]::PositiveInfinity
    $minZ = [double]::PositiveInfinity
    $maxX = [double]::NegativeInfinity
    $maxY = [double]::NegativeInfinity
    $maxZ = [double]::NegativeInfinity
    $count = 0

    Get-Content $Path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()

        if (-not $line.StartsWith("v ")) {
            return
        }

        $parts = $line -split "\s+"

        if ($parts.Count -lt 4) {
            return
        }

        $x = Parse-Double $parts[1]
        $y = Parse-Double $parts[2]
        $z = Parse-Double $parts[3]

        if ($x -lt $minX) { $minX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($z -lt $minZ) { $minZ = $z }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -gt $maxY) { $maxY = $y }
        if ($z -gt $maxZ) { $maxZ = $z }

        $count++
    }

    if ($count -eq 0) {
        throw "Aucun vertex dans : $Path"
    }

    return [pscustomobject]@{
        MinX = $minX
        MinY = $minY
        MinZ = $minZ
        MaxX = $maxX
        MaxY = $maxY
        MaxZ = $maxZ
        CenterX = ($minX + $maxX) * 0.5
        CenterY = ($minY + $maxY) * 0.5
        CenterZ = ($minZ + $maxZ) * 0.5
        SizeX = $maxX - $minX
        SizeY = $maxY - $minY
        SizeZ = $maxZ - $minZ
        Count = $count
    }
}

function Convert-FaceToken {
    param([string]$Token)
    return [int](($Token -split "/")[0])
}

function Transform-PhotoVertex {
    param($Vertex)

    return New-Vec3 `
        -X ($Vertex.X * $Scale + $OffsetX) `
        -Y ($Vertex.Y * $Scale + $OffsetY) `
        -Z ($Vertex.Z * $Scale + $OffsetZ)
}

Write-Host "=== GENERATE PHOTOMODEL CROP ===" -ForegroundColor Cyan
Write-Host "City OBJ : $CityObj"
Write-Host "Photo OBJ : $PhotoObj"
Write-Host "OutputDir : $OutputDir"
Write-Host "Initial offset : $OffsetX $OffsetY $OffsetZ"
Write-Host "Scale : $Scale"
Write-Host "Margin : $Margin"

if (-not (Test-Path $CityObj)) {
    throw "City OBJ introuvable : $CityObj"
}

if (-not (Test-Path $PhotoObj)) {
    throw "Photo OBJ introuvable : $PhotoObj"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$outputObj = Join-Path $OutputDir "C06_crop.obj"
$outputMtl = Join-Path $OutputDir "C06_crop.mtl"

$cityBounds = Get-ObjBounds $CityObj

$cropMinX = $cityBounds.MinX - $Margin
$cropMaxX = $cityBounds.MaxX + $Margin
$cropMinZ = $cityBounds.MinZ - $Margin
$cropMaxZ = $cityBounds.MaxZ + $Margin
$cropMinY = $cityBounds.MinY - 8.0
$cropMaxY = $cityBounds.MaxY + 80.0

Write-Host ""
Write-Host "City bounds:"
Write-Host ("  X {0} -> {1}" -f (Format-Double $cityBounds.MinX), (Format-Double $cityBounds.MaxX))
Write-Host ("  Y {0} -> {1}" -f (Format-Double $cityBounds.MinY), (Format-Double $cityBounds.MaxY))
Write-Host ("  Z {0} -> {1}" -f (Format-Double $cityBounds.MinZ), (Format-Double $cityBounds.MaxZ))

Write-Host ""
Write-Host "Crop bounds:"
Write-Host ("  X {0} -> {1}" -f (Format-Double $cropMinX), (Format-Double $cropMaxX))
Write-Host ("  Y {0} -> {1}" -f (Format-Double $cropMinY), (Format-Double $cropMaxY))
Write-Host ("  Z {0} -> {1}" -f (Format-Double $cropMinZ), (Format-Double $cropMaxZ))

# ------------------------------------------------------------
# Lire vertices + faces
# ------------------------------------------------------------
$vertices = New-Object System.Collections.Generic.List[object]
$faces = New-Object System.Collections.Generic.List[object]

Get-Content $PhotoObj -Encoding UTF8 | ForEach-Object {
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
            # On garde les triangles existants ; si un ngon traîne, triangulation éventail.
            for ($i = 1; $i -lt $idx.Count - 1; $i++) {
                $faces.Add(@($idx[0], $idx[$i], $idx[$i + 1]))
            }
        }

        return
    }
}

if ($vertices.Count -eq 0 -or $faces.Count -eq 0) {
    throw "Photo OBJ invalide : vertices=$($vertices.Count) faces=$($faces.Count)"
}

# ------------------------------------------------------------
# Sélectionner triangles dont le centre tombe dans la tuile élargie
# ------------------------------------------------------------
$selectedFaces = New-Object System.Collections.Generic.List[object]
$used = @{}

foreach ($face in $faces) {
    $a = Transform-PhotoVertex $vertices[$face[0] - 1]
    $b = Transform-PhotoVertex $vertices[$face[1] - 1]
    $c = Transform-PhotoVertex $vertices[$face[2] - 1]

    $cx = ($a.X + $b.X + $c.X) / 3.0
    $cy = ($a.Y + $b.Y + $c.Y) / 3.0
    $cz = ($a.Z + $b.Z + $c.Z) / 3.0

    $inside =
        $cx -ge $cropMinX -and $cx -le $cropMaxX -and
        $cy -ge $cropMinY -and $cy -le $cropMaxY -and
        $cz -ge $cropMinZ -and $cz -le $cropMaxZ

    if (-not $inside) {
        continue
    }

    $selectedFaces.Add($face)
    $used[$face[0]] = $true
    $used[$face[1]] = $true
    $used[$face[2]] = $true
}

if ($selectedFaces.Count -eq 0) {
    throw "Aucun triangle sélectionné. Ajuster offset/margin."
}

# ------------------------------------------------------------
# Calculer bounds sélectionnés transformés
# ------------------------------------------------------------
$selectedVertexKeys = @($used.Keys | ForEach-Object { [int]$_ } | Sort-Object)

$worldByOldIndex = @{}
$minX = [double]::PositiveInfinity
$minY = [double]::PositiveInfinity
$minZ = [double]::PositiveInfinity
$maxX = [double]::NegativeInfinity
$maxY = [double]::NegativeInfinity
$maxZ = [double]::NegativeInfinity

foreach ($oldIndex in $selectedVertexKeys) {
    $world = Transform-PhotoVertex $vertices[$oldIndex - 1]
    $worldByOldIndex[$oldIndex] = $world

    if ($world.X -lt $minX) { $minX = $world.X }
    if ($world.Y -lt $minY) { $minY = $world.Y }
    if ($world.Z -lt $minZ) { $minZ = $world.Z }
    if ($world.X -gt $maxX) { $maxX = $world.X }
    if ($world.Y -gt $maxY) { $maxY = $world.Y }
    if ($world.Z -gt $maxZ) { $maxZ = $world.Z }
}

$selectedCenterX = ($minX + $maxX) * 0.5
$selectedCenterZ = ($minZ + $maxZ) * 0.5

# Correction pour que l'autopositionnement moteur devienne proche de 0.
$correctionX = $cityBounds.CenterX - $selectedCenterX
$correctionY = $cityBounds.MinY - $minY
$correctionZ = $cityBounds.CenterZ - $selectedCenterZ

Write-Host ""
Write-Host "Selected raw world bounds:"
Write-Host ("  X {0} -> {1}" -f (Format-Double $minX), (Format-Double $maxX))
Write-Host ("  Y {0} -> {1}" -f (Format-Double $minY), (Format-Double $maxY))
Write-Host ("  Z {0} -> {1}" -f (Format-Double $minZ), (Format-Double $maxZ))
Write-Host ("Correction baked: {0} {1} {2}" -f (Format-Double $correctionX), (Format-Double $correctionY), (Format-Double $correctionZ))

# ------------------------------------------------------------
# Écrire OBJ remappé
# ------------------------------------------------------------
$oldToNew = @{}
$out = New-Object System.Collections.Generic.List[string]
$out.Add("# C06 cropped photomodel minimal")
$out.Add("# Generated by scripts/generate_photomodel_crop.ps1")
$out.Add("# Source path omitted from commit")
$out.Add("mtllib C06_crop.mtl")
$out.Add("usemtl photomodel_crop")

$newIndex = 1

foreach ($oldIndex in $selectedVertexKeys) {
    $world = $worldByOldIndex[$oldIndex]

    $x = $world.X + $correctionX
    $y = $world.Y + $correctionY
    $z = $world.Z + $correctionZ

    $oldToNew[$oldIndex] = $newIndex
    $out.Add(("v {0} {1} {2}" -f (Format-Double $x), (Format-Double $y), (Format-Double $z)))
    $newIndex++
}

foreach ($face in $selectedFaces) {
    $a = $oldToNew[$face[0]]
    $b = $oldToNew[$face[1]]
    $c = $oldToNew[$face[2]]

    if ($null -ne $a -and $null -ne $b -and $null -ne $c) {
        $out.Add("f $a $b $c")
    }
}

$out | Set-Content $outputObj -Encoding ASCII

@(
    "# C06 crop material",
    "newmtl photomodel_crop",
    "Ka 0.75 0.75 0.72",
    "Kd 0.95 0.93 0.86",
    "Ks 0.00 0.00 0.00",
    "d 0.55",
    "illum 1"
) | Set-Content $outputMtl -Encoding ASCII

$finalBounds = Get-ObjBounds $outputObj

Write-Host ""
Write-Host "=== Crop generated ===" -ForegroundColor Cyan
Write-Host "Output OBJ : $outputObj"
Write-Host "Output MTL : $outputMtl"
Write-Host "Source vertices : $($vertices.Count)"
Write-Host "Source triangles : $($faces.Count)"
Write-Host "Selected triangles : $($selectedFaces.Count)"
Write-Host "Selected vertices : $($selectedVertexKeys.Count)"
Write-Host ""
Write-Host "Final baked bounds:"
Write-Host ("  X {0} -> {1}" -f (Format-Double $finalBounds.MinX), (Format-Double $finalBounds.MaxX))
Write-Host ("  Y {0} -> {1}" -f (Format-Double $finalBounds.MinY), (Format-Double $finalBounds.MaxY))
Write-Host ("  Z {0} -> {1}" -f (Format-Double $finalBounds.MinZ), (Format-Double $finalBounds.MaxZ))
Write-Host ""
Write-Host "Use this overlay:"
Write-Host ".\build\montpellier.exe $CityObj $outputObj"
