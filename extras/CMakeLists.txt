# Version
add_executable(version version.cpp)
target_compile_definitions(version PRIVATE
    PROJECT_NAME="${PROJECT_NAME}"
    VERSION="${VERSION}"
    GIT_REVISION="${GIT_REVISION}"
    DISTRIBUTOR="${DISTRIBUTOR}"
)
install(TARGETS version DESTINATION "${INSTALL_LIBDIR}")

# Boot splash: the Nebula boot scene as a layer surface, up at once when Hyprland starts
# (fills the time until the lock screen's first frame; see boot-splash/main.c)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
pkg_get_variable(WAYLAND_PROTOCOLS_DIR wayland-protocols pkgdatadir)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
set(SPLASH_GEN "${CMAKE_CURRENT_BINARY_DIR}/boot-splash")
file(MAKE_DIRECTORY "${SPLASH_GEN}")
set(SPLASH_PROTOCOLS
    "${CMAKE_CURRENT_SOURCE_DIR}/boot-splash/wlr-layer-shell-unstable-v1.xml"
    "${WAYLAND_PROTOCOLS_DIR}/stable/xdg-shell/xdg-shell.xml"
)
set(SPLASH_SOURCES "")
foreach(xml ${SPLASH_PROTOCOLS})
    get_filename_component(name "${xml}" NAME_WE)
    add_custom_command(
        OUTPUT "${SPLASH_GEN}/${name}-client-protocol.h" "${SPLASH_GEN}/${name}-protocol.c"
        COMMAND "${WAYLAND_SCANNER}" client-header "${xml}" "${SPLASH_GEN}/${name}-client-protocol.h"
        COMMAND "${WAYLAND_SCANNER}" private-code "${xml}" "${SPLASH_GEN}/${name}-protocol.c"
        DEPENDS "${xml}"
        VERBATIM
    )
    list(APPEND SPLASH_SOURCES "${SPLASH_GEN}/${name}-client-protocol.h" "${SPLASH_GEN}/${name}-protocol.c")
endforeach()
add_executable(caelestia-boot-splash boot-splash/main.c ${SPLASH_SOURCES})
set_target_properties(caelestia-boot-splash PROPERTIES C_STANDARD 11 COMPILE_OPTIONS "-O2;-w")
target_include_directories(caelestia-boot-splash PRIVATE "${SPLASH_GEN}")
target_link_libraries(caelestia-boot-splash PRIVATE PkgConfig::WAYLAND_CLIENT m)
install(TARGETS caelestia-boot-splash DESTINATION "${INSTALL_LIBDIR}")

# Fast native boot launcher & deferred Plymouth DRM handoff helper
pkg_check_modules(LIBPNG REQUIRED IMPORTED_TARGET libpng)

add_executable(caelestia-session-boot session/main.c)
set_target_properties(caelestia-session-boot PROPERTIES C_STANDARD 11 COMPILE_OPTIONS "-O2;-Wall")
install(TARGETS caelestia-session-boot DESTINATION "${INSTALL_LIBDIR}")

add_executable(caelestia-plymouth-handoff plymouth-handoff/main.c)
set_target_properties(caelestia-plymouth-handoff PROPERTIES C_STANDARD 11 COMPILE_OPTIONS "-O2;-Wall")
target_link_libraries(caelestia-plymouth-handoff PRIVATE PkgConfig::LIBPNG)
install(TARGETS caelestia-plymouth-handoff DESTINATION "${INSTALL_LIBDIR}")
