#include "LinuxPluginHost.hpp"
#include "../../src/slic3r/Utils/PJarczakLinuxBridge/PJarczakLinuxSoBridgeRpcProtocol.hpp"

#include <cstdio>
#include <fstream>
#include <iostream>
#include <mutex>
#include <string>
#include <thread>
#include <unistd.h>

using namespace Slic3r::PJarczakLinuxBridge;

int main()
{
    std::ios::sync_with_stdio(false);

    const int rpc_fd = ::dup(STDOUT_FILENO);
    if (rpc_fd < 0)
        return 100;

    std::fflush(stdout);
    ::dup2(STDERR_FILENO, STDOUT_FILENO);

    std::ofstream rpc_out(std::string("/proc/self/fd/") + std::to_string(rpc_fd), std::ios::binary | std::ios::out);
    if (!rpc_out.good())
        return 101;

    LinuxPluginHost host;
    std::mutex out_mutex;
    std::string line;
    while (std::getline(std::cin, line)) {
        if (line.empty())
            continue;

        RpcFrame req;
        std::string err;
        if (!decode_frame(line, req, err)) {
            RpcFrame resp;
            resp.id = 0;
            resp.method = "reply";
            resp.payload = {{"ok", false}, {"error", err}};
            std::lock_guard<std::mutex> lock(out_mutex);
            rpc_out << encode_frame(resp);
            rpc_out.flush();
            continue;
        }

        std::thread([req, &host, &out_mutex, &rpc_out]() {
            RpcFrame resp;
            resp.id = req.id;
            resp.method = "reply";
            resp.payload = host.handle(req.method, req.payload);
            std::lock_guard<std::mutex> lock(out_mutex);
            rpc_out << encode_frame(resp);
            rpc_out.flush();
        }).detach();
    }

    return 0;
}
