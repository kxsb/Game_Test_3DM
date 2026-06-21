param(
    [double]$Width = 250,
    [double]$Depth = 250,
    [int]$MaxFaces = 50000,
    [string]$DxfPath = "..\VilleMTP_MTP_Modele3D\Centre_BATIMENTS_2016.dxf",
    [string]$OutputPath = "",
    [double]$CenterX = [double]::NaN,
    [double]$CenterY = [double]::NaN,

    [switch]$NoCollisions,

    [double]$CollisionCellSize = 6.0,
    [double]$CollisionMinWallHeight = 1.8,
    [double]$CollisionMinColumnHeight = 1.5,
    [double]$CollisionColumnPadding = 0.15,
    [int]$CollisionMaxBoxes = 4000,

    [switch]$ForceExtract,
    [switch]$ForceCollisions,
    [switch]$NoRun
)

$ErrorActionPreference = "Stop"
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function ConvertTo-FileNumber {
    param([double]$Value)

    return $Value.ToString("0.###", $InvariantCulture).Replace(".", "p").Replace("-", "m")
}

if (-not (Test-Path $DxfPath)) {
    throw "DXF not found: $DxfPath"
}

$ExtractScript = Join-Path $PSScriptRoot "dxf_extract_tile_obj.ps1"
$CollisionScript = Join-Path $PSScriptRoot "generate_collision_sidecar_from_obj.ps1"
$MaterialScript = Join-Path $PSScriptRoot "apply_tile_materials.ps1"
$RunScript = Join-Path $PSScriptRoot "run_windows.ps1"

if (-not (Test-Path $ExtractScript)) {
    throw "Extractor script not found: $ExtractScript"
}

if (-not (Test-Path $RunScript)) {
    throw "Run script not found: $RunScript"
}

if (-not $OutputPath) {
    $widthSlug = ConvertTo-FileNumber $Width
    $depthSlug = ConvertTo-FileNumber $Depth
    $cellSlug = ConvertTo-FileNumber $CollisionCellSize

    $OutputPath = "assets\models\dxf_tile_centre_w${widthSlug}_d${depthSlug}_c${cellSlug}.obj"
}

if (Test-Path $MaterialScript) {
    Write-Host ""
    Write-Host "=== APPLY TILE MATERIALS ==="
    & $MaterialScript -Path $OutputPath
}
else {
    Write-Host ""
    Write-Host "=== APPLY TILE MATERIALS ==="
    Write-Host "Material script missing, skipping."
}

$CollisionPath = [System.IO.Path]::ChangeExtension($OutputPath, ".collisions.txt")
$GroundPath = [System.IO.Path]::ChangeExtension($OutputPath, ".ground.txt")

Write-Host "=== DXF TILE CENTRE ==="
Write-Host "DXF : $DxfPath"
Write-Host "OBJ : $OutputPath"
Write-Host "Collisions : $CollisionPath"`nWrite-Host "Ground : $GroundPath"
Write-Host "Width : $Width"
Write-Host "Depth : $Depth"
Write-Host "MaxFaces : $MaxFaces"
Write-Host "CollisionCellSize : $CollisionCellSize"

$shouldExtract = $ForceExtract -or (-not (Test-Path $OutputPath))

if ($shouldExtract) {
    Write-Host ""
    Write-Host "=== EXTRACT OBJ TILE ==="

    $extractArgs = @{
        Path = $DxfPath
        OutputPath = $OutputPath
        Width = $Width
        Depth = $Depth
        MaxFaces = $MaxFaces
    }

    if (-not [double]::IsNaN($CenterX)) {
        $extractArgs["CenterX"] = $CenterX
    }

    if (-not [double]::IsNaN($CenterY)) {
        $extractArgs["CenterY"] = $CenterY
    }

    & $ExtractScript @extractArgs
}
else {
    Write-Host ""
    Write-Host "=== EXTRACT OBJ TILE ==="
    Write-Host "Cache hit: OBJ already exists. Use -ForceExtract to regenerate."
}

if (-not (Test-Path $OutputPath)) {
    throw "Expected OBJ missing after extraction step: $OutputPath"
}

if (-not $NoCollisions) {
    $shouldGenerateCollisions = $ForceCollisions -or $ForceExtract -or (-not (Test-Path $CollisionPath))

    if ($shouldGenerateCollisions) {
        if (-not (Test-Path $CollisionScript)) {
            throw "Collision sidecar generator not found: $CollisionScript"
        }

        Write-Host ""
        Write-Host "=== GENERATE COLLISION SIDECAR ==="

        & $CollisionScript `
            -Path $OutputPath `
            -OutputPath $CollisionPath `
            -CellSize $CollisionCellSize `
            -MinWallHeight $CollisionMinWallHeight `
            -MinColumnHeight $CollisionMinColumnHeight `
            -ColumnPadding $CollisionColumnPadding `
            -MaxBoxes $CollisionMaxBoxes
    }
    else {
        Write-Host ""
        Write-Host "=== GENERATE COLLISION SIDECAR ==="
        Write-Host "Cache hit: collision sidecar already exists. Use -ForceCollisions to regenerate."
    }
}

if ($NoRun) {
    Write-Host ""
    Write-Host "NoRun enabled. Generated assets are ready."
    exit 0
}

Write-Host ""
Write-Host "=== RUN GENERATED TILE ==="
& $RunScript -ModelPath $OutputPath
