param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MaxFaces = 0
)

$ErrorActionPreference = "Stop"
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function Parse-DoubleInvariant {
    param([string]$Text)
    return [double]::Parse($Text.Replace(",", "."), $InvariantCulture)
}

if (-not (Test-Path $Path)) {
    throw "Fichier DXF introuvable : $Path"
}

$LayerCounts = @{}

$MinX = [double]::PositiveInfinity
$MinY = [double]::PositiveInfinity
$MinZ = [double]::PositiveInfinity
$MaxX = [double]::NegativeInfinity
$MaxY = [double]::NegativeInfinity
$MaxZ = [double]::NegativeInfinity

$FaceCount = 0
$PairCount = 0

function Update-Bounds {
    param([double]$X, [double]$Y, [double]$Z)

    if ($X -lt $script:MinX) { $script:MinX = $X }
    if ($Y -lt $script:MinY) { $script:MinY = $Y }
    if ($Z -lt $script:MinZ) { $script:MinZ = $Z }

    if ($X -gt $script:MaxX) { $script:MaxX = $X }
    if ($Y -gt $script:MaxY) { $script:MaxY = $Y }
    if ($Z -gt $script:MaxZ) { $script:MaxZ = $Z }
}

$reader = [System.IO.StreamReader]::new((Resolve-Path $Path).Path)
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

    $script:FaceCount++

    $layer = $script:current.Layer
    if (-not $layer) { $layer = "<sans_layer>" }

    if (-not $script:LayerCounts.ContainsKey($layer)) {
        $script:LayerCounts[$layer] = 0
    }
    $script:LayerCounts[$layer]++

    foreach ($p in $script:current.Points) {
        if ($null -ne $p[0] -and $null -ne $p[1] -and $null -ne $p[2]) {
            Update-Bounds -X $p[0] -Y $p[1] -Z $p[2]
        }
    }

    $script:current = $null
}

try {
    while (-not $reader.EndOfStream) {
        $code = $reader.ReadLine()
        $value = $reader.ReadLine()
        if ($null -eq $code -or $null -eq $value) { break }

        $PairCount++

        $code = $code.Trim()
        $value = $value.Trim()

        if ($code -eq "0") {
            Flush-Face

            if ($MaxFaces -gt 0 -and $FaceCount -ge $MaxFaces) {
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

Write-Host "=== DXF INSPECT ==="
Write-Host "Fichier : $Path"
Write-Host "Paires lues : $PairCount"
Write-Host "Faces 3D : $FaceCount"

if ($FaceCount -gt 0) {
    Write-Host ("Bounds source: min({0:0.###}, {1:0.###}, {2:0.###}) max({3:0.###}, {4:0.###}, {5:0.###})" -f $MinX, $MinY, $MinZ, $MaxX, $MaxY, $MaxZ)
}

Write-Host ""
Write-Host "=== COUCHES ==="
$LayerCounts.GetEnumerator() |
    Sort-Object Value -Descending |
    ForEach-Object {
        "{0,8}  {1}" -f $_.Value, $_.Key
    }
