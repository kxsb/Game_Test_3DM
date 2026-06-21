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

    $SystemRoot = $env:SystemRoot
    if (-not $SystemRoot) {
        $SystemRoot = "C:\Windows"
    }

    $BasePathParts = @(
        "$SystemRoot\System32",
        "$SystemRoot",
        "$SystemRoot\System32\WindowsPowerShell\v1.0",
        "C:\Program Files\PowerShell\7",
        "C:\Program Files\Git\cmd",
        "C:\Program Files\Git\bin"
    )

    foreach ($PathPart in $BasePathParts) {
        Add-PathFront $PathPart
    }

    $ProjectRoot = Find-MontpellierProjectRoot
    Set-Location $ProjectRoot

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

    $CmdExe = Join-Path $SystemRoot "System32\cmd.exe"
    $EnvBootstrapPath = @(
        "$SystemRoot\System32",
        "$SystemRoot",
        "$SystemRoot\System32\WindowsPowerShell\v1.0",
        "C:\Program Files\Git\cmd",
        "C:\Program Files\Git\bin"
    ) -join ';'

    $VsCommand = 'set "PATH=' + $EnvBootstrapPath + ';%PATH%" && call "' + $VsDevCmd + '" -arch=x64 -host_arch=x64 >nul && set'

    & $CmdExe /d /s /c $VsCommand |
        ForEach-Object {
            if ($_ -match "^(.*?)=(.*)$") {
                Set-Item -Path "Env:\$($matches[1])" -Value $matches[2]
            }
        }

    $CMakeDir = Join-Path $VsPath "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin"
    $NinjaDir = Join-Path $VsPath "Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja"

    foreach ($PathPart in $BasePathParts) {
        Add-PathFront $PathPart
    }

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
