param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath = "",

    [double]$MinHeight = 1.5,

    [double]$MinThickness = 0.35,

    [int]$MaxBoxes = 20000
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

function Add-CollisionBoxFromTriangle {
    param(
        [object]$A,
        [object]$B,
        [object]$C,
        [System.Collections.Generic.List[string]]$Lines
    )

    if ($script:BoxCount -ge $script:MaxBoxCount) {
        return
    }

    $minX = [Math]::Min([Math]::Min($A.X, $B.X), $C.X)
    $maxX = [Math]::Max([Math]::Max($A.X, $B.X), $C.X)

    $minY = [Math]::Min([Math]::Min($A.Y, $B.Y), $C.Y)
    $maxY = [Math]::Max([Math]::Max($A.Y, $B.Y), $C.Y)

    $minZ = [Math]::Min([Math]::Min($A.Z, $B.Z), $C.Z)
    $maxZ = [Math]::Max([Math]::Max($A.Z, $B.Z), $C.Z)

    $sizeX = $maxX - $minX
    $sizeY = $maxY - $minY
    $sizeZ = $maxZ - $minZ

    # On garde surtout les surfaces verticales ou très inclinées.
    # Les toits plats et les petits détails horizontaux ne doivent pas devenir des murs invisibles.
    if ($sizeY -lt $script:MinimumHeight) {
        return
    }

    if ($sizeX -lt $script:MinimumThickness) {
        $sizeX = $script:MinimumThickness
    }

    if ($sizeY -lt $script:MinimumThickness) {
        $sizeY = $script:MinimumThickness
    }

    if ($sizeZ -lt $script:MinimumThickness) {
        $sizeZ = $script:MinimumThickness
    }

    $centerX = ($minX + $maxX) / 2.0
    $centerY = ($minY + $maxY) / 2.0
    $centerZ = ($minZ + $maxZ) / 2.0

    $Lines.Add(
        "box $(ConvertTo-InvariantFloat $centerX) $(ConvertTo-InvariantFloat $centerY) $(ConvertTo-InvariantFloat $centerZ) $(ConvertTo-InvariantFloat $sizeX) $(ConvertTo-InvariantFloat $sizeY) $(ConvertTo-InvariantFloat $sizeZ)"
    )

    $script:BoxCount++
}

if (-not (Test-Path $Path)) {
    throw "OBJ not found: $Path"
}

if (-not $OutputPath) {
    $OutputPath = [System.IO.Path]::ChangeExtension($Path, ".collisions.txt")
}

$vertices = New-Object System.Collections.Generic.List[object]
$collisionLines = New-Object System.Collections.Generic.List[string]

$collisionLines.Add("# Montpellier Game collision sidecar generated from OBJ")
$collisionLines.Add("# Format: box cx cy cz sx sy sz")
$collisionLines.Add("# Source OBJ: $Path")
$collisionLines.Add("# MinHeight: $MinHeight")
$collisionLines.Add("# MinThickness: $MinThickness")

$script:BoxCount = 0
$script:MaxBoxCount = $MaxBoxes
$script:MinimumHeight = $MinHeight
$script:MinimumThickness = $MinThickness

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

            # Triangulation éventuelle en éventail, même si nos OBJ actuels sont déjà triangulés.
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

                Add-CollisionBoxFromTriangle `
                    -A $vertices[$aIndex] `
                    -B $vertices[$bIndex] `
                    -C $vertices[$cIndex] `
                    -Lines $collisionLines

                $faceCount++
            }
        }
    }
}
finally {
    $reader.Close()
}

Set-Content -Path $OutputPath -Value $collisionLines -Encoding ASCII

Write-Host "=== COLLISION SIDECAR FROM OBJ ==="
Write-Host "Source OBJ : $Path"
Write-Host "Output : $OutputPath"
Write-Host "Vertices read : $($vertices.Count)"
Write-Host "Triangles scanned : $faceCount"
Write-Host "Collision boxes : $BoxCount"