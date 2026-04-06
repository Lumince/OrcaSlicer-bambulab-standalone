PJarczak Linux runtime bridge

Windows package should contain at minimum:
- pjarczak_bambu_networking_bridge.dll
- pjarczak_bambu_linux_host
- install_runtime.ps1
- install_runtime.cmd
- verify_runtime.ps1
- pjarczak_wsl_run_host.sh
- pjarczak_wsl_distro.txt
- windows-wsl2-rootfs.tar

Optional runtime payload directory:
- pjarczak_bambu_linux_host.runtime/

Optional plugin cache payloads looked up by the WSL helper:
- libbambu_networking.so
- libBambuSource.so
- liblive555.so
- linux_payload_manifest.json

Linux:
- Native Linux uses direct host execution and should not use the WSL helper flow.

macOS:
- macOS uses the dedicated wrapper flow and should not use the WSL helper flow.
