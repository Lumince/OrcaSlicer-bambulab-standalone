#include "PJarczakLinuxSoBridgeLauncher.hpp"
#include "PJarczakLinuxBridgeConfig.hpp"

#include <cstdlib>
#include <dlfcn.h>
#include <filesystem>
#include <string>

namespace Slic3r::PJarczakLinuxBridge {

namespace {

std::filesystem::path module_dir()
{
    Dl_info info{};
    if (!dladdr(reinterpret_cast<const void*>(&build_default_launch_spec), &info) || info.dli_fname == nullptr)
        return {};
    return std::filesystem::path(info.dli_fname).parent_path();
}

}

std::string host_executable_name()
{
    return host_executable_file_name();
}

std::string host_pipe_hint()
{
    return "stdio";
}

std::string launch_preflight_error()
{
    const std::filesystem::path plugin_dir = module_dir();
    if (plugin_dir.empty())
        return "bridge launcher could not resolve plugin directory";
    if (!std::filesystem::exists(plugin_dir / host_executable_file_name()))
        return "linux host executable missing in plugin directory";
    const char* runner = std::getenv("PJARCZAK_MAC_LINUX_GUEST_RUNNER");
    if (!runner || !*runner)
        return "PJARCZAK_MAC_LINUX_GUEST_RUNNER is not set";
    return {};
}

LaunchSpec build_default_launch_spec()
{
    const std::filesystem::path plugin_dir = module_dir();

    const char* wrapper_env = std::getenv("PJARCZAK_BAMBU_HOST_WRAPPER");
    const std::filesystem::path wrapper_path = (wrapper_env && *wrapper_env)
        ? std::filesystem::path(wrapper_env)
        : (plugin_dir / mac_host_wrapper_file_name());

    const std::filesystem::path host_path = plugin_dir / host_executable_file_name();

    LaunchSpec spec;
    spec.description = "mac via external linux guest wrapper";
    spec.argv = {wrapper_path.string(), host_path.string()};
    spec.env = {
        {"PJARCZAK_BAMBU_PLUGIN_DIR", plugin_dir.string()},
        {"PJARCZAK_BAMBU_NETWORK_SO", (plugin_dir / linux_network_library_name()).string()},
        {"PJARCZAK_BAMBU_SOURCE_SO", (plugin_dir / linux_source_library_name()).string()},
        {"PJARCZAK_BAMBU_REQUIRE_LINUX_GUEST", "1"}
    };
    return spec;
}

}
