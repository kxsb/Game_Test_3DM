param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath = "assets/models/dxf_sample.obj",

    [int]$MaxFaces = 5000
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

if (-not (Test-Path $Path)) {
    throw "Fichier DXF introuvable : $Path"
}

$faces = New-Object System.Collections.Generic.List[object]
$current = $null

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

function Flush-Face {
    if ($null -eq $script:current) { return }

    $complete = $true
    foreach ($p in $script:current.Points) {
        if ($null -eq $p[0] -or $null -eq $p[1] -or $null -eq $p[2]) {
            $complete = $false
        }
    }

    if ($complete) {
        $script:faces.Add($script:current)
    }

    $script:current = $null
}

$reader = [System.IO.StreamReader]::new((Resolve-Path $Path).Path)

try {
    while (-not $reader.EndOfStream) {
        $code = $reader.ReadLine()
        $value = $reader.ReadLine()
        if ($null -eq $code -or $null -eq $value) { break }

        $code = $code.Trim()
        $value = $value.Trim()

        if ($code -eq "0") {
            Flush-Face

            if ($faces.Count -ge $MaxFaces) {
                break
            }

            if ($value -eq "3DFACE") {
                $current = New-FaceEntity
            }

            continue
        }

        if ($null -eq $current) { continue }

        switch ($code) {
            "8"  { $current.Layer = $value }

            "10" { $current.Points[0][0] = Parse-DoubleInvariant $value }
            "20" { $current.Points[0][1] = Parse-DoubleInvariant $value }
            "30" { $current.Points[0][2] = Parse-DoubleInvariant $value }

            "11" { $current.Points[1][0] = Parse-DoubleInvariant $value }
            "21" { $current.Points[1][1] = Parse-DoubleInvariant $value }
            "31" { $current.Points[1][2] = Parse-DoubleInvariant $value }

            "12" { $current.Points[2][0] = Parse-DoubleInvariant $value }
            "22" { $current.Points[2][1] = Parse-DoubleInvariant $value }
            "32" { $current.Points[2][2] = Parse-DoubleInvariant $value }

            "13" { $current.Points[3][0] = Parse-DoubleInvariant $value }
            "23" { $current.Points[3][1] = Parse-DoubleInvariant $value }
            "33" { $current.Points[3][2] = Parse-DoubleInvariant $value }
        }
    }

    Flush-Face
}
finally {
    $reader.Close()
}

if ($faces.Count -eq 0) {
    throw "Aucune 3DFACE extraite."
}

$MinX = [double]::PositiveInfinity
$MinY = [double]::PositiveInfinity
$MinZ = [double]::PositiveInfinity
$MaxX = [double]::NegativeInfinity
$MaxY = [double]::NegativeInfinity
$MaxZ = [double]::NegativeInfinity

foreach ($face in $faces) {
    foreach ($p in $face.Points) {
        if ($p[0] -lt $MinX) { $MinX = $p[0] }
        if ($p[1] -lt $MinY) { $MinY = $p[1] }
        if ($p[2] -lt $MinZ) { $MinZ = $p[2] }

        if ($p[0] -gt $MaxX) { $MaxX = $p[0] }
        if ($p[1] -gt $MaxY) { $MaxY = $p[1] }
        if ($p[2] -gt $MaxZ) { $MaxZ = $p[2] }
    }
}

$CenterX = ($MinX + $MaxX) / 2.0
$CenterY = ($MinY + $MaxY) / 2.0
$GroundZ = $MinZ

$OutputDir = Split-Path $OutputPath
if ($OutputDir) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Montpellier Game DXF sample OBJ")
$lines.Add("# Source: $Path")
$lines.Add("# Faces extracted: $($faces.Count)")
$lines.Add("# Transform: Lambert X/Y -> game X/Z, altitude Z -> game Y")

$vertexIndex = 1
$triangleCount = 0

foreach ($face in $faces) {
    $indices = @()

    foreach ($p in $face.Points) {
        $gx = $p[0] - $CenterX
        $gy = $p[2] - $GroundZ
        $gz = $p[1] - $CenterY

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

Write-Host "=== DXF SAMPLE OBJ ==="
Write-Host "Source : $Path"
Write-Host "Output : $OutputPath"
Write-Host "3DFACE extraites : $($faces.Count)"
Write-Host "Vertices : $($vertexIndex - 1)"
Write-Host "Triangles : $triangleCount"
Write-Host ("Bounds source: min({0:0.###}, {1:0.###}, {2:0.###}) max({3:0.###}, {4:0.###}, {5:0.###})" -f $MinX, $MinY, $MinZ, $MaxX, $MaxY, $MaxZ)
