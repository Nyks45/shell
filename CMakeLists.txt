cmake_minimum_required(VERSION 3.19)

if(NOT DEFINED VERSION)
    execute_process(COMMAND git describe --tags --abbrev=0
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if("${VERSION}" STREQUAL "")
        message(FATAL_ERROR "VERSION is not set and failed to get from git")
    endif()
endif()

if(NOT DEFINED GIT_REVISION)
    execute_process(COMMAND git rev-parse HEAD
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE GIT_REVISION
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if("${GIT_REVISION}" STREQUAL "")
        message(FATAL_ERROR "GIT_REVISION is not set and failed to get from git")
    endif()
endif()

string(REGEX REPLACE "^v" "" VERSION "${VERSION}")

project(caelestia-shell VERSION ${VERSION} LANGUAGES C CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

set(DISTRIBUTOR "Unset" CACHE STRING "Distributor")
set(ENABLE_MODULES "extras;plugin;shell" CACHE STRING "Modules to build/install")
set(INSTALL_LIBDIR "${CMAKE_INSTALL_LIBDIR}/caelestia" CACHE STRING "Library install dir")
set(INSTALL_QMLDIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE STRING "QML install dir")
set(INSTALL_QSCONFDIR "${CMAKE_INSTALL_SYSCONFDIR}/xdg/quickshell/caelestia" CACHE STRING "Quickshell config install dir")
set(INSTALL_APPDIR "${CMAKE_INSTALL_DATADIR}/applications" CACHE STRING "Desktop entry install dir")

add_compile_definitions(
    QT_NO_CAST_FROM_ASCII
    QT_NO_CAST_TO_ASCII
    QT_NO_CAST_FROM_BYTEARRAY
)

add_compile_options(
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion
    -Wold-style-cast -Wnull-dereference -Wdouble-promotion
    -Wformat=2 -Wfloat-equal -Woverloaded-virtual
    -Wsign-conversion -Wredundant-decls -Wswitch
    -Wunreachable-code
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wunused-lambda-capture -Wno-nonportable-include-path)
endif()

if("extras" IN_LIST ENABLE_MODULES)
    add_subdirectory(extras)
endif()

if("plugin" IN_LIST ENABLE_MODULES)
    add_subdirectory(plugin)
endif()

if("shell" IN_LIST ENABLE_MODULES)
    find_program(QSB_EXECUTABLE NAMES qsb PATHS /usr/lib/qt6/bin REQUIRED)
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/assets/shaders")
    add_custom_command(
        OUTPUT "${CMAKE_BINARY_DIR}/assets/shaders/liquid.frag.qsb"
        COMMAND "${QSB_EXECUTABLE}" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "${CMAKE_BINARY_DIR}/assets/shaders/liquid.frag.qsb" "${CMAKE_SOURCE_DIR}/assets/shaders/liquid.frag"
        DEPENDS "${CMAKE_SOURCE_DIR}/assets/shaders/liquid.frag"
        COMMENT "Compiling liquid.frag shader"
        VERBATIM
    )
    add_custom_target(shell_shaders ALL DEPENDS "${CMAKE_BINARY_DIR}/assets/shaders/liquid.frag.qsb")

    foreach(dir assets components daemons modules services utils)
        install(DIRECTORY ${dir} DESTINATION "${INSTALL_QSCONFDIR}")
    endforeach()

    install(FILES "${CMAKE_BINARY_DIR}/assets/shaders/liquid.frag.qsb" DESTINATION "${INSTALL_QSCONFDIR}/assets/shaders")

    install(PROGRAMS assets/wrap_term_launch.sh assets/live-wallpaper assets/caelestia-session DESTINATION "${INSTALL_QSCONFDIR}/assets")

    # The settings' root helper (named actions only) and its polkit action: the
    # shell's own password prompt, remembered for a few minutes
    install(PROGRAMS assets/caelestia-admin assets/caelestia-set-password assets/caelestia-disks assets/caelestia-system assets/caelestia-packages assets/caelestia-gaming assets/caelestia-devices assets/caelestia-fans assets/caelestia-session DESTINATION "${INSTALL_LIBDIR}")
    install(FILES assets/systemd-user/caelestia-openrgb.service assets/systemd-user/caelestia-devices.service DESTINATION "${CMAKE_INSTALL_LIBDIR}/systemd/user")
    install(FILES assets/systemd/caelestia-login.service DESTINATION "${CMAKE_INSTALL_LIBDIR}/systemd/system")
    install(FILES assets/pam.d/caelestia-login DESTINATION "${CMAKE_INSTALL_SYSCONFDIR}/pam.d")
    install(FILES assets/org.caelestia.shell.admin.policy DESTINATION "${CMAKE_INSTALL_DATADIR}/polkit-1/actions")

    # The settings app (Nexus) in app launchers
    install(FILES assets/caelestia-settings.desktop DESTINATION "${INSTALL_APPDIR}")

    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/shell.qml")
    file(READ shell.qml SHELL_QML)
    string(REPLACE "settings.watchFiles: true" "settings.watchFiles: false" SHELL_QML "${SHELL_QML}")
    file(WRITE "${CMAKE_BINARY_DIR}/qml/shell.qml" "${SHELL_QML}")
    install(FILES "${CMAKE_BINARY_DIR}/qml/shell.qml" DESTINATION "${INSTALL_QSCONFDIR}")

    install(FILES LICENSE DESTINATION "${INSTALL_QSCONFDIR}")
endif()
