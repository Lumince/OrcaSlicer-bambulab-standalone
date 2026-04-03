#include "PJarczakLinuxSoBridgeLauncher.hpp"
#include "PJarczakLinuxBridgeConfig.hpp"

#include <algorithm>
#include <cctype>
#include <cstdlib>

namespace Slic3r::PJarczakLinuxBridge {

namespace {

const char* env_host_cmd()
{
    return std::getenv("PJARCZAK_LINUX_HOST_CMD");
}

std::string shell_quote(const std::string& value)
{
    std::string out = "'";
    for (char ch : value) {
        if (ch == '\'')
            out += "'\''";
        else
            out += ch;
    }
    out += "'";
    return out;
}

std::string to_wsl_path(std::string path)
{
    std::replace(path.begin(), path.end(), '\\', '/');
    if (path.size() >= 2 && path[1] == ':') {
        const char drive = static_cast<char>(std::tolower(static_cast<unsigned char>(path[0])));
        return std::string("/mnt/") + drive + path.substr(2);
    }
    return path;
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
        spec.description = "windows via PJARCZAK_LINUX_HOST_CMD";
        spec.argv = {"wsl.exe", "--", "bash", "-lc", cmd};
        return spec;
    }

    spec.description = "windows via WSL";
    spec.argv = {"wsl.exe", "--", "bash", "-lc", shell_quote(to_wsl_path(sibling_binary_path(host_executable_name())))};
    return spec;
}

}
