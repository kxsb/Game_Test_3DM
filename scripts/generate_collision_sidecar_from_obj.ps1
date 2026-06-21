param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath = "",

    [double]$CellSize = 2.0,

    [double]$MinWallHeight = 1.8,

    [double]$MinColumnHeight = 1.5,

    [double]$ColumnPadding = 0.10,

    [int]$MaxBoxes = 12000
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

function Add-CellOccupation {
    param(
        [hashtable]$Cells,
        [int]$Ix,
        [int]$Iz,
        [double]$MinY,
        [double]$MaxY
    )

    $key = "$Ix`:$Iz"

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

    # On ne garde que les faces qui montent suffisamment.
    # Cela élimine la plupart des sols, toits plats, corniches et détails horizontaux.
    if ($height -lt $script:MinimumWallHeight) {
        return
    }

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

$faceCount = 0
$usedFaceCount = 0

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

                $beforeCount = $cells.Count

                Add-TriangleToCollisionGrid `
                    -A $vertices[$aIndex] `
                    -B $vertices[$bIndex] `
                    -C $vertices[$cIndex] `
                    -Cells $cells

                if ($cells.Count -gt $beforeCount) {
                    $usedFaceCount++
                }

                $faceCount++
            }
        }
    }
}
finally {
    $reader.Close()
}

$collisionLines = New-Object System.Collections.Generic.List[string]
$collisionLines.Add("# Montpellier Game collision sidecar generated from OBJ grid")
$collisionLines.Add("# Format: box cx cy cz sx sy sz")
$collisionLines.Add("# Source OBJ: $Path")
$collisionLines.Add("# CellSize: $CellSize")
$collisionLines.Add("# MinWallHeight: $MinWallHeight")
$collisionLines.Add("# MinColumnHeight: $MinColumnHeight")
$collisionLines.Add("# ColumnPadding: $ColumnPadding")

$boxCount = 0

foreach ($entry in $cells.GetEnumerator() | Sort-Object Name) {
    if ($boxCount -ge $MaxBoxes) {
        break
    }

    $cell = $entry.Value
    $height = $cell.MaxY - $cell.MinY

    if ($height -lt $MinColumnHeight) {
        continue
    }

    $centerX = (($cell.Ix + 0.5) * $CellSize)
    $centerZ = (($cell.Iz + 0.5) * $CellSize)

    $centerY = ($cell.MinY + $cell.MaxY) / 2.0

    $sizeX = $CellSize + $ColumnPadding
    $sizeY = $height
    $sizeZ = $CellSize + $ColumnPadding

    $collisionLines.Add(
        "box $(ConvertTo-InvariantFloat $centerX) $(ConvertTo-InvariantFloat $centerY) $(ConvertTo-InvariantFloat $centerZ) $(ConvertTo-InvariantFloat $sizeX) $(ConvertTo-InvariantFloat $sizeY) $(ConvertTo-InvariantFloat $sizeZ)"
    )

    $boxCount++
}

Set-Content -Path $OutputPath -Value $collisionLines -Encoding ASCII

Write-Host "=== COLLISION SIDECAR FROM OBJ GRID ==="
Write-Host "Source OBJ : $Path"
Write-Host "Output : $OutputPath"
Write-Host "Vertices read : $($vertices.Count)"
Write-Host "Triangles scanned : $faceCount"
Write-Host "Faces contributing : $usedFaceCount"
Write-Host "Occupied cells : $($cells.Count)"
Write-Host "Collision boxes : $boxCount"
Write-Host "Cell size : $CellSize"