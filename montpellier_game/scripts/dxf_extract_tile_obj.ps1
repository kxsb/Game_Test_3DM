param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath = "assets/models/dxf_tile.obj",

    [double]$CenterX = [double]::NaN,
    [double]$CenterY = [double]::NaN,

    [double]$Width = 250.0,
    [double]$Depth = 250.0,

    [int]$MaxFaces = 50000,

    [switch]$FullFileCenter
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

function New-FaceEntity {
    return [pscustomobject]@{
        Layer = ""
        Points = @(
            @($null, $null, $null),
            @($null, $null, $null),
            @($null, $null, $null),
            @($null, $null, $null)
        )
    }
}

function Test-FaceComplete {
    param($Face)

    if ($null -eq $Face) { return $false }

    foreach ($p in $Face.Points) {
        if ($null -eq $p[0] -or $null -eq $p[1] -or $null -eq $p[2]) {
            return $false
        }
    }

    return $true
}

function Get-FaceCentroidXY {
    param($Face)

    $x = 0.0
    $y = 0.0

    foreach ($p in $Face.Points) {
        $x += $p[0]
        $y += $p[1]
    }

    return @($x / 4.0, $y / 4.0)
}

function Read-DxfFaces {
    param(
        [string]$FilePath,
        [scriptblock]$OnFace
    )

    $reader = [System.IO.StreamReader]::new((Resolve-Path $FilePath).Path)
    $current = $null

    function Flush-LocalFace {
        if ($null -eq $script:current) { return }

        if (Test-FaceComplete $script:current) {
            & $OnFace $script:current
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
                Flush-LocalFace

                if ($value -eq "3DFACE") {
                    $script:current = New-FaceEntity
                }

                continue
            }

            if ($null -eq $script:current) { continue }

            switch ($code) {
                "8"  { $script:current.Layer = $value }

                "10" { $script:current.Points[0][0] = Parse-DoubleInvariant $value }
                "20" { $script:current.Points[0][1] = Parse-DoubleInvariant $value }
                "30" { $script:current.Points[0][2] = Parse-DoubleInvariant $value }

                "11" { $script:current.Points[1][0] = Parse-DoubleInvariant $value }
                "21" { $script:current.Points[1][1] = Parse-DoubleInvariant $value }
                "31" { $script:current.Points[1][2] = Parse-DoubleInvariant $value }

                "12" { $script:current.Points[2][0] = Parse-DoubleInvariant $value }
                "22" { $script:current.Points[2][1] = Parse-DoubleInvariant $value }
                "32" { $script:current.Points[2][2] = Parse-DoubleInvariant $value }

                "13" { $script:current.Points[3][0] = Parse-DoubleInvariant $value }
                "23" { $script:current.Points[3][1] = Parse-DoubleInvariant $value }
                "33" { $script:current.Points[3][2] = Parse-DoubleInvariant $value }
            }
        }

        Flush-LocalFace
    }
    finally {
        $reader.Close()
        $script:current = $null
    }
}

if (-not (Test-Path $Path)) {
    throw "Fichier DXF introuvable : $Path"
}

if ([double]::IsNaN($CenterX) -or [double]::IsNaN($CenterY) -or $FullFileCenter) {
    Write-Host "=== PASS 1 / CENTRE GLOBAL DXF ==="

    $minX = [double]::PositiveInfinity
    $minY = [double]::PositiveInfinity
    $maxX = [double]::NegativeInfinity
    $maxY = [double]::NegativeInfinity
    $faceCount = 0

    Read-DxfFaces -FilePath $Path -OnFace {
        param($Face)
        $script:faceCount++

        foreach ($p in $Face.Points) {
            if ($p[0] -lt $script:minX) { $script:minX = $p[0] }
            if ($p[1] -lt $script:minY) { $script:minY = $p[1] }
            if ($p[0] -gt $script:maxX) { $script:maxX = $p[0] }
            if ($p[1] -gt $script:maxY) { $script:maxY = $p[1] }
        }
    }

    $CenterX = ($minX + $maxX) / 2.0
    $CenterY = ($minY + $maxY) / 2.0

    Write-Host "Faces parcourues : $faceCount"
    Write-Host ("Centre auto : X={0:0.###} Y={1:0.###}" -f $CenterX, $CenterY)
    Write-Host ("Bounds XY : min({0:0.###}, {1:0.###}) max({2:0.###}, {3:0.###})" -f $minX, $minY, $maxX, $maxY)
}

Write-Host ""
Write-Host "=== PASS 2 / EXTRACTION TILE ==="
Write-Host ("Fenêtre : centre({0:0.###}, {1:0.###}) largeur={2:0.###} profondeur={3:0.###}" -f $CenterX, $CenterY, $Width, $Depth)

$halfW = $Width / 2.0
$halfD = $Depth / 2.0
$xMinWindow = $CenterX - $halfW
$xMaxWindow = $CenterX + $halfW
$yMinWindow = $CenterY - $halfD
$yMaxWindow = $CenterY + $halfD

$faces = New-Object System.Collections.Generic.List[object]
$seenFaces = 0

Read-DxfFaces -FilePath $Path -OnFace {
    param($Face)

    if ($script:faces.Count -ge $MaxFaces) {
        return
    }

    $script:seenFaces++
    $centroid = Get-FaceCentroidXY $Face
    $cx = $centroid[0]
    $cy = $centroid[1]

    if ($cx -ge $script:xMinWindow -and $cx -le $script:xMaxWindow -and $cy -ge $script:yMinWindow -and $cy -le $script:yMaxWindow) {
        $script:faces.Add($Face)
    }
}

if ($faces.Count -eq 0) {
    throw "Aucune face extraite dans la fenêtre. Essaie une largeur/profondeur plus grande ou un autre centre."
}

$minX2 = [double]::PositiveInfinity
$minY2 = [double]::PositiveInfinity
$minZ2 = [double]::PositiveInfinity
$maxX2 = [double]::NegativeInfinity
$maxY2 = [double]::NegativeInfinity
$maxZ2 = [double]::NegativeInfinity

foreach ($face in $faces) {
    foreach ($p in $face.Points) {
        if ($p[0] -lt $minX2) { $minX2 = $p[0] }
        if ($p[1] -lt $minY2) { $minY2 = $p[1] }
        if ($p[2] -lt $minZ2) { $minZ2 = $p[2] }
        if ($p[0] -gt $maxX2) { $maxX2 = $p[0] }
        if ($p[1] -gt $maxY2) { $maxY2 = $p[1] }
        if ($p[2] -gt $maxZ2) { $maxZ2 = $p[2] }
    }
}

$centerTileX = ($minX2 + $maxX2) / 2.0
$centerTileY = ($minY2 + $maxY2) / 2.0
$groundZ = $minZ2

$outputDir = Split-Path $OutputPath
if ($outputDir) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Montpellier Game DXF tile OBJ")
$lines.Add("# Source: $Path")
$lines.Add("# Faces extracted: $($faces.Count)")
$lines.Add("# Tile center Lambert: X=$(Format-Float $CenterX) Y=$(Format-Float $CenterY)")
$lines.Add("# Transform: Lambert X/Y -> game X/Z, altitude Z -> game Y")

$vertexIndex = 1
$triangleCount = 0

foreach ($face in $faces) {
    $indices = @()

    foreach ($p in $face.Points) {
        $gx = $p[0] - $centerTileX
        $gy = $p[2] - $groundZ
        $gz = $p[1] - $centerTileY

        $lines.Add("v $(Format-Float $gx) $(Format-Float $gy) $(Format-Float $gz)")
        $indices += $vertexIndex
        $vertexIndex++
    }

    $p2 = $face.Points[2]
    $p3 = $face.Points[3]

    $same34 = (
        [Math]::Abs($p2[0] - $p3[0]) -lt 0.0001 -and
        [Math]::Abs($p2[1] - $p3[1]) -lt 0.0001 -and
        [Math]::Abs($p2[2] - $p3[2]) -lt 0.0001
    )

    $lines.Add("f $($indices[0]) $($indices[1]) $($indices[2])")
    $triangleCount++

    if (-not $same34) {
        $lines.Add("f $($indices[0]) $($indices[2]) $($indices[3])")
        $triangleCount++
    }
}

Set-Content -Path $OutputPath -Value $lines -Encoding ASCII

Write-Host "=== DXF TILE OBJ ==="
Write-Host "Source : $Path"
Write-Host "Output : $OutputPath"
Write-Host "Faces retenues : $($faces.Count)"
Write-Host "Vertices : $($vertexIndex - 1)"
Write-Host "Triangles : $triangleCount"
Write-Host ("Bounds source selection: min({0:0.###}, {1:0.###}, {2:0.###}) max({3:0.###}, {4:0.###}, {5:0.###})" -f $minX2, $minY2, $minZ2, $maxX2, $maxY2, $maxZ2)
Write-Host ("Bounds jeu approx: largeur={0:0.###} profondeur={1:0.###} hauteur={2:0.###}" -f ($maxX2 - $minX2), ($maxY2 - $minY2), ($maxZ2 - $minZ2))
