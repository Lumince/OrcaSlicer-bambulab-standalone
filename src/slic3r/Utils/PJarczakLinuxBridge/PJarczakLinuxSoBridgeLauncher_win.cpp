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

std::string to_wsl_path(std::string path)
{
    std::replace(path.begin(), path.end(), '\\', '/');
    if (path.size() >= 2 && path[1] == ':') {
        const char drive = static_cast<char>(std::tolower(static_cast<unsigned char>(path[0])));
        return std::string("/mnt/") + drive + path.substr(2);
    }
    return path;
}

std::string host_path_in_distro()
{
    return env_or("PJARCZAK_WSL_HOST_PATH", "/opt/pjarczak/bin/pjarczak_bambu_linux_host");
}

std::string runtime_dir_in_distro()
{
    return env_or("PJARCZAK_WSL_RUNTIME_DIR", "/opt/pjarczak/runtime");
}

std::string wsl_distro_name()
{
    return env_or("PJARCZAK_WSL_DISTRO", "PJARCZAK-BAMBU");
}

std::string wsl_user_name()
{
    return env_or("PJARCZAK_WSL_USER", "root");
}

std::string wsl_shell_path()
{
    return env_or("PJARCZAK_WSL_SHELL", "/bin/sh");
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

std::string build_shell_prefix()
{
    std::string script = "set -eu;";

    append_shell_path_export(script, "PJARCZAK_BAMBU_PLUGIN_DIR");
    append_shell_path_export(script, "PJARCZAK_BAMBU_NETWORK_SO");
    append_shell_path_export(script, "PJARCZAK_BAMBU_SOURCE_SO");
    append_shell_path_export(script, "PJARCZAK_BAMBU_LIVE555_SO");

    if (const char* version = env_value("PJARCZAK_EXPECTED_BAMBU_NETWORK_VERSION"); version && *version)
        append_shell_export(script, "PJARCZAK_EXPECTED_BAMBU_NETWORK_VERSION", version);

    script += "RUNTIME_DIR=";
    script += shell_quote(runtime_dir_in_distro());
    script += ";";
    script += "HOST=";
    script += shell_quote(host_path_in_distro());
    script += ";";
    script += "PLUGIN_DIR=${PJARCZAK_BAMBU_PLUGIN_DIR:-};";
    script += "if [ -z \"${PJARCZAK_BAMBU_NETWORK_SO:-}\" ] && [ -n \"$PLUGIN_DIR\" ]; then export PJARCZAK_BAMBU_NETWORK_SO=\"$PLUGIN_DIR/libbambu_networking.so\"; fi;";
    script += "if [ -z \"${PJARCZAK_BAMBU_SOURCE_SO:-}\" ] && [ -n \"$PLUGIN_DIR\" ]; then export PJARCZAK_BAMBU_SOURCE_SO=\"$PLUGIN_DIR/libBambuSource.so\"; fi;";
    script += "if [ -z \"${PJARCZAK_BAMBU_LIVE555_SO:-}\" ] && [ -n \"$PLUGIN_DIR\" ]; then export PJARCZAK_BAMBU_LIVE555_SO=\"$PLUGIN_DIR/liblive555.so\"; fi;";
    script += "LIB_DIR=\"$RUNTIME_DIR\";";
    script += "if [ -n \"${PJARCZAK_BAMBU_NETWORK_SO:-}\" ]; then LIB_DIR=$(dirname \"$PJARCZAK_BAMBU_NETWORK_SO\"); fi;";
    script += "export LD_LIBRARY_PATH=\"$LIB_DIR:$RUNTIME_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\";";
    script += "[ -x \"$HOST\" ] || chmod +x \"$HOST\" || true;";
    script += "[ -x \"$HOST\" ] || { echo \"missing linux host: $HOST\" 1>&2; exit 127; };";
    script += "if [ -n \"${PJARCZAK_BAMBU_NETWORK_SO:-}\" ] && [ ! -f \"$PJARCZAK_BAMBU_NETWORK_SO\" ]; then echo \"missing libbambu_networking.so: $PJARCZAK_BAMBU_NETWORK_SO\" 1>&2; exit 127; fi;";
    script += "if [ -n \"${PJARCZAK_BAMBU_SOURCE_SO:-}\" ] && [ ! -f \"$PJARCZAK_BAMBU_SOURCE_SO\" ]; then echo \"missing libBambuSource.so: $PJARCZAK_BAMBU_SOURCE_SO\" 1>&2; exit 127; fi;";
    script += "if [ -n \"${PJARCZAK_BAMBU_LIVE555_SO:-}\" ] && [ ! -f \"$PJARCZAK_BAMBU_LIVE555_SO\" ]; then echo \"missing liblive555.so: $PJARCZAK_BAMBU_LIVE555_SO\" 1>&2; exit 127; fi;";
    return script;
}

std::string build_default_shell_script()
{
    std::string script = build_shell_prefix();
    script += "exec \"$HOST\";";
    return script;
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

    if (const char* cmd = env_value("PJARCZAK_LINUX_HOST_CMD"); cmd && *cmd) {
        spec.description = "windows via PJARCZAK_LINUX_HOST_CMD";
        std::string script = build_shell_prefix();
        script += cmd;
        spec.argv = {
            "wsl.exe",
            "--distribution", wsl_distro_name(),
            "--user", wsl_user_name(),
            "--exec", wsl_shell_path(),
            "-lc", script
        };
        return spec;
    }

    spec.description = "windows via WSL distro=" + wsl_distro_name() + " user=" + wsl_user_name();
    spec.argv = {
        "wsl.exe",
        "--distribution", wsl_distro_name(),
        "--user", wsl_user_name(),
        "--exec", wsl_shell_path(),
        "-lc", build_default_shell_script()
    };
    return spec;
}

} // namespace Slic3r::PJarczakLinuxBridge
