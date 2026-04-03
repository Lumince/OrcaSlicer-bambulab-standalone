#include "PJarczakLinuxSoBridgeLauncher.hpp"
#include "PJarczakLinuxBridgeConfig.hpp"

#include <cstdlib>

namespace Slic3r::PJarczakLinuxBridge {

namespace {
const char* env_host_cmd()
{
    return std::getenv("PJARCZAK_LINUX_HOST_CMD");
}
}

std::string host_executable_name()
{
    return "pjarczak_bambu_linux_host";
}

std::string host_pipe_hint()
{
    return "stdio";
}

LaunchSpec build_default_launch_spec()
{
    LaunchSpec spec;
    if (const char* cmd = env_host_cmd(); cmd && *cmd) {
        spec.description = "mac via PJARCZAK_LINUX_HOST_CMD";
        spec.argv = {"/bin/sh", "-lc", cmd};
        return spec;
    }
    spec.description = "mac via external linux wrapper";
    spec.argv = {"pjarczak-bambu-linux-host-wrapper", sibling_binary_path(host_executable_name())};
    return spec;
}

}
