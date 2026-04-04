#include "PJarczakLinuxSoBridgeLauncher.hpp"
#include "PJarczakLinuxBridgeConfig.hpp"

#include <cstdlib>

namespace Slic3r::PJarczakLinuxBridge {

namespace {

const char* env_value(const char* name)
{
    return std::getenv(name);
}

std::string env_or(const char* name, const char* fallback)
{
    if (const char* v = env_value(name); v && *v)
        return v;
    return fallback;
}

std::string shell_quote(const std::string& value)
{
    std::string out = "'";
    for (char ch : value) {
        if (ch == '\'')
            out += "'\\''";
        else
            out += ch;
    }
    out += "'";
    return out;
}

std::string wrapper_script_name()
{
    return "pjarczak_bambu_macos_linux_wrapper.sh";
}

} // namespace

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
    if (const char* cmd = env_value("PJARCZAK_MAC_LINUX_WRAPPER_CMD"); cmd && *cmd) {
        spec.description = "mac via PJARCZAK_MAC_LINUX_WRAPPER_CMD";
        spec.argv = {"/bin/sh", "-lc", cmd};
        return spec;
    }

    const std::string wrapper = sibling_binary_path(wrapper_script_name());
    const std::string host = sibling_binary_path(host_executable_name());
    const std::string runtime_dir_default = sibling_binary_path("pjarczak_bambu_linux_host.runtime");
    const std::string runtime_dir = env_or("PJARCZAK_MAC_RUNTIME_DIR", runtime_dir_default.c_str());
    const std::string plugin_dir = env_or("PJARCZAK_BAMBU_PLUGIN_DIR", "");

    std::string cmd;
    cmd += "exec ";
    cmd += shell_quote(wrapper);
    cmd += " ";
    cmd += shell_quote(host);
    cmd += " ";
    cmd += shell_quote(runtime_dir);
    cmd += " ";
    cmd += shell_quote(plugin_dir);

    spec.description = "mac via wrapper script";
    spec.argv = {"/bin/sh", "-lc", cmd};
    return spec;
}

} // namespace Slic3r::PJarczakLinuxBridge
