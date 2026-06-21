param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [double]$CenterX = 770727.18,
    [double]$CenterY = 6279737.513,

    [double]$Width = 250.0,
    [double]$Depth = 250.0,

    [double]$GroundCellSize = 6.0,

    [int]$MaxPolygons = 120000
)

$ErrorActionPreference = "Stop"
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function Format-Float {
    param([double]$Value)

    return $Value.ToString("0.###", $InvariantCulture)
}

function Parse-Float {
    param([string]$Value)

    return [double]::Parse($Value.Replace(",", "."), $InvariantCulture)
}

function New-Point3 {
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

function Remove-ClosingPoint {
    param($Points)

    if ($Points.Count -lt 2) {
        return $Points
    }

    $first = $Points[0]
    $last = $Points[$Points.Count - 1]

    $same =
        ([Math]::Abs($first.X - $last.X) -lt 0.001) -and
        ([Math]::Abs($first.Y - $last.Y) -lt 0.001) -and
        ([Math]::Abs($first.Z - $last.Z) -lt 0.001)

    if (-not $same) {
        return $Points
    }

    $trimmed = New-Object System.Collections.Generic.List[object]

    for ($i = 0; $i -lt $Points.Count - 1; $i++) {
        $trimmed.Add($Points[$i])
    }

    return $trimmed
}

function Get-PolygonBounds {
    param($Points)

    $minX = [double]::PositiveInfinity
    $maxX = [double]::NegativeInfinity
    $minY = [double]::PositiveInfinity
    $maxY = [double]::NegativeInfinity
    $minZ = [double]::PositiveInfinity
    $maxZ = [double]::NegativeInfinity

    foreach ($p in $Points) {
        if ($p.X -lt $minX) { $minX = $p.X }
        if ($p.X -gt $maxX) { $maxX = $p.X }
        if ($p.Y -lt $minY) { $minY = $p.Y }
        if ($p.Y -gt $maxY) { $maxY = $p.Y }
        if ($p.Z -lt $minZ) { $minZ = $p.Z }
        if ($p.Z -gt $maxZ) { $maxZ = $p.Z }
    }

    return [pscustomobject]@{
        MinX = $minX
        MaxX = $maxX
        MinY = $minY
        MaxY = $maxY
        MinZ = $minZ
        MaxZ = $maxZ
    }
}

function Polygon-IntersectsTile {
    param(
        $Bounds,
        [double]$TileMinX,
        [double]$TileMaxX,
        [double]$TileMinY,
        [double]$TileMaxY
    )

    if ($Bounds.MaxX -lt $TileMinX) { return $false }
    if ($Bounds.MinX -gt $TileMaxX) { return $false }
    if ($Bounds.MaxY -lt $TileMinY) { return $false }
    if ($Bounds.MinY -gt $TileMaxY) { return $false }

    return $true
}

function Parse-PosList {
    param([string]$Text)

    $match = [regex]::Match(
        $Text,
        '<gml:posList[^>]*>(.*?)</gml:posList>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    if (-not $match.Success) {
        return $null
    }

    $inner = $match.Groups[1].Value.Trim()

    if (-not $inner) {
        return $null
    }

    $parts = $inner -split '\s+'

    if ($parts.Count -lt 9) {
        return $null
    }

    $points = New-Object System.Collections.Generic.List[object]

    for ($i = 0; $i + 2 -lt $parts.Count; $i += 3) {
        $points.Add((New-Point3 `
            -X (Parse-Float $parts[$i]) `
            -Y (Parse-Float $parts[$i + 1]) `
            -Z (Parse-Float $parts[$i + 2])
        ))
    }

    return Remove-ClosingPoint $points
}

function Add-GroundSample {
    param(
        [hashtable]$Samples,
        [double]$GameX,
        [double]$GameY,
        [double]$GameZ,
        [double]$MinX,
        [double]$MinZ,
        [double]$CellSize,
        [int]$WidthCells,
        [int]$DepthCells
    )

    $ix = [int][Math]::Floor(($GameX - $MinX) / $CellSize)
    $iz = [int][Math]::Floor(($GameZ - $MinZ) / $CellSize)

    if ($ix -lt 0 -or $ix -ge $WidthCells -or $iz -lt 0 -or $iz -ge $DepthCells) {
        return
    }

    $key = "$ix,$iz"

    if (-not $Samples.ContainsKey($key)) {
        $Samples[$key] = New-Object System.Collections.Generic.List[double]
    }

    $Samples[$key].Add($GameY)
}

function Select-GroundHeight {
    param($Values)

    if ($Values.Count -eq 0) {
        return 0.0
    }

    $sorted = @($Values | Sort-Object)
    $index = [int][Math]::Floor(([Math]::Max(0, $sorted.Count - 1)) * 0.20)

    return [double]$sorted[$index]
}

if (-not (Test-Path $Path)) {
    throw "CityGML introuvable : $Path"
}

$outputDir = Split-Path $OutputPath -Parent

if ($outputDir) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$resolvedInput = (Resolve-Path $Path).Path
$resolvedOutput = $OutputPath

$tileMinX = $CenterX - ($Width / 2.0)
$tileMaxX = $CenterX + ($Width / 2.0)
$tileMinY = $CenterY - ($Depth / 2.0)
$tileMaxY = $CenterY + ($Depth / 2.0)

Write-Host "=== CITYGML EXTRACT TILE ==="
Write-Host "Input : $resolvedInput"
Write-Host "Output : $resolvedOutput"
Write-Host "Tile center : X=$CenterX Y=$CenterY"
Write-Host "Tile bounds : min($tileMinX, $tileMinY) max($tileMaxX, $tileMaxY)"
Write-Host ""

$polygons = New-Object System.Collections.Generic.List[object]

$currentSurface = "generic"
$currentBuildingId = ""
$posListScanned = 0
$posListSelected = 0

$reader = [System.IO.StreamReader]::new($resolvedInput)

try {
    while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()

        if ($null -eq $line) {
            break
        }

        if ($line -match '<bldg:Building[^>]*gml:id="([^"]+)"') {
            $currentBuildingId = $Matches[1]
        }

        if ($line -match '<bldg:WallSurface') {
            $currentSurface = "wall"
        }
        elseif ($line -match '<bldg:RoofSurface') {
            $currentSurface = "roof"
        }
        elseif ($line -match '<bldg:GroundSurface') {
            $currentSurface = "ground"
        }

        if ($line -match '<gml:posList') {
            $posText = $line

            while (($posText -notmatch '</gml:posList>') -and (-not $reader.EndOfStream)) {
                $posText += " " + $reader.ReadLine()
            }

            $posListScanned++

            $points = Parse-PosList $posText

            if ($null -eq $points -or $points.Count -lt 3) {
                continue
            }

            $bounds = Get-PolygonBounds $points

            if (-not (Polygon-IntersectsTile `
                -Bounds $bounds `
                -TileMinX $tileMinX `
                -TileMaxX $tileMaxX `
                -TileMinY $tileMinY `
                -TileMaxY $tileMaxY
            )) {
                continue
            }

            if ($polygons.Count -ge $MaxPolygons) {
                break
            }

            $polygons.Add([pscustomobject]@{
                Surface = $currentSurface
                BuildingId = $currentBuildingId
                Points = $points
                Bounds = $bounds
            })

            $posListSelected++
        }

        if ($line -match '</bldg:WallSurface>' -or
            $line -match '</bldg:RoofSurface>' -or
            $line -match '</bldg:GroundSurface>') {
            $currentSurface = "generic"
        }
    }
}
finally {
    $reader.Close()
}

if ($polygons.Count -eq 0) {
    throw "Aucun polygone CityGML sélectionné dans la tuile."
}

$groundCandidates = New-Object System.Collections.Generic.List[double]
$allZ = New-Object System.Collections.Generic.List[double]

foreach ($poly in $polygons) {
    foreach ($p in $poly.Points) {
        $allZ.Add($p.Z)

        if ($poly.Surface -eq "ground") {
            $groundCandidates.Add($p.Z)
        }
    }
}

if ($groundCandidates.Count -gt 0) {
    $groundZ = ($groundCandidates | Measure-Object -Minimum).Minimum
}
else {
    $groundZ = ($allZ | Measure-Object -Minimum).Minimum
}

Write-Host "Polygons selected : $($polygons.Count)"
Write-Host "posList scanned : $posListScanned"
Write-Host "posList selected : $posListSelected"
Write-Host "Ground Z : $groundZ"
Write-Host ""

$mtlName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath) + ".mtl"
$mtlPath = [System.IO.Path]::ChangeExtension($OutputPath, ".mtl")
$groundPath = [System.IO.Path]::ChangeExtension($OutputPath, ".ground.txt")

$objLines = New-Object System.Collections.Generic.List[string]
$objLines.Add("# Montpellier Game CityGML tile OBJ")
$objLines.Add("# Source: local CityGML path omitted")
$objLines.Add("# CenterX: $(Format-Float $CenterX)")
$objLines.Add("# CenterY: $(Format-Float $CenterY)")
$objLines.Add("# GroundZ: $(Format-Float $groundZ)")
$objLines.Add("mtllib $mtlName")

$currentMaterial = ""
$vertexIndex = 1
$facesWritten = 0
$verticesWritten = 0

$materialCounts = @{}

foreach ($poly in $polygons) {
    $points = $poly.Points

    if ($points.Count -lt 3) {
        continue
    }

    $material = "citygml_generic"

    if ($poly.Surface -eq "wall") {
        $material = "citygml_wall"
    }
    elseif ($poly.Surface -eq "roof") {
        $material = "citygml_roof"
    }
    elseif ($poly.Surface -eq "ground") {
        $material = "citygml_ground"
    }

    if (-not $materialCounts.ContainsKey($material)) {
        $materialCounts[$material] = 0
    }

    if ($material -ne $currentMaterial) {
        $objLines.Add("usemtl $material")
        $currentMaterial = $material
    }

    $indices = @()

    foreach ($p in $points) {
        $gameX = $p.X - $CenterX
        $gameY = $p.Z - $groundZ
        $gameZ = $p.Y - $CenterY

        $objLines.Add("v $(Format-Float $gameX) $(Format-Float $gameY) $(Format-Float $gameZ)")
        $indices += $vertexIndex
        $vertexIndex++
        $verticesWritten++
    }

    for ($i = 1; $i -lt $indices.Count - 1; $i++) {
        $objLines.Add("f $($indices[0]) $($indices[$i]) $($indices[$i + 1])")
        $facesWritten++
        $materialCounts[$material]++
    }
}

Set-Content -Path $OutputPath -Value $objLines -Encoding ASCII

@(
    "# Montpellier Game CityGML materials",
    "",
    "newmtl citygml_ground",
    "Ka 0.24 0.32 0.25",
    "Kd 0.40 0.52 0.42",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1",
    "",
    "newmtl citygml_wall",
    "Ka 0.50 0.48 0.43",
    "Kd 0.72 0.70 0.62",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1",
    "",
    "newmtl citygml_roof",
    "Ka 0.35 0.35 0.37",
    "Kd 0.54 0.54 0.58",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1",
    "",
    "newmtl citygml_generic",
    "Ka 0.46 0.46 0.44",
    "Kd 0.68 0.68 0.64",
    "Ks 0.00 0.00 0.00",
    "d 1.0",
    "illum 1"
) | Set-Content -Path $mtlPath -Encoding ASCII

# ------------------------------------------------------------
# Ground sidecar
# ------------------------------------------------------------
$groundMinX = -($Width / 2.0)
$groundMinZ = -($Depth / 2.0)
$groundWidthCells = [Math]::Max(1, [int][Math]::Ceiling($Width / $GroundCellSize))
$groundDepthCells = [Math]::Max(1, [int][Math]::Ceiling($Depth / $GroundCellSize))

$groundSamples = @{}

foreach ($poly in $polygons) {
    $points = $poly.Points

    if ($points.Count -lt 3) {
        continue
    }

    $minSourceZ = ($points | ForEach-Object { $_.Z } | Measure-Object -Minimum).Minimum

    foreach ($p in $points) {
        $gameX = $p.X - $CenterX
        $gameY = $p.Z - $groundZ
        $gameZ = $p.Y - $CenterY

        if ($poly.Surface -eq "ground") {
            Add-GroundSample `
                -Samples $groundSamples `
                -GameX $gameX `
                -GameY $gameY `
                -GameZ $gameZ `
                -MinX $groundMinX `
                -MinZ $groundMinZ `
                -CellSize $GroundCellSize `
                -WidthCells $groundWidthCells `
                -DepthCells $groundDepthCells
        }
        elseif ([Math]::Abs($p.Z - $minSourceZ) -le 0.45) {
            Add-GroundSample `
                -Samples $groundSamples `
                -GameX $gameX `
                -GameY $gameY `
                -GameZ $gameZ `
                -MinX $groundMinX `
                -MinZ $groundMinZ `
                -CellSize $GroundCellSize `
                -WidthCells $groundWidthCells `
                -DepthCells $groundDepthCells
        }
    }
}

$groundLines = New-Object System.Collections.Generic.List[string]
$groundLines.Add("# Montpellier Game ground sidecar generated from CityGML tile")
$groundLines.Add("# Format:")
$groundLines.Add("# grid minX minZ cellSize width depth fallbackY")
$groundLines.Add("# cell ix iz height sampleCount")
$groundLines.Add("# Source: local CityGML path omitted")
$groundLines.Add("# Mode: citygml_ground_and_low_vertices")
$groundLines.Add("grid $(Format-Float $groundMinX) $(Format-Float $groundMinZ) $(Format-Float $GroundCellSize) $groundWidthCells $groundDepthCells 0")

foreach ($key in ($groundSamples.Keys | Sort-Object)) {
    $parts = $key.Split(",")
    $values = $groundSamples[$key]

    if ($values.Count -eq 0) {
        continue
    }

    $height = Select-GroundHeight $values
    $groundLines.Add("cell $($parts[0]) $($parts[1]) $(Format-Float $height) $($values.Count)")
}

Set-Content -Path $groundPath -Value $groundLines -Encoding ASCII

Write-Host "=== CITYGML TILE OBJ ==="
Write-Host "Output OBJ : $OutputPath"
Write-Host "Output MTL : $mtlPath"
Write-Host "Output ground : $groundPath"
Write-Host "Vertices : $verticesWritten"
Write-Host "Triangles : $facesWritten"
Write-Host "Ground sampled cells : $($groundSamples.Count)"

foreach ($key in ($materialCounts.Keys | Sort-Object)) {
    Write-Host ("{0} : {1}" -f $key, $materialCounts[$key])
}
