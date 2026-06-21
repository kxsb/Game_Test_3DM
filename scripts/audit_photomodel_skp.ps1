param(
    [string]$PhotoRoot = "",
    [int]$ProbeBytesPerFile = 1048576
)

$ErrorActionPreference = "Stop"
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

Write-Host "=== AUDIT PHOTOMODEL SKP ===" -ForegroundColor Cyan

$projectRoot = (Resolve-Path ".").Path
$devRoot = Split-Path $projectRoot -Parent

if (-not $PhotoRoot) {
    $PhotoRoot = Join-Path $devRoot "VilleMTP_MTP_PhotomodeleUrbain"
}

if (-not (Test-Path $PhotoRoot)) {
    throw "Dossier photomodèle introuvable : $PhotoRoot"
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$auditDir = Join-Path $projectRoot "_audit_photomodel_skp_$stamp"
New-Item -ItemType Directory -Force -Path $auditDir | Out-Null

function Get-FileSizeMb {
    param([System.IO.FileInfo]$File)

    return [Math]::Round($File.Length / 1MB, 2)
}

function Read-FilePrefixText {
    param(
        [string]$Path,
        [int]$MaxBytes
    )

    $file = [System.IO.FileInfo]::new($Path)
    $bytesToRead = [Math]::Min($MaxBytes, [int][Math]::Min($file.Length, [int]::MaxValue))

    $buffer = New-Object byte[] $bytesToRead

    $stream = [System.IO.File]::OpenRead($Path)

    try {
        [void]$stream.Read($buffer, 0, $bytesToRead)
    }
    finally {
        $stream.Close()
    }

    return [System.Text.Encoding]::ASCII.GetString($buffer)
}

function Read-FileMagicHex {
    param([string]$Path)

    $buffer = New-Object byte[] 16
    $stream = [System.IO.File]::OpenRead($Path)

    try {
        [void]$stream.Read($buffer, 0, 16)
    }
    finally {
        $stream.Close()
    }

    return (($buffer | ForEach-Object { $_.ToString("X2") }) -join " ")
}

function Count-Regex {
    param(
        [string]$Text,
        [string]$Pattern
    )

    return ([regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
}

function Find-Tool {
    param([string]$Command)

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue

    if ($cmd) {
        return $cmd.Source
    }

    return ""
}

function Find-Executables {
    param(
        [string[]]$Roots,
        [string]$Filter
    )

    $found = New-Object System.Collections.Generic.List[string]

    foreach ($root in $Roots) {
        if (-not $root) { continue }
        if (-not (Test-Path $root)) { continue }

        Get-ChildItem -Path $root -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue |
            Select-Object -First 20 |
            ForEach-Object {
                $found.Add($_.FullName)
            }
    }

    return $found
}

# ------------------------------------------------------------
# 1) Inventaire SKP
# ------------------------------------------------------------
$skpFiles = Get-ChildItem -Path $PhotoRoot -Recurse -File -Filter *.skp | Sort-Object FullName

if ($skpFiles.Count -eq 0) {
    throw "Aucun fichier .skp trouvé dans $PhotoRoot"
}

Write-Host "SKP trouvés : $($skpFiles.Count)"

$inventory = New-Object System.Collections.Generic.List[object]

foreach ($file in $skpFiles) {
    Write-Host "Scan : $($file.Name)"

    $magic = Read-FileMagicHex $file.FullName
    $text = Read-FilePrefixText -Path $file.FullName -MaxBytes $ProbeBytesPerFile

    $inventory.Add([pscustomobject]@{
        Name = $file.Name
        File = $file.FullName
        Directory = Split-Path $file.FullName -Parent
        SizeMB = Get-FileSizeMb $file
        MagicHex = $magic
        HasSketchUpString = ($text -match "SketchUp")
        HasVersionMention = ($text -match "SketchUp\s+[0-9]|SU[0-9]|Version")
        TextureMentions = Count-Regex -Text $text -Pattern "texture|material|jpg|jpeg|png|tif|tiff"
        ImageExtensionMentions = Count-Regex -Text $text -Pattern "\.(jpg|jpeg|png|tif|tiff)"
        GeoMentions = Count-Regex -Text $text -Pattern "geo|latitude|longitude|Lambert|EPSG|coordinate|origin|north"
        ComponentMentions = Count-Regex -Text $text -Pattern "component|group|layer|entity|face"
    })
}

$inventoryCsv = Join-Path $auditDir "photomodel_skp_inventory.csv"
$inventory | Export-Csv -Path $inventoryCsv -NoTypeInformation -Encoding UTF8

# ------------------------------------------------------------
# 2) Candidats utiles
# ------------------------------------------------------------
$candidateNames = @(
    "C06.skp",
    "C07.skp",
    "B06.skp",
    "B07.skp",
    "C08.skp",
    "B08.skp",
    "A12.skp",
    "A13.skp"
)

$candidates = New-Object System.Collections.Generic.List[object]

foreach ($name in $candidateNames) {
    $hit = $inventory | Where-Object { $_.Name -ieq $name } | Select-Object -First 1

    if ($hit) {
        $candidates.Add($hit)
    }
}

$largest = $inventory | Sort-Object SizeMB -Descending | Select-Object -First 20
$smallUseful = $inventory | Where-Object { $_.SizeMB -gt 0.5 -and $_.SizeMB -lt 15.0 } | Sort-Object SizeMB | Select-Object -First 20

$candidateCsv = Join-Path $auditDir "photomodel_candidate_files.csv"
@($candidates + $largest + $smallUseful) |
    Sort-Object File -Unique |
    Export-Csv -Path $candidateCsv -NoTypeInformation -Encoding UTF8

# ------------------------------------------------------------
# 3) Probe plus profond sur quelques candidats
# ------------------------------------------------------------
$deepProbeFiles = @($candidates | Select-Object -First 4)

if ($deepProbeFiles.Count -eq 0) {
    $deepProbeFiles = @($smallUseful | Select-Object -First 4)
}

$deepOut = Join-Path $auditDir "photomodel_deep_probe.txt"
$deepLines = New-Object System.Collections.Generic.List[string]

foreach ($item in $deepProbeFiles) {
    $fileInfo = [System.IO.FileInfo]::new($item.File)
    $bytesToRead = [Math]::Min($fileInfo.Length, 8MB)

    $text = Read-FilePrefixText -Path $item.File -MaxBytes $bytesToRead

    $deepLines.Add("")
    $deepLines.Add("============================================================")
    $deepLines.Add("FILE: $($item.Name)")
    $deepLines.Add("SIZE_MB: $($item.SizeMB)")
    $deepLines.Add("PATH: $($item.File)")
    $deepLines.Add("BYTES_PROBED: $bytesToRead")
    $deepLines.Add("============================================================")

    $patterns = @(
        "SketchUp",
        "Version",
        "texture",
        "material",
        ".jpg",
        ".jpeg",
        ".png",
        ".tif",
        ".tiff",
        "latitude",
        "longitude",
        "coordinate",
        "origin",
        "Lambert",
        "EPSG",
        "component",
        "layer",
        "face"
    )

    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($text, ".{0,45}$([regex]::Escape($pattern)).{0,45}", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        $deepLines.Add("")
        $deepLines.Add("PATTERN: $pattern | count=$($matches.Count)")

        foreach ($m in ($matches | Select-Object -First 12)) {
            $clean = $m.Value -replace "[^\x20-\x7E]", " "
            $deepLines.Add("  $clean")
        }
    }
}

$deepLines | Set-Content $deepOut -Encoding UTF8

# ------------------------------------------------------------
# 4) Outils de conversion disponibles
# ------------------------------------------------------------
$toolRows = New-Object System.Collections.Generic.List[object]

$pathTools = @("blender", "assimp", "python", "py", "7z", "cmake", "git")

foreach ($tool in $pathTools) {
    $toolRows.Add([pscustomobject]@{
        Tool = $tool
        Found = [bool](Find-Tool $tool)
        Path = Find-Tool $tool
    })
}

$programRoots = @(
    "$env:ProgramFiles\Blender Foundation",
    "$env:ProgramFiles\SketchUp",
    "${env:ProgramFiles(x86)}\SketchUp",
    "$env:LOCALAPPDATA\Programs"
)

$exeHits = New-Object System.Collections.Generic.List[object]

foreach ($exe in (Find-Executables -Roots $programRoots -Filter "blender.exe")) {
    $exeHits.Add([pscustomobject]@{ Tool = "blender.exe"; Path = $exe })
}

foreach ($exe in (Find-Executables -Roots $programRoots -Filter "SketchUp.exe")) {
    $exeHits.Add([pscustomobject]@{ Tool = "SketchUp.exe"; Path = $exe })
}

$toolsCsv = Join-Path $auditDir "conversion_tools.csv"
$toolRows | Export-Csv -Path $toolsCsv -NoTypeInformation -Encoding UTF8

$exeCsv = Join-Path $auditDir "conversion_executables_found.csv"
$exeHits | Export-Csv -Path $exeCsv -NoTypeInformation -Encoding UTF8

# ------------------------------------------------------------
# 5) Résumé
# ------------------------------------------------------------
$summaryPath = Join-Path $auditDir "SUMMARY.txt"
$summary = New-Object System.Collections.Generic.List[string]

$summary.Add("=== PHOTOMODEL_AUDIT001 SUMMARY ===")
$summary.Add("")
$summary.Add("Project root: $projectRoot")
$summary.Add("Photomodel root: $PhotoRoot")
$summary.Add("SKP files: $($skpFiles.Count)")
$summary.Add("Probe bytes per file: $ProbeBytesPerFile")
$summary.Add("")
$summary.Add("Inventory CSV: $inventoryCsv")
$summary.Add("Candidate CSV: $candidateCsv")
$summary.Add("Deep probe: $deepOut")
$summary.Add("Tools CSV: $toolsCsv")
$summary.Add("Executables CSV: $exeCsv")
$summary.Add("")

$totalSize = [Math]::Round((($skpFiles | Measure-Object Length -Sum).Sum / 1MB), 2)
$summary.Add("Total SKP size MB: $totalSize")
$summary.Add("")

$summary.Add("=== Explicit candidate files ===")
if ($candidates.Count -gt 0) {
    foreach ($c in $candidates) {
        $summary.Add("$($c.Name) | $($c.SizeMB) MB | textureMentions=$($c.TextureMentions) | geoMentions=$($c.GeoMentions)")
    }
}
else {
    $summary.Add("No explicit C06/B06-style candidate found.")
}

$summary.Add("")
$summary.Add("=== Top largest SKP ===")
foreach ($item in ($largest | Select-Object -First 10)) {
    $summary.Add("$($item.Name) | $($item.SizeMB) MB | textureMentions=$($item.TextureMentions) | geoMentions=$($item.GeoMentions)")
}

$summary.Add("")
$summary.Add("=== Small useful SKP candidates for conversion test ===")
foreach ($item in ($smallUseful | Select-Object -First 10)) {
    $summary.Add("$($item.Name) | $($item.SizeMB) MB | textureMentions=$($item.TextureMentions) | geoMentions=$($item.GeoMentions)")
}

$summary.Add("")
$summary.Add("=== PATH tools ===")
foreach ($row in $toolRows) {
    $summary.Add("$($row.Tool): found=$($row.Found) path=$($row.Path)")
}

$summary.Add("")
$summary.Add("=== Program executables ===")
if ($exeHits.Count -gt 0) {
    foreach ($row in $exeHits) {
        $summary.Add("$($row.Tool): $($row.Path)")
    }
}
else {
    $summary.Add("No Blender/SketchUp executable found in common Program Files paths.")
}

$summary.Add("")
$summary.Add("=== Recommendation ===")
if (($toolRows | Where-Object { $_.Tool -eq "blender" -and $_.Found }).Count -gt 0 -or ($exeHits | Where-Object { $_.Tool -eq "blender.exe" }).Count -gt 0) {
    $summary.Add("Blender appears available. Next step can test SKP import/export if the installed Blender supports this SKP version.")
}
elseif (($toolRows | Where-Object { $_.Tool -eq "assimp" -and $_.Found }).Count -gt 0) {
    $summary.Add("Assimp appears available. Next step can test assimp export SKP -> OBJ on one small candidate.")
}
elseif (($exeHits | Where-Object { $_.Tool -eq "SketchUp.exe" }).Count -gt 0) {
    $summary.Add("SketchUp appears available. Manual or plugin-based export may be possible; CLI automation must be checked.")
}
else {
    $summary.Add("No obvious SKP conversion tool found. Next step should install or identify a conversion path before touching all 242 files.")
}

$summary | Set-Content $summaryPath -Encoding UTF8

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Get-Content $summaryPath

Write-Host ""
Write-Host "Audit terminé : $auditDir" -ForegroundColor Green
notepad $summaryPath

