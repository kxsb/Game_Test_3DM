function Add-PathFront {
    param([string]$PathPart)

    if (-not (Test-Path $PathPart)) {
        return
    }

    $CurrentParts = $env:Path -split ';'
    if ($CurrentParts -notcontains $PathPart) {
        $env:Path = "$PathPart;$env:Path"
    }
}

function Find-MontpellierProjectRoot {
    param([string]$StartPath = (Get-Location).Path)

    $Dir = Get-Item $StartPath

    while ($null -ne $Dir) {
        $Candidate = Join-Path $Dir.FullName "CMakeLists.txt"
        if (Test-Path $Candidate) {
            return $Dir.FullName
        }

        $Dir = $Dir.Parent
    }

    throw "Impossible de trouver la racine du projet Montpellier Game."
}

function Initialize-MontpellierWindowsDevEnv {
    param([switch]$Quiet)

    Add-PathFront "$env:WINDIR\System32"
    Add-PathFront "$env:WINDIR"
    Add-PathFront "$env:WINDIR\System32\WindowsPowerShell\v1.0"
    Add-PathFront "C:\Program Files\Git\cmd"
    Add-PathFront "C:\Program Files\Git\bin"

    $ProjectRoot = Find-MontpellierProjectRoot
    Set-Location $ProjectRoot

    $OriginalPath = $env:Path

    $VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $VsWhere)) {
        throw "vswhere.exe introuvable. Visual Studio Installer semble absent."
    }

    $VsPath = & $VsWhere -latest -products * -property installationPath
    if (-not $VsPath) {
        throw "Visual Studio introuvable."
    }

    $VsDevCmd = Join-Path $VsPath "Common7\Tools\VsDevCmd.bat"
    if (-not (Test-Path $VsDevCmd)) {
        throw "VsDevCmd.bat introuvable : $VsDevCmd"
    }

    $env:Path = "$env:WINDIR\System32;C:\Program Files\Git\cmd;C:\Program Files\Git\bin;$OriginalPath"

    cmd /c "`"$VsDevCmd`" -arch=x64 -host_arch=x64 >nul && set" |
        ForEach-Object {
            if ($_ -match "^(.*?)=(.*)$") {
                Set-Item -Path "Env:\$($matches[1])" -Value $matches[2]
            }
        }

    $CMakeDir = Join-Path $VsPath "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
    $NinjaDir = Join-Path $VsPath "Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"

    Add-PathFront "$env:WINDIR\System32"
    Add-PathFront "$env:WINDIR"
    Add-PathFront "C:\Program Files\Git\cmd"
    Add-PathFront "C:\Program Files\Git\bin"
    Add-PathFront $CMakeDir
    Add-PathFront $NinjaDir

    if (-not $Quiet) {
        Write-Host "Projet : $ProjectRoot"
        Write-Host "Visual Studio : $VsPath"

        Write-Host ""
        Write-Host "Outils :"
        where.exe git
        where.exe cl
        where.exe cmake
        where.exe ninja
    }

    return [pscustomobject]@{
        ProjectRoot = $ProjectRoot
        VisualStudioPath = $VsPath
        CMakeDir = $CMakeDir
        NinjaDir = $NinjaDir
    }
}
