param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath = "",

    [double]$CellSize = 6.0,

    [double]$MinWallHeight = 1.8,

    [double]$MinColumnHeight = 1.5,

    [double]$ColumnPadding = 0.15,

    [int]$MaxBoxes = 4000
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

function Get-CellKey {
    param(
        [int]$Ix,
        [int]$Iz
    )

    return "$Ix`:$Iz"
}

function Add-CellOccupation {
    param(
        [hashtable]$Cells,
        [int]$Ix,
        [int]$Iz,
        [double]$MinY,
        [double]$MaxY
    )

    $key = Get-CellKey -Ix $Ix -Iz $Iz

    if (-not $Cells.ContainsKey($key)) {
        $Cells[$key] = [pscustomobject]@{
            Ix = $Ix
            Iz = $Iz
            MinY = $MinY
            MaxY = $MaxY
        }

        return
    }

    if ($MinY -lt $Cells[$key].MinY) {
        $Cells[$key].MinY = $MinY
    }

    if ($MaxY -gt $Cells[$key].MaxY) {
        $Cells[$key].MaxY = $MaxY
    }
}

function Add-TriangleToCollisionGrid {
    param(
        [object]$A,
        [object]$B,
        [object]$C,
        [hashtable]$Cells
    )

    $minX = Get-Min3 $A.X $B.X $C.X
    $maxX = Get-Max3 $A.X $B.X $C.X

    $minY = Get-Min3 $A.Y $B.Y $C.Y
    $maxY = Get-Max3 $A.Y $B.Y $C.Y

    $minZ = Get-Min3 $A.Z $B.Z $C.Z
    $maxZ = Get-Max3 $A.Z $B.Z $C.Z

    $height = $maxY - $minY

    if ($height -lt $script:MinimumWallHeight) {
        return
    }

    $script:ContributingTriangles++

    $minIx = [Math]::Floor($minX / $script:GridCellSize)
    $maxIx = [Math]::Floor($maxX / $script:GridCellSize)

    $minIz = [Math]::Floor($minZ / $script:GridCellSize)
    $maxIz = [Math]::Floor($maxZ / $script:GridCellSize)

    for ($ix = $minIx; $ix -le $maxIx; $ix++) {
        for ($iz = $minIz; $iz -le $maxIz; $iz++) {
            Add-CellOccupation `
                -Cells $Cells `
                -Ix $ix `
                -Iz $iz `
                -MinY $minY `
                -MaxY $maxY
        }
    }
}

function Get-NextRemainingCell {
    param([hashtable]$Remaining)

    $best = $null

    foreach ($cell in $Remaining.Values) {
        if ($null -eq $best) {
            $best = $cell
            continue
        }

        if ($cell.Iz -lt $best.Iz) {
            $best = $cell
            continue
        }

        if ($cell.Iz -eq $best.Iz -and $cell.Ix -lt $best.Ix) {
            $best = $cell
        }
    }

    return $best
}

function Convert-GridToMergedBoxes {
    param(
        [hashtable]$Cells,
        [double]$CellSize,
        [double]$MinColumnHeight,
        [double]$Padding,
        [int]$MaxBoxes
    )

    $remaining = @{}

    foreach ($entry in $Cells.GetEnumerator()) {
        $remaining[$entry.Key] = $entry.Value
    }

    $boxes = New-Object System.Collections.Generic.List[object]

    while ($remaining.Count -gt 0) {
        if ($boxes.Count -ge $MaxBoxes) {
            break
        }

        $start = Get-NextRemainingCell -Remaining $remaining

        if ($null -eq $start) {
            break
        }

        $widthCells = 1

        while ($true) {
            $nextIx = $start.Ix + $widthCells
            $key = Get-CellKey -Ix $nextIx -Iz $start.Iz

            if ($remaining.ContainsKey($key)) {
                $widthCells++
            }
            else {
                break
            }
        }

        $depthCells = 1

        while ($true) {
            $nextIz = $start.Iz + $depthCells
            $rowOk = $true

            for ($dx = 0; $dx -lt $widthCells; $dx++) {
                $key = Get-CellKey -Ix ($start.Ix + $dx) -Iz $nextIz

                if (-not $remaining.ContainsKey($key)) {
                    $rowOk = $false
                    break
                }
            }

            if ($rowOk) {
                $depthCells++
            }
            else {
                break
            }
        }

        $minY = [double]::PositiveInfinity
        $maxY = [double]::NegativeInfinity

        for ($dz = 0; $dz -lt $depthCells; $dz++) {
            for ($dx = 0; $dx -lt $widthCells; $dx++) {
                $key = Get-CellKey -Ix ($start.Ix + $dx) -Iz ($start.Iz + $dz)
                $cell = $remaining[$key]

                if ($cell.MinY -lt $minY) {
                    $minY = $cell.MinY
                }

                if ($cell.MaxY -gt $maxY) {
                    $maxY = $cell.MaxY
                }
            }
        }

        for ($dz = 0; $dz -lt $depthCells; $dz++) {
            for ($dx = 0; $dx -lt $widthCells; $dx++) {
                $key = Get-CellKey -Ix ($start.Ix + $dx) -Iz ($start.Iz + $dz)
                $remaining.Remove($key)
            }
        }

        $height = $maxY - $minY

        if ($height -lt $MinColumnHeight) {
            continue
        }

        $centerX = ($start.Ix + ($widthCells / 2.0)) * $CellSize
        $centerZ = ($start.Iz + ($depthCells / 2.0)) * $CellSize
        $centerY = ($minY + $maxY) / 2.0

        $sizeX = ($widthCells * $CellSize) + $Padding
        $sizeY = $height
        $sizeZ = ($depthCells * $CellSize) + $Padding

        $boxes.Add([pscustomobject]@{
            CenterX = $centerX
            CenterY = $centerY
            CenterZ = $centerZ
            SizeX = $sizeX
            SizeY = $sizeY
            SizeZ = $sizeZ
            WidthCells = $widthCells
            DepthCells = $depthCells
        })
    }

    return $boxes
}

if (-not (Test-Path $Path)) {
    throw "OBJ not found: $Path"
}

if (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::ChangeExtension($Path, ".collisions.txt")
}

$vertices = New-Object System.Collections.Generic.List[object]
$cells = @{}

$script:GridCellSize = $CellSize
$script:MinimumWallHeight = $MinWallHeight
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

                Add-TriangleToCollisionGrid `
                    -A $vertices[$aIndex] `
                    -B $vertices[$bIndex] `
                    -C $vertices[$cIndex] `
                    -Cells $cells

                $faceCount++
            }
        }
    }
}
finally {
    $reader.Close()
}

$boxes = Convert-GridToMergedBoxes `
    -Cells $cells `
    -CellSize $CellSize `
    -MinColumnHeight $MinColumnHeight `
    -Padding $ColumnPadding `
    -MaxBoxes $MaxBoxes

$collisionLines = New-Object System.Collections.Generic.List[string]
$collisionLines.Add("# Montpellier Game collision sidecar generated from OBJ merged grid")
$collisionLines.Add("# Format: box cx cy cz sx sy sz")
$collisionLines.Add("# Source OBJ: $Path")
$collisionLines.Add("# CellSize: $CellSize")
$collisionLines.Add("# MinWallHeight: $MinWallHeight")
$collisionLines.Add("# MinColumnHeight: $MinColumnHeight")
$collisionLines.Add("# ColumnPadding: $ColumnPadding")

foreach ($box in $boxes) {
    $collisionLines.Add(
        "box $(ConvertTo-InvariantFloat $box.CenterX) $(ConvertTo-InvariantFloat $box.CenterY) $(ConvertTo-InvariantFloat $box.CenterZ) $(ConvertTo-InvariantFloat $box.SizeX) $(ConvertTo-InvariantFloat $box.SizeY) $(ConvertTo-InvariantFloat $box.SizeZ)"
    )
}

Set-Content -Path $OutputPath -Value $collisionLines -Encoding ASCII

Write-Host "=== COLLISION SIDECAR FROM OBJ MERGED GRID ==="
Write-Host "Source OBJ : $Path"
Write-Host "Output : $OutputPath"
Write-Host "Vertices read : $($vertices.Count)"
Write-Host "Triangles scanned : $faceCount"
Write-Host "Triangles contributing : $ContributingTriangles"
Write-Host "Occupied cells before merge : $($cells.Count)"
Write-Host "Collision boxes after merge : $($boxes.Count)"
Write-Host "Cell size : $CellSize"