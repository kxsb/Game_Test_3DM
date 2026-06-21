param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath = "assets/models/dxf_tile_centre.obj",

    [double]$Width = 250,
    [double]$Depth = 250,
    [int]$MaxFaces = 50000,

    [string]$CenterX = "",
    [string]$CenterY = ""
)

$ErrorActionPreference = "Stop"
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function Parse-DoubleInvariant {
    param([string]$Text)
    return [double]::Parse($Text.Replace(",", "."), $InvariantCulture)
}

function Format-Float {
    param([double]$Value)
    return $Value.ToString("0.###", $InvariantCulture)
}

function New-Face {
    return [pscustomobject]@{
        Layer = ""
        X0 = $null; Y0 = $null; Z0 = $null
        X1 = $null; Y1 = $null; Z1 = $null
        X2 = $null; Y2 = $null; Z2 = $null
        X3 = $null; Y3 = $null; Z3 = $null
    }
}

function Test-FaceComplete {
    param($Face)

    return (
        $null -ne $Face.X0 -and $null -ne $Face.Y0 -and $null -ne $Face.Z0 -and
        $null -ne $Face.X1 -and $null -ne $Face.Y1 -and $null -ne $Face.Z1 -and
        $null -ne $Face.X2 -and $null -ne $Face.Y2 -and $null -ne $Face.Z2 -and
        $null -ne $Face.X3 -and $null -ne $Face.Y3 -and $null -ne $Face.Z3
    )
}

function Read-Dxf3DFaces {
    param(
        [string]$FilePath,
        [scriptblock]$OnFace,
        [int]$StopAfterFaces = 0
    )

    $reader = [System.IO.StreamReader]::new((Resolve-Path $FilePath).Path)
    $current = $null
    $facesSeen = 0
    $stop = $false

    function Flush-CurrentFace {
        if ($null -eq $script:current) { return }

        if (Test-FaceComplete $script:current) {
            $script:facesSeen++
            & $script:OnFace $script:current

            if ($script:StopAfterFaces -gt 0 -and $script:facesSeen -ge $script:StopAfterFaces) {
                $script:stop = $true
            }
        }

        $script:current = $null
    }

    try {
        while (-not $reader.EndOfStream) {
            $code = $reader.ReadLine()
            $value = $reader.ReadLine()
            if ($null -eq $code -or $null -eq $value) { break }

            $code = $code.Trim()
            $value = $value.Trim()

            if ($code -eq "0") {
                Flush-CurrentFace
                if ($stop) { break }

                if ($value -eq "3DFACE") {
                    $current = New-Face
                }
                continue
            }

            if ($null -eq $current) { continue }

            switch ($code) {
                "8"  { $current.Layer = $value }

                "10" { $current.X0 = Parse-DoubleInvariant $value }
                "20" { $current.Y0 = Parse-DoubleInvariant $value }
                "30" { $current.Z0 = Parse-DoubleInvariant $value }

                "11" { $current.X1 = Parse-DoubleInvariant $value }
                "21" { $current.Y1 = Parse-DoubleInvariant $value }
                "31" { $current.Z1 = Parse-DoubleInvariant $value }

                "12" { $current.X2 = Parse-DoubleInvariant $value }
                "22" { $current.Y2 = Parse-DoubleInvariant $value }
                "32" { $current.Z2 = Parse-DoubleInvariant $value }

                "13" { $current.X3 = Parse-DoubleInvariant $value }
                "23" { $current.Y3 = Parse-DoubleInvariant $value }
                "33" { $current.Z3 = Parse-DoubleInvariant $value }
            }
        }

        Flush-CurrentFace
    }
    finally {
        $reader.Close()
    }
}

if (-not (Test-Path $Path)) {
    throw "DXF file not found: $Path"
}

# -------------------------------------------------------------------
# PASS 1: global bounds and automatic center
# -------------------------------------------------------------------
$GlobalMinX = [double]::PositiveInfinity
$GlobalMinY = [double]::PositiveInfinity
$GlobalMinZ = [double]::PositiveInfinity
$GlobalMaxX = [double]::NegativeInfinity
$GlobalMaxY = [double]::NegativeInfinity
$GlobalMaxZ = [double]::NegativeInfinity
$GlobalFaceCount = 0

Read-Dxf3DFaces -FilePath $Path -OnFace {
    param($face)

    $script:GlobalFaceCount++

    foreach ($x in @($face.X0, $face.X1, $face.X2, $face.X3)) {
        if ($x -lt $script:GlobalMinX) { $script:GlobalMinX = $x }
        if ($x -gt $script:GlobalMaxX) { $script:GlobalMaxX = $x }
    }
    foreach ($y in @($face.Y0, $face.Y1, $face.Y2, $face.Y3)) {
        if ($y -lt $script:GlobalMinY) { $script:GlobalMinY = $y }
        if ($y -gt $script:GlobalMaxY) { $script:GlobalMaxY = $y }
    }
    foreach ($z in @($face.Z0, $face.Z1, $face.Z2, $face.Z3)) {
        if ($z -lt $script:GlobalMinZ) { $script:GlobalMinZ = $z }
        if ($z -gt $script:GlobalMaxZ) { $script:GlobalMaxZ = $z }
    }
}

if ($GlobalFaceCount -eq 0) {
    throw "No 3DFACE found in DXF."
}

if ($CenterX -eq "") {
    $TileCenterX = ($GlobalMinX + $GlobalMaxX) / 2.0
}
else {
    $TileCenterX = Parse-DoubleInvariant $CenterX
}

if ($CenterY -eq "") {
    $TileCenterY = ($GlobalMinY + $GlobalMaxY) / 2.0
}
else {
    $TileCenterY = Parse-DoubleInvariant $CenterY
}

$HalfWidth = $Width / 2.0
$HalfDepth = $Depth / 2.0
$TileMinX = $TileCenterX - $HalfWidth
$TileMaxX = $TileCenterX + $HalfWidth
$TileMinY = $TileCenterY - $HalfDepth
$TileMaxY = $TileCenterY + $HalfDepth

Write-Host "=== PASS 1 / GLOBAL DXF CENTER ==="
Write-Host "Faces scanned: $GlobalFaceCount"
Write-Host ("Auto center: X={0} Y={1}" -f (Format-Float $TileCenterX), (Format-Float $TileCenterY))
Write-Host ("Bounds XY: min({0}, {1}) max({2}, {3})" -f (Format-Float $GlobalMinX), (Format-Float $GlobalMinY), (Format-Float $GlobalMaxX), (Format-Float $GlobalMaxY))

# -------------------------------------------------------------------
# PASS 2: select tile faces by centroid
# -------------------------------------------------------------------
$SelectedFaces = New-Object System.Collections.Generic.List[object]
$TileMinZ = [double]::PositiveInfinity
$TileMaxZ = [double]::NegativeInfinity
$ScannedForTile = 0

Write-Host ""
Write-Host "=== PASS 2 / TILE EXTRACTION ==="
Write-Host ("Window: center({0}, {1}) width={2} depth={3}" -f (Format-Float $TileCenterX), (Format-Float $TileCenterY), (Format-Float $Width), (Format-Float $Depth))

Read-Dxf3DFaces -FilePath $Path -OnFace {
    param($face)

    $script:ScannedForTile++

    $cx = ($face.X0 + $face.X1 + $face.X2 + $face.X3) / 4.0
    $cy = ($face.Y0 + $face.Y1 + $face.Y2 + $face.Y3) / 4.0

    if ($cx -lt $script:TileMinX -or $cx -gt $script:TileMaxX) { return }
    if ($cy -lt $script:TileMinY -or $cy -gt $script:TileMaxY) { return }

    $script:SelectedFaces.Add($face)

    foreach ($z in @($face.Z0, $face.Z1, $face.Z2, $face.Z3)) {
        if ($z -lt $script:TileMinZ) { $script:TileMinZ = $z }
        if ($z -gt $script:TileMaxZ) { $script:TileMaxZ = $z }
    }
} -StopAfterFaces 0

if ($SelectedFaces.Count -gt $MaxFaces) {
    $trimmed = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $MaxFaces; $i++) {
        $trimmed.Add($SelectedFaces[$i])
    }
    $SelectedFaces = $trimmed
}

if ($SelectedFaces.Count -eq 0) {
    throw "No faces selected in tile. Try a bigger Width/Depth or explicit CenterX/CenterY."
}

# Recompute tile vertical bounds after optional trim
$TileMinZ = [double]::PositiveInfinity
$TileMaxZ = [double]::NegativeInfinity
foreach ($face in $SelectedFaces) {
    foreach ($z in @($face.Z0, $face.Z1, $face.Z2, $face.Z3)) {
        if ($z -lt $TileMinZ) { $TileMinZ = $z }
        if ($z -gt $TileMaxZ) { $TileMaxZ = $z }
    }
}

$OutputDir = Split-Path $OutputPath
if ($OutputDir) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$writer = [System.IO.StreamWriter]::new($OutputPath, $false, [System.Text.Encoding]::ASCII)
$vertexIndex = 1
$triangleCount = 0

try {
    $writer.WriteLine("# Montpellier Game DXF tile OBJ")
    $writer.WriteLine("# Source: $Path")
    $writer.WriteLine("# Selected faces: $($SelectedFaces.Count)")
    $writer.WriteLine("# Transform: Lambert X/Y -> game X/Z, altitude Z -> game Y")
    $writer.WriteLine(("# Tile center: {0} {1}" -f (Format-Float $TileCenterX), (Format-Float $TileCenterY)))
    $writer.WriteLine(("# Tile size: {0} {1}" -f (Format-Float $Width), (Format-Float $Depth)))

    foreach ($face in $SelectedFaces) {
        $points = @(
            @($face.X0, $face.Y0, $face.Z0),
            @($face.X1, $face.Y1, $face.Z1),
            @($face.X2, $face.Y2, $face.Z2),
            @($face.X3, $face.Y3, $face.Z3)
        )

        $indices = @()

        foreach ($p in $points) {
            $gx = [double]$p[0] - $TileCenterX
            $gy = [double]$p[2] - $TileMinZ
            $gz = [double]$p[1] - $TileCenterY

            $writer.WriteLine("v $(Format-Float $gx) $(Format-Float $gy) $(Format-Float $gz)")
            $indices += $vertexIndex
            $vertexIndex++
        }

        $same34 = (
            [Math]::Abs($face.X2 - $face.X3) -lt 0.0001 -and
            [Math]::Abs($face.Y2 - $face.Y3) -lt 0.0001 -and
            [Math]::Abs($face.Z2 - $face.Z3) -lt 0.0001
        )

        $writer.WriteLine("f $($indices[0]) $($indices[1]) $($indices[2])")
        $triangleCount++

        if (-not $same34) {
            $writer.WriteLine("f $($indices[0]) $($indices[2]) $($indices[3])")
            $triangleCount++
        }
    }
}
finally {
    $writer.Close()
}

Write-Host "Selected faces: $($SelectedFaces.Count)"
Write-Host "Output: $OutputPath"
Write-Host "Vertices: $($vertexIndex - 1)"
Write-Host "Triangles: $triangleCount"
Write-Host ("Tile Z bounds: min={0} max={1}" -f (Format-Float $TileMinZ), (Format-Float $TileMaxZ))
