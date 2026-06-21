param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath = "",

    [double]$CellSize = 6.0,

    [double]$MinWallHeight = 1.8,

    [double]$MinColumnHeight = 1.5,

    [double]$ColumnPadding = 0.15,

    [double]$BaseVertexTolerance = 0.45,

    [double]$SegmentThickness = 0.35,

    [int]$MaxBoxes = 6000
)

$ErrorActionPreference = "Stop"
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function ConvertTo-InvariantFloat {
    param([double]$Value)

    return $Value.ToString("0.###", $InvariantCulture)
}

function ConvertTo-ObjIndex {
    param([string]$Token)

    $raw = ($Token -split "/")[0]
    return [int]::Parse($raw, $InvariantCulture)
}

function New-Vector3 {
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

function Get-Min3 {
    param([double]$A, [double]$B, [double]$C)

    return [Math]::Min([Math]::Min($A, $B), $C)
}

function Get-Max3 {
    param([double]$A, [double]$B, [double]$C)

    return [Math]::Max([Math]::Max($A, $B), $C)
}

function ConvertTo-KeyFloat {
    param([double]$Value)

    return ([Math]::Round($Value, 2)).ToString("0.##", $InvariantCulture)
}

function Get-SegmentKey {
    param(
        [object]$A,
        [object]$B
    )

    $aKey = "$(ConvertTo-KeyFloat $A.X),$(ConvertTo-KeyFloat $A.Z)"
    $bKey = "$(ConvertTo-KeyFloat $B.X),$(ConvertTo-KeyFloat $B.Z)"

    if ([string]::CompareOrdinal($aKey, $bKey) -le 0) {
        return "$aKey|$bKey"
    }

    return "$bKey|$aKey"
}

function Add-CollisionSegment {
    param(
        [hashtable]$Segments,
        [object]$A,
        [object]$B,
        [double]$MinY,
        [double]$MaxY
    )

    $dx = $B.X - $A.X
    $dz = $B.Z - $A.Z
    $length = [Math]::Sqrt(($dx * $dx) + ($dz * $dz))

    if ($length -lt 0.35) {
        return
    }

    $key = Get-SegmentKey -A $A -B $B

    if (-not $Segments.ContainsKey($key)) {
        $Segments[$key] = [pscustomobject]@{
            AX = $A.X
            AZ = $A.Z
            BX = $B.X
            BZ = $B.Z
            MinY = $MinY
            MaxY = $MaxY
            Count = 1
        }

        return
    }

    if ($MinY -lt $Segments[$key].MinY) {
        $Segments[$key].MinY = $MinY
    }

    if ($MaxY -gt $Segments[$key].MaxY) {
        $Segments[$key].MaxY = $MaxY
    }

    $Segments[$key].Count++
}

function Add-TriangleCollisionSegments {
    param(
        [object]$A,
        [object]$B,
        [object]$C,
        [hashtable]$Segments
    )

    $minY = Get-Min3 $A.Y $B.Y $C.Y
    $maxY = Get-Max3 $A.Y $B.Y $C.Y
    $height = $maxY - $minY

    if ($height -lt $MinWallHeight) {
        return
    }

    $script:ContributingTriangles++

    $lowVertices = New-Object System.Collections.Generic.List[object]

    if ([Math]::Abs($A.Y - $minY) -le $BaseVertexTolerance) {
        $lowVertices.Add($A)
    }

    if ([Math]::Abs($B.Y - $minY) -le $BaseVertexTolerance) {
        $lowVertices.Add($B)
    }

    if ([Math]::Abs($C.Y - $minY) -le $BaseVertexTolerance) {
        $lowVertices.Add($C)
    }

    if ($lowVertices.Count -lt 2) {
        return
    }

    for ($i = 0; $i -lt $lowVertices.Count; $i++) {
        for ($j = $i + 1; $j -lt $lowVertices.Count; $j++) {
            Add-CollisionSegment `
                -Segments $Segments `
                -A $lowVertices[$i] `
                -B $lowVertices[$j] `
                -MinY $minY `
                -MaxY $maxY
        }
    }
}

if (-not (Test-Path $Path)) {
    throw "OBJ not found: $Path"
}

if (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::ChangeExtension($Path, ".collisions.txt")
}

$vertices = New-Object System.Collections.Generic.List[object]
$segments = @{}

$script:ContributingTriangles = 0
$faceCount = 0

$reader = [System.IO.StreamReader]::new((Resolve-Path $Path).Path)

try {
    while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()

        if ($null -eq $line) {
            break
        }

        $line = $line.Trim()

        if ($line.Length -eq 0) {
            continue
        }

        if ($line.StartsWith("#")) {
            continue
        }

        $parts = $line -split "\s+"

        if ($parts[0] -eq "v" -and $parts.Count -ge 4) {
            $x = [double]::Parse($parts[1].Replace(",", "."), $InvariantCulture)
            $y = [double]::Parse($parts[2].Replace(",", "."), $InvariantCulture)
            $z = [double]::Parse($parts[3].Replace(",", "."), $InvariantCulture)

            $vertices.Add((New-Vector3 -X $x -Y $y -Z $z))
            continue
        }

        if ($parts[0] -eq "f" -and $parts.Count -ge 4) {
            $indices = @()

            for ($i = 1; $i -lt $parts.Count; $i++) {
                $idx = ConvertTo-ObjIndex $parts[$i]

                if ($idx -lt 0) {
                    $idx = $vertices.Count + $idx + 1
                }

                $indices += $idx
            }

            for ($i = 1; $i -lt $indices.Count - 1; $i++) {
                $aIndex = $indices[0] - 1
                $bIndex = $indices[$i] - 1
                $cIndex = $indices[$i + 1] - 1

                if ($aIndex -lt 0 -or $bIndex -lt 0 -or $cIndex -lt 0) {
                    continue
                }

                if ($aIndex -ge $vertices.Count -or $bIndex -ge $vertices.Count -or $cIndex -ge $vertices.Count) {
                    continue
                }

                Add-TriangleCollisionSegments `
                    -A $vertices[$aIndex] `
                    -B $vertices[$bIndex] `
                    -C $vertices[$cIndex] `
                    -Segments $segments

                $faceCount++
            }
        }
    }
}
finally {
    $reader.Close()
}

$collisionLines = New-Object System.Collections.Generic.List[string]
$collisionLines.Add("# Montpellier Game collision sidecar generated from wall base segments")
$collisionLines.Add("# Format: seg ax az bx bz minY maxY thickness")
$collisionLines.Add("# Source OBJ: local path omitted")
$collisionLines.Add("# Mode: wall_base_segments")
$collisionLines.Add("# CellSize legacy parameter ignored: $CellSize")
$collisionLines.Add("# MinWallHeight: $MinWallHeight")
$collisionLines.Add("# BaseVertexTolerance: $BaseVertexTolerance")
$collisionLines.Add("# SegmentThickness: $SegmentThickness")

$count = 0

foreach ($segment in ($segments.Values | Sort-Object AZ, AX, BZ, BX)) {
    if ($count -ge $MaxBoxes) {
        break
    }

    $collisionLines.Add(
        "seg $(ConvertTo-InvariantFloat $segment.AX) $(ConvertTo-InvariantFloat $segment.AZ) $(ConvertTo-InvariantFloat $segment.BX) $(ConvertTo-InvariantFloat $segment.BZ) $(ConvertTo-InvariantFloat $segment.MinY) $(ConvertTo-InvariantFloat $segment.MaxY) $(ConvertTo-InvariantFloat $SegmentThickness)"
    )

    $count++
}

Set-Content -Path $OutputPath -Value $collisionLines -Encoding ASCII

Write-Host "=== COLLISION SIDECAR FROM WALL BASE SEGMENTS ==="
Write-Host "Source OBJ : $Path"
Write-Host "Output : $OutputPath"
Write-Host "Vertices read : $($vertices.Count)"
Write-Host "Triangles scanned : $faceCount"
Write-Host "Triangles contributing : $ContributingTriangles"
Write-Host "Segments after dedupe : $($segments.Count)"
Write-Host "Segments written : $count"
Write-Host "Max segments : $MaxBoxes"
Write-Host "Segment thickness : $SegmentThickness"
