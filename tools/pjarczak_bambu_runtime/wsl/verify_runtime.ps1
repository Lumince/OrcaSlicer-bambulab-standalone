param(
    [string]$Distro = $(if ($env:PJARCZAK_WSL_DISTRO) { $env:PJARCZAK_WSL_DISTRO } else { 'PJARCZAK-BAMBU' })
)

$ErrorActionPreference = 'Stop'

function Find-WslExe {
    foreach ($candidate in @((Join-Path $env:WINDIR 'System32\wsl.exe'), (Join-Path $env:WINDIR 'Sysnative\wsl.exe'))) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }
    $cmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    throw 'wsl.exe not found'
}

function Step([string]$Name, [scriptblock]$Block) {
    Write-Host ('[' + $Name + ']')
    $global:LASTEXITCODE = 0
    & $Block
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
    Write-Host ''
}

function Step-WslLddStrict([string]$Name, [string]$CommandText) {
    Step $Name {
        $output = & $WslExe --distribution $Distro --user root --exec /bin/sh -lc $CommandText 2>&1
        $exitCode = $LASTEXITCODE
        $text = ($output | Out-String)
        $text = $text.TrimEnd()
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            Write-Host $text
        }
        if ($exitCode -ne 0) {
            throw "$Name failed with exit code $exitCode"
        }
        if ($text -match '(?m)\bnot found\b') {
            throw "$Name reported missing shared libraries"
        }
    }
}

$WslExe = Find-WslExe

Step 'env' {
    Write-Host ('PJARCZAK_WSL_DISTRO=' + $env:PJARCZAK_WSL_DISTRO)
    Write-Host ('PJARCZAK_WSL_USER=' + $env:PJARCZAK_WSL_USER)
    Write-Host ('PJARCZAK_WSL_HOST_PATH=' + $env:PJARCZAK_WSL_HOST_PATH)
    Write-Host ('PJARCZAK_WSL_RUNTIME_DIR=' + $env:PJARCZAK_WSL_RUNTIME_DIR)
}

Step 'wsl-status' {
    & $WslExe --status
}

Step 'wsl-list' {
    & $WslExe -l -v
}

Step 'host-check' {
    & $WslExe --distribution $Distro --user root --exec /bin/sh -lc 'set -eu; test -x /opt/pjarczak/bin/pjarczak_bambu_linux_host; echo HOST_OK'
}

Step 'runtime-check' {
    & $WslExe --distribution $Distro --user root --exec /bin/sh -lc 'set -eu; ls -la /opt/pjarczak/bin; ls -la /opt/pjarczak/runtime || true'
}

Step-WslLddStrict 'ldd' 'set -eu; LD_LIBRARY_PATH=/opt/pjarczak/runtime ldd /opt/pjarczak/bin/pjarczak_bambu_linux_host'

Write-Host 'Verify finished.'
