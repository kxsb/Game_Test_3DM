param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$MaxFaces = 0
)

$ErrorActionPreference = "Stop"
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function ConvertTo-InvariantDouble {
    param([string]$Text)

    return [double]::Parse(
        $Text.Replace(",", "."),
        [System.Globalization.NumberStyles]::Float,
        $InvariantCulture
    )
}

function New-DxfFace {
    return [pscustomobject]@{
        Layer = ""

        X0 = $null; Y0 = $null; Z0 = $null
        X1 = $null; Y1 = $null; Z1 = $null
        X2 = $null; Y2 = $null; Z2 = $null
        X3 = $null; Y3 = $null; Z3 = $null
    }
}

function Test-CompleteFace {
    param($Face)

    if ($null -eq $Face) { return $false }

    $required = @(
        $Face.X0, $Face.Y0, $Face.Z0,
        $Face.X1, $Face.Y1, $Face.Z1,
        $Face.X2, $Face.Y2, $Face.Z2
    )

    foreach ($value in $required) {
        if ($null -eq $value) { return $false }
    }

    if ($null -eq $Face.X3) { $Face.X3 = $Face.X2 }
    if ($null -eq $Face.Y3) { $Face.Y3 = $Face.Y2 }
    if ($null -eq $Face.Z3) { $Face.Z3 = $Face.Z2 }

    return $true
}

function Get-Min4 {
    param([double]$A, [double]$B, [double]$C, [double]$D)
    return [Math]::Min([Math]::Min($A, $B), [Math]::Min($C, $D))
}

function Get-Max4 {
    param([double]$A, [double]$B, [double]$C, [double]$D)
    return [Math]::Max([Math]::Max($A, $B), [Math]::Max($C, $D))
}

function Update-LayerStats {
    param(
        [hashtable]$Stats,
        $Face
    )

    $layer = $Face.Layer
    if (-not $layer) { $layer = "<sans_layer>" }

    $minX = Get-Min4 $Face.X0 $Face.X1 $Face.X2 $Face.X3
    $maxX = Get-Max4 $Face.X0 $Face.X1 $Face.X2 $Face.X3

    $minY = Get-Min4 $Face.Y0 $Face.Y1 $Face.Y2 $Face.Y3
    $maxY = Get-Max4 $Face.Y0 $Face.Y1 $Face.Y2 $Face.Y3

    $minZ = Get-Min4 $Face.Z0 $Face.Z1 $Face.Z2 $Face.Z3
    $maxZ = Get-Max4 $Face.Z0 $Face.Z1 $Face.Z2 $Face.Z3

    $zRange = $maxZ - $minZ

    if (-not $Stats.ContainsKey($layer)) {
        $Stats[$layer] = [pscustomobject]@{
            Layer = $layer
            Count = 0

            MinX = [double]::PositiveInfinity
            MaxX = [double]::NegativeInfinity
            MinY = [double]::PositiveInfinity
            MaxY = [double]::NegativeInfinity
            MinZ = [double]::PositiveInfinity
            MaxZ = [double]::NegativeInfinity

            HorizontalLike = 0
            LowHorizontalLike = 0
            VerticalLike = 0
        }
    }

    $s = $Stats[$layer]
    $s.Count++

    if ($minX -lt $s.MinX) { $s.MinX = $minX }
    if ($maxX -gt $s.MaxX) { $s.MaxX = $maxX }

    if ($minY -lt $s.MinY) { $s.MinY = $minY }
    if ($maxY -gt $s.MaxY) { $s.MaxY = $maxY }

    if ($minZ -lt $s.MinZ) { $s.MinZ = $minZ }
    if ($maxZ -gt $s.MaxZ) { $s.MaxZ = $maxZ }

    if ($zRange -le 0.35) {
        $s.HorizontalLike++
    }

    if ($zRange -le 0.35 -and $maxZ -le 5.0) {
        $s.LowHorizontalLike++
    }

    if ($zRange -ge 1.8) {
        $s.VerticalLike++
    }
}

if (-not (Test-Path $Path)) {
    throw "DXF introuvable : $Path"
}

$resolved = (Resolve-Path $Path).Path

$stats = @{}
$totalFaces = 0
$current = $null

$reader = [System.IO.StreamReader]::new($resolved)

function Flush-Face {
    if (Test-CompleteFace $script:current) {
        $script:totalFaces++
        Update-LayerStats -Stats $script:stats -Face $script:current
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
            Flush-Face

            if ($MaxFaces -gt 0 -and $totalFaces -ge $MaxFaces) {
                break
            }

            if ($value -eq "3DFACE") {
                $current = New-DxfFace
            }
            else {
                $current = $null
            }

            continue
        }

        if ($null -eq $current) { continue }

        switch ($code) {
            "8"  { $current.Layer = $value }

            "10" { $current.X0 = ConvertTo-InvariantDouble $value }
            "20" { $current.Y0 = ConvertTo-InvariantDouble $value }
            "30" { $current.Z0 = ConvertTo-InvariantDouble $value }

            "11" { $current.X1 = ConvertTo-InvariantDouble $value }
            "21" { $current.Y1 = ConvertTo-InvariantDouble $value }
            "31" { $current.Z1 = ConvertTo-InvariantDouble $value }

            "12" { $current.X2 = ConvertTo-InvariantDouble $value }
            "22" { $current.Y2 = ConvertTo-InvariantDouble $value }
            "32" { $current.Z2 = ConvertTo-InvariantDouble $value }

            "13" { $current.X3 = ConvertTo-InvariantDouble $value }
            "23" { $current.Y3 = ConvertTo-InvariantDouble $value }
            "33" { $current.Z3 = ConvertTo-InvariantDouble $value }
        }
    }

    Flush-Face
}
finally {
    $reader.Close()
}

Write-Host "=== DXF GROUND AUDIT ==="
Write-Host "Fichier : $resolved"
Write-Host "Faces lues : $totalFaces"
Write-Host ""

Write-Host "=== COUCHES PAR VOLUME ==="
$stats.Values |
    Sort-Object Count -Descending |
    Select-Object `
        Layer,
        Count,
        HorizontalLike,
        LowHorizontalLike,
        VerticalLike,
        @{Name="MinZ"; Expression={ "{0:0.###}" -f $_.MinZ }},
        @{Name="MaxZ"; Expression={ "{0:0.###}" -f $_.MaxZ }} |
    Format-Table -AutoSize

Write-Host ""
Write-Host "=== CANDIDATES SOL / HORIZONTAL BAS ==="
$stats.Values |
    Where-Object { $_.LowHorizontalLike -gt 0 -or $_.Layer -match "sol|terrain|voirie|route|rue|dalle|ground|floor" } |
    Sort-Object LowHorizontalLike -Descending |
    Select-Object `
        Layer,
        Count,
        HorizontalLike,
        LowHorizontalLike,
        VerticalLike,
        @{Name="MinZ"; Expression={ "{0:0.###}" -f $_.MinZ }},
        @{Name="MaxZ"; Expression={ "{0:0.###}" -f $_.MaxZ }} |
    Format-Table -AutoSize
    