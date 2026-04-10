param(
    [string]$PackageDir = "",
    [string]$DistroName = "",
    [string]$PluginCacheDir = "",
    [switch]$AllowMissingLinuxPlugin
)

$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $script:__pj_prev_native_pref = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
}

function Get-ScriptDir {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return (Split-Path -Parent $PSCommandPath)
    }
    if ($MyInvocation.MyCommand -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
        return (Split-Path -Parent $MyInvocation.MyCommand.Path)
    }
    return (Get-Location).Path
}

function Convert-FileToLf([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path $Path)) {
        return
    }

    $content = [System.IO.File]::ReadAllText($Path)
    $content = $content.Replace("`r`n", "`n").Replace("`r", "`n")
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $content, $utf8NoBom)
}

function To-WslPath([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    if ($full.Length -ge 2 -and $full[1] -eq ':') {
        $drive = $full.Substring(0, 1).ToLowerInvariant()
        $tail = ($full.Substring(2) -replace '\\', '/')
        if ($tail.StartsWith('/')) {
            $tail = $tail.Substring(1)
        }
        return "/mnt/$drive/$tail"
    }
    return ($full -replace '\\', '/')
}

function Invoke-NativeCapture([string]$FilePath, [string[]]$ArgumentList) {
    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -WindowStyle Hidden
        $stdoutText = if (Test-Path $stdoutPath) { [System.IO.File]::ReadAllText($stdoutPath) } else { '' }
        $stderrText = if (Test-Path $stderrPath) { [System.IO.File]::ReadAllText($stderrPath) } else { '' }
        $combined = (($stdoutText + "`n" + $stderrText).Trim())
        return @{
            ExitCode = $proc.ExitCode
            StdOut = $stdoutText
            StdErr = $stderrText
            Combined = $combined
        }
    } finally {
        Remove-Item -Force -ErrorAction SilentlyContinue $stdoutPath, $stderrPath
    }
}

if ([string]::IsNullOrWhiteSpace($PackageDir)) {
    $PackageDir = Get-ScriptDir
}
$PackageDir = [System.IO.Path]::GetFullPath($PackageDir)

if ([string]::IsNullOrWhiteSpace($PluginCacheDir)) {
    if ($env:PJARCZAK_BAMBU_WINDOWS_PLUGIN_CACHE_DIR) {
        $PluginCacheDir = $env:PJARCZAK_BAMBU_WINDOWS_PLUGIN_CACHE_DIR
    } elseif ($env:APPDATA) {
        $PluginCacheDir = Join-Path $env:APPDATA 'OrcaSlicer\plugins'
    }
}
if (-not [string]::IsNullOrWhiteSpace($PluginCacheDir)) {
    $PluginCacheDir = [System.IO.Path]::GetFullPath($PluginCacheDir)
}

if ([string]::IsNullOrWhiteSpace($DistroName)) {
    $distroFile = Join-Path $PackageDir 'pjarczak_wsl_distro.txt'
    if (Test-Path $distroFile) {
        $DistroName = (Get-Content $distroFile -Raw).Trim()
    }
}
if ([string]::IsNullOrWhiteSpace($DistroName)) {
    throw 'Missing distro name. Set PJARCZAK_WSL_DISTRO or provide pjarczak_wsl_distro.txt.'
}

$requiredFiles = @(
    'pjarczak_bambu_networking_bridge.dll',
    'pjarczak_wsl_distro.txt',
    'install_runtime.ps1',
    'verify_runtime.ps1',
    'pjarczak_wsl_run_host.sh',
    'pjarczak_bambu_linux_host',
    'windows-wsl2-rootfs.tar'
)

foreach ($name in $requiredFiles) {
    $path = Join-Path $PackageDir $name
    if (!(Test-Path $path)) {
        throw "Missing package file: $name"
    }
}

$bootstrapPath = Join-Path $PackageDir 'pjarczak_wsl_run_host.sh'
Convert-FileToLf $bootstrapPath

$wsl = Join-Path $env:WINDIR 'System32\wsl.exe'
if (!(Test-Path $wsl)) {
    throw 'wsl.exe not found'
}

$distroQuery = Invoke-NativeCapture $wsl @('-l', '-q')
if ($distroQuery.ExitCode -ne 0) {
    throw "Failed to query installed WSL distros: $($distroQuery.Combined)"
}
$distroList = @()
if (-not [string]::IsNullOrWhiteSpace($distroQuery.StdOut)) {
    $distroList = $distroQuery.StdOut -split "`r?`n"
}
if (-not ($distroList | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $DistroName })) {
    throw "WSL distro '$DistroName' is not installed"
}

$packageDirWsl = To-WslPath $PackageDir
$pluginCacheDirWsl = ""
if (-not [string]::IsNullOrWhiteSpace($PluginCacheDir)) {
    $pluginCacheDirWsl = To-WslPath $PluginCacheDir
}
$bootstrapWsl = "$packageDirWsl/pjarczak_wsl_run_host.sh"

$probe = Invoke-NativeCapture $wsl @('-d', $DistroName, '--user', 'root', '--', 'sh', $bootstrapWsl, '--probe', $packageDirWsl, $pluginCacheDirWsl)
if ($probe.ExitCode -ne 0) {
    $probeText = $probe.Combined
    if ($AllowMissingLinuxPlugin -and $probeText -match 'plugin_not_downloaded') {
        Write-Host 'WSL runtime package OK, linux plugin not downloaded yet.'
        Write-Host $probeText
        exit 0
    }
    throw "WSL runtime probe failed: $probeText"
}

Write-Host 'WSL runtime probe OK'
Write-Host $probe.Combined
