set(PJARCZAK_LINUX_BRIDGE_SOURCES
    ${CMAKE_CURRENT_LIST_DIR}/PJarczakLinuxBridgeConfig.cpp
    ${CMAKE_CURRENT_LIST_DIR}/PJarczakLinuxSoBridgeRpcProtocol.cpp
    ${CMAKE_CURRENT_LIST_DIR}/PJarczakLinuxSoBridgeRpcClient.cpp
    ${CMAKE_CURRENT_LIST_DIR}/PJarczakLinuxSoBridgeEventPump.cpp
    ${CMAKE_CURRENT_LIST_DIR}/PJarczakBambuNetworkForwarderState.cpp
    ${CMAKE_CURRENT_LIST_DIR}/PJarczakBambuNetworkForwarderExports.cpp
)

if (WIN32)
    list(APPEND PJARCZAK_LINUX_BRIDGE_SOURCES ${CMAKE_CURRENT_LIST_DIR}/PJarczakLinuxSoBridgeLauncher_win.cpp)
elseif (APPLE)
    list(APPEND PJARCZAK_LINUX_BRIDGE_SOURCES ${CMAKE_CURRENT_LIST_DIR}/PJarczakLinuxSoBridgeLauncher_mac.mm)
else()
    list(APPEND PJARCZAK_LINUX_BRIDGE_SOURCES ${CMAKE_CURRENT_LIST_DIR}/PJarczakLinuxSoBridgeLauncher_linux.cpp)
endif()

add_library(pjarczak_bambu_networking_bridge SHARED ${PJARCZAK_LINUX_BRIDGE_SOURCES})
target_include_directories(pjarczak_bambu_networking_bridge PRIVATE ${CMAKE_CURRENT_LIST_DIR}/../../..)
target_link_libraries(pjarczak_bambu_networking_bridge PRIVATE boost_headeronly boost_libs OpenSSL::Crypto)
set_target_properties(pjarczak_bambu_networking_bridge PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}"
)

install(TARGETS pjarczak_bambu_networking_bridge
    RUNTIME DESTINATION "."
    LIBRARY DESTINATION "."
)

if (UNIX AND NOT APPLE)
    add_executable(pjarczak_bambu_linux_host
        ${CMAKE_SOURCE_DIR}/tools/pjarczak_bambu_linux_host/main.cpp
        ${CMAKE_SOURCE_DIR}/tools/pjarczak_bambu_linux_host/LinuxPluginHost.cpp
        ${CMAKE_CURRENT_LIST_DIR}/PJarczakLinuxSoBridgeRpcProtocol.cpp
    )
    target_include_directories(pjarczak_bambu_linux_host PRIVATE ${CMAKE_SOURCE_DIR}/src)
    target_link_libraries(pjarczak_bambu_linux_host PRIVATE boost_headeronly boost_libs ${CMAKE_DL_LIBS} OpenSSL::Crypto)
    target_link_options(pjarczak_bambu_linux_host PRIVATE -static-libstdc++ -static-libgcc)
    set_target_properties(pjarczak_bambu_linux_host PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}"
    )
    install(TARGETS pjarczak_bambu_linux_host
        RUNTIME DESTINATION "."
    )
endif()

if (APPLE)
    set(PJARCZAK_MAC_WRAPPER_SCRIPT_SOURCE ${CMAKE_SOURCE_DIR}/tools/pjarczak_bambu_macos_linux_wrapper/pjarczak_bambu_macos_linux_wrapper.sh)
    add_custom_command(TARGET pjarczak_bambu_networking_bridge POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${PJARCZAK_MAC_WRAPPER_SCRIPT_SOURCE}
            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/pjarczak_bambu_macos_linux_wrapper.sh
    )
    install(FILES ${PJARCZAK_MAC_WRAPPER_SCRIPT_SOURCE}
        DESTINATION "."
        RENAME pjarczak_bambu_macos_linux_wrapper.sh
    )
endif()

if (WIN32)
    set(PJARCZAK_WSL_HELPER_SOURCE ${CMAKE_SOURCE_DIR}/tools/pjarczak_bambu_runtime/wsl/pjarczak_wsl_run_host.sh)
    set(PJARCZAK_WSL_INSTALLER_SOURCE ${CMAKE_SOURCE_DIR}/tools/pjarczak_bambu_runtime/wsl/install_runtime.ps1)
    set(PJARCZAK_WSL_INSTALLER_CMD_SOURCE ${CMAKE_SOURCE_DIR}/tools/pjarczak_bambu_runtime/wsl/install_runtime.cmd)
    set(PJARCZAK_WSL_VERIFY_SOURCE ${CMAKE_SOURCE_DIR}/tools/pjarczak_bambu_runtime/wsl/verify_runtime.ps1)
    set(PJARCZAK_RUNTIME_README_SOURCE ${CMAKE_SOURCE_DIR}/tools/pjarczak_bambu_runtime/README_runtime_bridge.txt)
    add_custom_command(TARGET pjarczak_bambu_networking_bridge POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${PJARCZAK_WSL_HELPER_SOURCE}
            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/pjarczak_wsl_run_host.sh
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${PJARCZAK_WSL_INSTALLER_SOURCE}
            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/install_runtime.ps1
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${PJARCZAK_WSL_INSTALLER_CMD_SOURCE}
            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/install_runtime.cmd
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${PJARCZAK_WSL_VERIFY_SOURCE}
            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/verify_runtime.ps1
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${PJARCZAK_RUNTIME_README_SOURCE}
            ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/README_runtime_bridge.txt
    )
    install(FILES
        ${PJARCZAK_WSL_HELPER_SOURCE}
        ${PJARCZAK_WSL_INSTALLER_SOURCE}
        ${PJARCZAK_WSL_INSTALLER_CMD_SOURCE}
        ${PJARCZAK_WSL_VERIFY_SOURCE}
        ${PJARCZAK_RUNTIME_README_SOURCE}
        DESTINATION "."
    )
endif()
