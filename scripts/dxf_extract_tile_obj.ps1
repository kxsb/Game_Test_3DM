param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath = "assets/models/dxf_tile.obj",

    [double]$Width = 250,

    [double]$Depth = 250,

    [int]$MaxFaces = 50000,

    [double]$GroundCellSize = 6.0,

    [double]$CenterX = [double]::NaN,

    [double]$CenterY = [double]::NaN
)

$ErrorActionPreference = "Stop"
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function Parse-DoubleInvariant {
    param([string]$Text)

    return [double]::Parse(
        $Text.Replace(",", "."),
        [System.Globalization.NumberStyles]::Float,
        $InvariantCulture
    )
}

function Format-Float {
    param([double]$Value)

    return $Value.ToString("0.###", $InvariantCulture)
}

function Min4 {
    param([double]$A, [double]$B, [double]$C, [double]$D)

    return [Math]::Min([Math]::Min($A, $B), [Math]::Min($C, $D))
}

function Max4 {
    param([double]$A, [double]$B, [double]$C, [double]$D)

    return [Math]::Max([Math]::Max($A, $B), [Math]::Max($C, $D))
}

function New-DxfFace {
    return [pscustomobject]@{
        Layer = ""

        X0 = $null
        Y0 = $null
        Z0 = $null

        X1 = $null
        Y1 = $null
        Z1 = $null

        X2 = $null
        Y2 = $null
        Z2 = $null

        X3 = $null
        Y3 = $null
        Z3 = $null
    }
}

function Complete-DxfFace {
    param($Face)

    if ($null -eq $Face) {
        return $false
    }

    $required = @(
        $Face.X0, $Face.Y0, $Face.Z0,
        $Face.X1, $Face.Y1, $Face.Z1,
        $Face.X2, $Face.Y2, $Face.Z2
    )

    foreach ($value in $required) {
        if ($null -eq $value) {
            return $false
        }
    }

    if ($null -eq $Face.X3) { $Face.X3 = $Face.X2 }
    if ($null -eq $Face.Y3) { $Face.Y3 = $Face.Y2 }
    if ($null -eq $Face.Z3) { $Face.Z3 = $Face.Z2 }

    return $true
}

function Invoke-DxfFaces {
    param(
        [string]$FilePath,
        [scriptblock]$OnFace
    )

    $reader = [System.IO.StreamReader]::new((Resolve-Path $FilePath).Path)
    $currentFace = $null

    try {
        while (-not $reader.EndOfStream) {
            $code = $reader.ReadLine()
            $value = $reader.ReadLine()

            if ($null -eq $code -or $null -eq $value) {
                break
            }

            $code = $code.Trim()
            $value = $value.Trim()

            if ($code -eq "0") {
                if (Complete-DxfFace $currentFace) {
                    & $OnFace $currentFace
                }

                if ($value -eq "3DFACE") {
                    $currentFace = New-DxfFace
                }
                else {
                    $currentFace = $null
                }

                continue
            }

            if ($null -eq $currentFace) {
                continue
            }

            switch ($code) {
                "8"  { $currentFace.Layer = $value }

                "10" { $currentFace.X0 = Parse-DoubleInvariant $value }
                "20" { $currentFace.Y0 = Parse-DoubleInvariant $value }
                "30" { $currentFace.Z0 = Parse-DoubleInvariant $value }

                "11" { $currentFace.X1 = Parse-DoubleInvariant $value }
                "21" { $currentFace.Y1 = Parse-DoubleInvariant $value }
                "31" { $currentFace.Z1 = Parse-DoubleInvariant $value }

                "12" { $currentFace.X2 = Parse-DoubleInvariant $value }
                "22" { $currentFace.Y2 = Parse-DoubleInvariant $value }
                "32" { $currentFace.Z2 = Parse-DoubleInvariant $value }

                "13" { $currentFace.X3 = Parse-DoubleInvariant $value }
                "23" { $currentFace.Y3 = Parse-DoubleInvariant $value }
                "33" { $currentFace.Z3 = Parse-DoubleInvariant $value }
            }
        }

        if (Complete-DxfFace $currentFace) {
            & $OnFace $currentFace
        }
    }
    finally {
        $reader.Close()
    }
}

function Update-GlobalBounds {
    param($Face)

    $faceMinX = Min4 $Face.X0 $Face.X1 $Face.X2 $Face.X3
    $faceMaxX = Max4 $Face.X0 $Face.X1 $Face.X2 $Face.X3

    $faceMinY = Min4 $Face.Y0 $Face.Y1 $Face.Y2 $Face.Y3
    $faceMaxY = Max4 $Face.Y0 $Face.Y1 $Face.Y2 $Face.Y3

    $faceMinZ = Min4 $Face.Z0 $Face.Z1 $Face.Z2 $Face.Z3
    $faceMaxZ = Max4 $Face.Z0 $Face.Z1 $Face.Z2 $Face.Z3

    if ($faceMinX -lt $script:GlobalMinX) { $script:GlobalMinX = $faceMinX }
    if ($faceMaxX -gt $script:GlobalMaxX) { $script:GlobalMaxX = $faceMaxX }

    if ($faceMinY -lt $script:GlobalMinY) { $script:GlobalMinY = $faceMinY }
    if ($faceMaxY -gt $script:GlobalMaxY) { $script:GlobalMaxY = $faceMaxY }

    if ($faceMinZ -lt $script:GlobalMinZ) { $script:GlobalMinZ = $faceMinZ }
    if ($faceMaxZ -gt $script:GlobalMaxZ) { $script:GlobalMaxZ = $faceMaxZ }
}

function Update-SelectedBounds {
    param($Face)

    $faceMinX = Min4 $Face.X0 $Face.X1 $Face.X2 $Face.X3
    $faceMaxX = Max4 $Face.X0 $Face.X1 $Face.X2 $Face.X3

    $faceMinY = Min4 $Face.Y0 $Face.Y1 $Face.Y2 $Face.Y3
    $faceMaxY = Max4 $Face.Y0 $Face.Y1 $Face.Y2 $Face.Y3

    $faceMinZ = Min4 $Face.Z0 $Face.Z1 $Face.Z2 $Face.Z3
    $faceMaxZ = Max4 $Face.Z0 $Face.Z1 $Face.Z2 $Face.Z3

    if ($faceMinX -lt $script:SelectedMinX) { $script:SelectedMinX = $faceMinX }
    if ($faceMaxX -gt $script:SelectedMaxX) { $script:SelectedMaxX = $faceMaxX }

    if ($faceMinY -lt $script:SelectedMinY) { $script:SelectedMinY = $faceMinY }
    if ($faceMaxY -gt $script:SelectedMaxY) { $script:SelectedMaxY = $faceMaxY }

    if ($faceMinZ -lt $script:SelectedMinZ) { $script:SelectedMinZ = $faceMinZ }
    if ($faceMaxZ -gt $script:SelectedMaxZ) { $script:SelectedMaxZ = $faceMaxZ }
}

function Face-Intersects-Tile {
    param(
        $Face,
        [double]$TileMinX,
        [double]$TileMaxX,
        [double]$TileMinY,
        [double]$TileMaxY
    )

    $faceMinX = Min4 $Face.X0 $Face.X1 $Face.X2 $Face.X3
    $faceMaxX = Max4 $Face.X0 $Face.X1 $Face.X2 $Face.X3

    $faceMinY = Min4 $Face.Y0 $Face.Y1 $Face.Y2 $Face.Y3
    $faceMaxY = Max4 $Face.Y0 $Face.Y1 $Face.Y2 $Face.Y3

    if ($faceMaxX -lt $TileMinX) { return $false }
    if ($faceMinX -gt $TileMaxX) { return $false }
    if ($faceMaxY -lt $TileMinY) { return $false }
    if ($faceMinY -gt $TileMaxY) { return $false }

    return $true
}

function Add-ObjVertex {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [double]$SourceX,
        [double]$SourceY,
        [double]$SourceZ,
        [double]$OriginX,
        [double]$OriginY,
        [double]$GroundZ
    )

    $gameX = $SourceX - $OriginX
    $gameY = $SourceZ - $GroundZ
    $gameZ = $SourceY - $OriginY

    $Lines.Add("v $(Format-Float $gameX) $(Format-Float $gameY) $(Format-Float $gameZ)")
}

if (-not (Test-Path $Path)) {
    throw "DXF file not found: $Path"
}

$ResolvedPath = (Resolve-Path $Path).Path

$script:GlobalFaceCount = 0
$script:GlobalMinX = [double]::PositiveInfinity
$script:GlobalMinY = [double]::PositiveInfinity
$script:GlobalMinZ = [double]::PositiveInfinity
$script:GlobalMaxX = [double]::NegativeInfinity
$script:GlobalMaxY = [double]::NegativeInfinity
$script:GlobalMaxZ = [double]::NegativeInfinity

Write-Host "=== PASS 1 / GLOBAL DXF BOUNDS ==="

Invoke-DxfFaces -FilePath $ResolvedPath -OnFace {
    param($Face)

    $script:GlobalFaceCount++
    Update-GlobalBounds $Face
}

if ($GlobalFaceCount -eq 0) {
    throw "No 3DFACE entity found in DXF."
}

if ([double]::IsNaN($CenterX)) {
    $CenterX = ($GlobalMinX + $GlobalMaxX) / 2.0
}

if ([double]::IsNaN($CenterY)) {
    $CenterY = ($GlobalMinY + $GlobalMaxY) / 2.0
}

Write-Host "Faces found : $GlobalFaceCount"
Write-Host ("Auto center : X={0} Y={1}" -f (Format-Float $CenterX), (Format-Float $CenterY))
Write-Host ("Source bounds XY : min({0}, {1}) max({2}, {3})" -f (Format-Float $GlobalMinX), (Format-Float $GlobalMinY), (Format-Float $GlobalMaxX), (Format-Float $GlobalMaxY))

$tileMinX = $CenterX - ($Width / 2.0)
$tileMaxX = $CenterX + ($Width / 2.0)
$tileMinY = $CenterY - ($Depth / 2.0)
$tileMaxY = $CenterY + ($Depth / 2.0)

Write-Host ""
Write-Host "=== PASS 2 / TILE EXTRACTION ==="
Write-Host ("Tile center : X={0} Y={1}" -f (Format-Float $CenterX), (Format-Float $CenterY))
Write-Host ("Tile size : width={0} depth={1}" -f (Format-Float $Width), (Format-Float $Depth))
Write-Host ("Tile bounds : min({0}, {1}) max({2}, {3})" -f (Format-Float $tileMinX), (Format-Float $tileMinY), (Format-Float $tileMaxX), (Format-Float $tileMaxY))

$selectedFaces = New-Object System.Collections.Generic.List[object]

$script:SelectedMinX = [double]::PositiveInfinity
$script:SelectedMinY = [double]::PositiveInfinity
$script:SelectedMinZ = [double]::PositiveInfinity
$script:SelectedMaxX = [double]::NegativeInfinity
$script:SelectedMaxY = [double]::NegativeInfinity
$script:SelectedMaxZ = [double]::NegativeInfinity

Invoke-DxfFaces -FilePath $ResolvedPath -OnFace {
    param($Face)

    if ($script:selectedFaces.Count -ge $MaxFaces) {
        return
    }

    if (Face-Intersects-Tile $Face $tileMinX $tileMaxX $tileMinY $tileMaxY) {
        $script:selectedFaces.Add($Face)
        Update-SelectedBounds $Face
    }
}

if ($selectedFaces.Count -eq 0) {
    Write-Host ""
    Write-Host "No face selected in this tile."
    Write-Host "Try a larger tile, for example Width=500 Depth=500."
    throw "No selected face in tile."
}

$OutputDir = Split-Path $OutputPath
if ($OutputDir) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$groundZ = $SelectedMinZ

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Montpellier Game DXF tile OBJ")
$lines.Add("# Source: $ResolvedPath")
$lines.Add("# Selected faces: $($selectedFaces.Count)")
$lines.Add("# Transform: Lambert X/Y -> game X/Z, DXF altitude Z -> game Y")
$lines.Add("# Tile center X/Y: $(Format-Float $CenterX) $(Format-Float $CenterY)")
$lines.Add("# Tile size W/D: $(Format-Float $Width) $(Format-Float $Depth)")
$lines.Add("o dxf_tile")

$vertexIndex = 1
$triangleCount = 0

foreach ($face in $selectedFaces) {
    $i0 = $vertexIndex
    Add-ObjVertex $lines $face.X0 $face.Y0 $face.Z0 $CenterX $CenterY $groundZ
    $vertexIndex++

    $i1 = $vertexIndex
    Add-ObjVertex $lines $face.X1 $face.Y1 $face.Z1 $CenterX $CenterY $groundZ
    $vertexIndex++

    $i2 = $vertexIndex
    Add-ObjVertex $lines $face.X2 $face.Y2 $face.Z2 $CenterX $CenterY $groundZ
    $vertexIndex++

    $i3 = $vertexIndex
    Add-ObjVertex $lines $face.X3 $face.Y3 $face.Z3 $CenterX $CenterY $groundZ
    $vertexIndex++

    $same34 = (
        [Math]::Abs($face.X2 - $face.X3) -lt 0.0001 -and
        [Math]::Abs($face.Y2 - $face.Y3) -lt 0.0001 -and
        [Math]::Abs($face.Z2 - $face.Z3) -lt 0.0001
    )

    $lines.Add("f $i0 $i1 $i2")
    $triangleCount++

    if (-not $same34) {
        $lines.Add("f $i0 $i2 $i3")
        $triangleCount++
    }
}

Set-Content -Path $OutputPath -Value $lines -Encoding ASCII

$GroundOutputPath = [System.IO.Path]::ChangeExtension($OutputPath, ".ground.txt")
$GroundMinX = -($Width / 2.0)
$GroundMinZ = -($Depth / 2.0)
$GroundWidthCells = [Math]::Max(1, [int][Math]::Ceiling($Width / $GroundCellSize))
$GroundDepthCells = [Math]::Max(1, [int][Math]::Ceiling($Depth / $GroundCellSize))

# On ne dispose pas d'un vrai fichier "voirie / terrain".
# Le DXF actuel est principalement un fichier bâtiments.
# Donc on reconstruit un sol indicatif à partir des points bas des façades.
$GroundMaxBaseHeightAboveMin = 20.0
$GroundBaseVertexTolerance = 0.35
$GroundGenerationMode = "base_vertices"

$script:GroundSamples = @{}

function Add-GroundSample {
    param(
        [double]$SourceX,
        [double]$SourceY,
        [double]$SourceZ
    )

    $gameX = $SourceX - $CenterX
    $gameY = $SourceZ - $groundZ
    $gameZ = $SourceY - $CenterY

    if ($gameY -lt -0.50) { return }
    if ($gameY -gt $GroundMaxBaseHeightAboveMin) { return }

    $ix = [int][Math]::Floor(($gameX - $GroundMinX) / $GroundCellSize)
    $iz = [int][Math]::Floor(($gameZ - $GroundMinZ) / $GroundCellSize)

    if ($ix -lt 0 -or $ix -ge $GroundWidthCells -or $iz -lt 0 -or $iz -ge $GroundDepthCells) {
        return
    }

    $key = "$ix,$iz"

    if (-not $script:GroundSamples.ContainsKey($key)) {
        $script:GroundSamples[$key] = New-Object System.Collections.Generic.List[double]
    }

    $script:GroundSamples[$key].Add($gameY)
}

function Add-Face-Low-Vertices-To-Ground {
    param($Face)

    $faceMinAlt = Min4 $Face.Z0 $Face.Z1 $Face.Z2 $Face.Z3
    $faceMaxAlt = Max4 $Face.Z0 $Face.Z1 $Face.Z2 $Face.Z3
    $faceMinGameY = $faceMinAlt - $groundZ
    $verticalSpread = $faceMaxAlt - $faceMinAlt

    if ($faceMinGameY -lt -0.50) { return }
    if ($faceMinGameY -gt $GroundMaxBaseHeightAboveMin) { return }

    # 1) On récupère les vertices proches du bas de la face.
    # Pour une façade verticale, ce sont généralement les deux points de pied.
    if ([Math]::Abs($Face.Z0 - $faceMinAlt) -le $GroundBaseVertexTolerance) {
        Add-GroundSample $Face.X0 $Face.Y0 $Face.Z0
    }

    if ([Math]::Abs($Face.Z1 - $faceMinAlt) -le $GroundBaseVertexTolerance) {
        Add-GroundSample $Face.X1 $Face.Y1 $Face.Z1
    }

    if ([Math]::Abs($Face.Z2 - $faceMinAlt) -le $GroundBaseVertexTolerance) {
        Add-GroundSample $Face.X2 $Face.Y2 $Face.Z2
    }

    if ([Math]::Abs($Face.Z3 - $faceMinAlt) -le $GroundBaseVertexTolerance) {
        Add-GroundSample $Face.X3 $Face.Y3 $Face.Z3
    }

    # 2) Si la face est déjà basse et presque plane, on ajoute aussi le centre.
    if ($verticalSpread -le 0.90) {
        $cx = ($Face.X0 + $Face.X1 + $Face.X2 + $Face.X3) / 4.0
        $cy = ($Face.Y0 + $Face.Y1 + $Face.Y2 + $Face.Y3) / 4.0
        $cz = ($Face.Z0 + $Face.Z1 + $Face.Z2 + $Face.Z3) / 4.0
        Add-GroundSample $cx $cy $cz
    }
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

foreach ($face in $selectedFaces) {
    Add-Face-Low-Vertices-To-Ground $face
}

# Si le DXF ne fournit vraiment aucun indice exploitable,
# on génère un sol plat explicite plutôt qu'un sidecar vide.
if ($script:GroundSamples.Count -eq 0) {
    $GroundGenerationMode = "synthetic_flat_fallback"

    for ($iz = 0; $iz -lt $GroundDepthCells; $iz++) {
        for ($ix = 0; $ix -lt $GroundWidthCells; $ix++) {
            $key = "$ix,$iz"
            $script:GroundSamples[$key] = New-Object System.Collections.Generic.List[double]
            $script:GroundSamples[$key].Add(0.0)
        }
    }
}

$groundLines = New-Object System.Collections.Generic.List[string]
$groundLines.Add("# Montpellier Game ground sidecar generated from DXF tile")
$groundLines.Add("# Format:")
$groundLines.Add("# grid minX minZ cellSize width depth fallbackY")
$groundLines.Add("# cell ix iz height sampleCount")
$groundLines.Add("# Source: $ResolvedPath")
$groundLines.Add("# OBJ: $OutputPath")
$groundLines.Add("# Mode: $GroundGenerationMode")
$groundLines.Add("grid $(Format-Float $GroundMinX) $(Format-Float $GroundMinZ) $(Format-Float $GroundCellSize) $GroundWidthCells $GroundDepthCells 0")

foreach ($key in ($script:GroundSamples.Keys | Sort-Object)) {
    $parts = $key.Split(",")
    $values = $script:GroundSamples[$key]

    if ($values.Count -eq 0) {
        continue
    }

    $height = Select-GroundHeight $values
    $groundLines.Add("cell $($parts[0]) $($parts[1]) $(Format-Float $height) $($values.Count)")
}

Set-Content -Path $GroundOutputPath -Value $groundLines -Encoding ASCII

Write-Host ""
Write-Host "=== DXF TILE OBJ ==="
Write-Host "Output : $OutputPath"
Write-Host "Ground sidecar : $GroundOutputPath"
Write-Host "Ground sampled cells : $($script:GroundSamples.Count)"
Write-Host "Ground mode : $GroundGenerationMode"
Write-Host "Selected faces : $($selectedFaces.Count)"
Write-Host "Vertices : $($vertexIndex - 1)"
Write-Host "Triangles : $triangleCount"
Write-Host ("Selected bounds XYZ : min({0}, {1}, {2}) max({3}, {4}, {5})" -f `
    (Format-Float $SelectedMinX), `
    (Format-Float $SelectedMinY), `
    (Format-Float $SelectedMinZ), `
    (Format-Float $SelectedMaxX), `
    (Format-Float $SelectedMaxY), `
    (Format-Float $SelectedMaxZ)
)

