param(
    [Parameter(Mandatory = $true)][string]$OutputDir,
    [Parameter(Mandatory = $true)][string]$RootFs,
    [Parameter(Mandatory = $true)][string]$LinuxHostBinary,
    [string]$RuntimeDir = ""
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$toolsRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir '..'))
$wslRoot = Join-Path $toolsRoot 'wsl'

if (-not (Test-Path $RootFs)) { throw "RootFs not found: $RootFs" }
if (-not (Test-Path $LinuxHostBinary)) { throw "LinuxHostBinary not found: $LinuxHostBinary" }
if ($RuntimeDir -and -not (Test-Path $RuntimeDir)) { throw "RuntimeDir not found: $RuntimeDir" }

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir 'rootfs') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir 'linux-runtime') | Out-Null

Copy-Item -Force (Join-Path $wslRoot 'install_runtime.ps1') (Join-Path $OutputDir 'install_runtime.ps1')
Copy-Item -Force (Join-Path $wslRoot 'install_runtime.cmd') (Join-Path $OutputDir 'install_runtime.cmd')
Copy-Item -Force (Join-Path $wslRoot 'verify_runtime.ps1') (Join-Path $OutputDir 'verify_runtime.ps1')
Copy-Item -Force (Join-Path $toolsRoot 'README_runtime_bridge.txt') (Join-Path $OutputDir 'README_runtime_bridge.txt')
Copy-Item -Force $RootFs (Join-Path $OutputDir 'rootfs\pjarczak-bambu-rootfs.tar')
Copy-Item -Force $LinuxHostBinary (Join-Path $OutputDir 'linux-runtime\pjarczak_bambu_linux_host')

if ($RuntimeDir) {
    New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir 'linux-runtime\runtime') | Out-Null
    Copy-Item -Recurse -Force (Join-Path $RuntimeDir '*') (Join-Path $OutputDir 'linux-runtime\runtime')
}

Write-Host 'Bundle created:'
Write-Host $OutputDir
