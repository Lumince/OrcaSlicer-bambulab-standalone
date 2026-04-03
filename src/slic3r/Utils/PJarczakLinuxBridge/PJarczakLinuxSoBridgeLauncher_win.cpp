#include "PJarczakLinuxSoBridgeLauncher.hpp"
#include "PJarczakLinuxBridgeConfig.hpp"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <string>

namespace Slic3r::PJarczakLinuxBridge {

namespace {

const char* env_value(const char* name)
{
    return std::getenv(name);
}

const char* env_host_cmd()
{
    return env_value("PJARCZAK_LINUX_HOST_CMD");
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

std::string to_wsl_path(std::string path)
{
    std::replace(path.begin(), path.end(), '\\', '/');
    if (path.size() >= 2 && path[1] == ':') {
        const char drive = static_cast<char>(std::tolower(static_cast<unsigned char>(path[0])));
        return std::string("/mnt/") + drive + path.substr(2);
    }
    return path;
}

void append_shell_export(std::string& script, const char* name, const std::string& value)
{
    if (value.empty())
        return;
    script += "export ";
    script += name;
    script += "=";
    script += shell_quote(value);
    script += ";";
}

void append_shell_path_export(std::string& script, const char* name)
{
    const char* value = env_value(name);
    if (!value || !*value)
        return;
    append_shell_export(script, name, to_wsl_path(value));
}

std::string host_runtime_dir_name()
{
    return "pjarczak_bambu_linux_host.runtime";
}

std::string build_shell_prefix()
{
    std::string script = "set -eu;";
    append_shell_path_export(script, "PJARCZAK_BAMBU_PLUGIN_DIR");
    append_shell_path_export(script, "PJARCZAK_BAMBU_NETWORK_SO");
    append_shell_path_export(script, "PJARCZAK_BAMBU_SOURCE_SO");
    append_shell_path_export(script, "PJARCZAK_BAMBU_LIVE555_SO");

    if (const char* version = env_value("PJARCZAK_EXPECTED_BAMBU_NETWORK_VERSION"); version && *version)
        append_shell_export(script, "PJARCZAK_EXPECTED_BAMBU_NETWORK_VERSION", version);

    const std::string runtime_path = to_wsl_path(sibling_binary_path(host_runtime_dir_name()));
    script += "export LD_LIBRARY_PATH=";
    script += shell_quote(runtime_path);
    script += "${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}};";
    return script;
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
    std::string script = build_shell_prefix();

    if (const char* cmd = env_host_cmd(); cmd && *cmd) {
        spec.description = "windows via PJARCZAK_LINUX_HOST_CMD";
        script += cmd;
        spec.argv = {"wsl.exe", "--", "bash", "-lc", script};
        return spec;
    }

    const std::string host_path = to_wsl_path(sibling_binary_path(host_executable_name()));

    script += "HOST=";
    script += shell_quote(host_path);
    script += ";";
    script += "[ -x \"$HOST\" ] || chmod +x \"$HOST\" || true;";
    script += "exec \"$HOST\";";

    spec.description = "windows via WSL";
    spec.argv = {"wsl.exe", "--", "bash", "-lc", script};
    return spec;
}

}
