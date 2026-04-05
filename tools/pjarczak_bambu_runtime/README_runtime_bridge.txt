PJarczak Linux runtime bridge

Windows:
- The Windows package must contain:
  - pjarczak_bambu_networking_bridge.dll
  - install_runtime.ps1
  - install_runtime.cmd
  - verify_runtime.ps1
  - pjarczak_wsl_run_host.sh
  - pjarczak_wsl_distro.txt
  - pjarczak_bambu_linux_host
  - pjarczak_bambu_linux_host.runtime/
  - windows-wsl2-rootfs.tar
- Run install_runtime.cmd as Administrator to import the WSL runtime distro.
- Run verify_runtime.ps1 after install to validate the runtime package.
- The WSL helper will use linux payload files from:
  - package root
  - pjarczak_bambu_linux_host.runtime/
  - plugin cache directory

Linux:
- Native Linux uses direct host execution and should not use the WSL helper flow.

macOS:
- macOS uses the dedicated wrapper flow and should not use the WSL helper flow.
