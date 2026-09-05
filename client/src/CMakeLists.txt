cmake_minimum_required(VERSION 3.25)

project(MuMain)

# Repository root (parent of this src/ directory). Defined here so all
# sibling-directory references (cmake/, ClientLibrary/, etc.) have a
# single, stable anchor instead of scattered "../" navigations.
cmake_path(GET CMAKE_CURRENT_SOURCE_DIR PARENT_PATH REPO_ROOT)

include("${REPO_ROOT}/cmake/EnsureSubmodule.cmake")

mu_ensure_submodule("ThirdParty/SDL"
  INDICATOR "CMakeLists.txt"
  URL "https://github.com/libsdl-org/SDL.git")

mu_ensure_submodule("ThirdParty/SDL_mixer"
  INDICATOR "CMakeLists.txt"
  URL "https://github.com/libsdl-org/SDL_mixer.git")

# SDL3 — static link, no tests, no install
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
set(SDL_INSTALL OFF CACHE BOOL "" FORCE)
add_subdirectory(ThirdParty/SDL EXCLUDE_FROM_ALL)

# SDL3_mixer — static link, MP3 + Ogg Vorbis only (matches our music assets)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(SDLMIXER_INSTALL OFF CACHE BOOL "" FORCE)
set(SDLMIXER_VENDORED ON CACHE BOOL "" FORCE)
set(SDLMIXER_SAMPLES OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MP3 ON CACHE BOOL "" FORCE)
set(SDLMIXER_MP3_DRMP3 ON CACHE BOOL "" FORCE)
# mpg123 is built as a dynamically loaded library — drmp3 alone is enough
# for the assets we ship and keeps everything statically linked.
set(SDLMIXER_MP3_MPG123 OFF CACHE BOOL "" FORCE)
set(SDLMIXER_VORBIS_STB ON CACHE BOOL "" FORCE)
set(SDLMIXER_VORBIS_VORBISFILE OFF CACHE BOOL "" FORCE)
set(SDLMIXER_FLAC OFF CACHE BOOL "" FORCE)
set(SDLMIXER_OPUS OFF CACHE BOOL "" FORCE)
set(SDLMIXER_WAVPACK OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MOD OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MIDI OFF CACHE BOOL "" FORCE)
set(SDLMIXER_GME OFF CACHE BOOL "" FORCE)
add_subdirectory(ThirdParty/SDL_mixer EXCLUDE_FROM_ALL)

# Determine architecture if CMAKE_SIZEOF_VOID_P isn't set
if (NOT DEFINED CMAKE_SIZEOF_VOID_P OR CMAKE_SIZEOF_VOID_P EQUAL 0)
  # Try to detect from compiler path
  if (CMAKE_CXX_COMPILER MATCHES "x64|amd64|AMD64")
    set(CMAKE_SIZEOF_VOID_P 8 CACHE INTERNAL "Pointer size" FORCE)
    message(STATUS "Detected x64 from compiler path, setting CMAKE_SIZEOF_VOID_P=8")
  elseif (CMAKE_CXX_COMPILER MATCHES "x86|i386|i686")
    set(CMAKE_SIZEOF_VOID_P 4 CACHE INTERNAL "Pointer size" FORCE)
    message(STATUS "Detected x86 from compiler path, setting CMAKE_SIZEOF_VOID_P=4")
  else()
    # Default fallback
    set(CMAKE_SIZEOF_VOID_P 4 CACHE INTERNAL "Pointer size" FORCE)
    message(WARNING "Could not detect architecture, defaulting to x86")
  endif()
endif()

# Check architecture and configure accordingly
if (MSVC)
  if (CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(STATUS "Configuring for 64-bit (x64) build")
  else()
    message(STATUS "Configuring for 32-bit (x86) build")
  endif()
endif()

if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING
      "Build type (default RelWithDebInfo for useful symbols)" FORCE)
endif()

# Editor mode option (for admin builds)
option(ENABLE_EDITOR "Enable editor features for admin builds" OFF)

# ---------------------------------------------------------------------------
# Engine/game code -> static library (libMuClient); MuMain -> thin executable.
#
# All engine and game logic compiles into the MuClient static library. The
# Main executable defined further down contains only the platform entry point
# (WinMain) and links the library. Keeping the two separated lets unit-test
# binaries link the same engine code instead of recompiling individual
# translation units, and stops bootstrap-only code from leaking into the
# engine (issue #345).
# ---------------------------------------------------------------------------

# Collect all C++ source files under source/
file(GLOB_RECURSE MU_CLIENT_SOURCES
  CONFIGURE_DEPENDS
        "source/*.cpp"
)

# Per-platform entry points (App/Platform/<OS>/Winmain.cpp, main.cpp, main.mm)
# belong to the executable, not the engine library. Removing them keeps the
# library free of a WinMain/main() so it can be linked into test binaries that
# bring their own entry point, and so a non-Windows entry (e.g. Linux main.cpp)
# does not get globbed into MuClient and collide with the executable's own
# entry symbol at link time. Match only the Platform/<OS>/ entry-file tail, not
# an absolute path: a ${CMAKE_CURRENT_SOURCE_DIR}-built path can differ from
# glob results in drive-letter casing or separators on Windows. This excludes
# only the entry files; other Platform/<OS>/ sources (e.g. Local.cpp) stay in
# the library.
list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]Platform[/\\][^/\\]+[/\\][Ww]in[Mm]ain\\.[Cc]pp$")
list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]Platform[/\\][^/\\]+[/\\]main\\.(cpp|mm)$")

# The in-game shop's catalog downloader is a WinINet/urlmon HTTP+FTP stack on
# Windows (FileDownloader/FTPConnecter/HTTPConnecter/DownloadInfo). Off Windows
# it is replaced by a libcurl implementation (CurlFileDownloader, issue #462).
# Keep only the transport that fits the platform in the build.
if(WIN32)
  list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]GameShop[/\\]FileDownloader[/\\]CurlFileDownloader\\.cpp$")
else()
  list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]GameShop[/\\]FileDownloader[/\\](FileDownloader|FTPConnecter|HTTPConnecter|DownloadInfo)\\.cpp$")
endif()

# Add MuEditor sources when editor is enabled
if(ENABLE_EDITOR)
  file(GLOB_RECURSE MU_EDITOR_SOURCES
    CONFIGURE_DEPENDS
    "MuEditor/*.cpp"
  )
  list(APPEND MU_CLIENT_SOURCES ${MU_EDITOR_SOURCES})
endif()

# ImGui static library (required when editor is enabled)
if(ENABLE_EDITOR)
  mu_ensure_submodule("ThirdParty/imgui"
    INDICATOR "imgui.cpp"
    URL "https://github.com/ocornut/imgui.git")

  add_library(imgui STATIC
    "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/imgui/imgui.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/imgui/imgui_draw.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/imgui/imgui_tables.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/imgui/imgui_widgets.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/imgui/backends/imgui_impl_sdl3.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/imgui/backends/imgui_impl_opengl2.cpp"
  )

  target_include_directories(imgui PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/imgui"
    "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/imgui/backends"
  )

  # The SDL3 ImGui backend (imgui_impl_sdl3.cpp) needs the SDL3 headers; link the
  # target so its include dirs propagate (issue #442).
  target_link_libraries(imgui PUBLIC SDL3::SDL3)

  # The Win32 + OpenGL2 backends call straight into opengl32 (glOrtho,
  # glShadeModel, ...) and dwmapi. Declaring them as PUBLIC dependencies of
  # imgui lets CMake place these libraries *after* libimgui.a on the final
  # link line, which MinGW's order-sensitive linker requires. Restrict to
  # Windows non-MSVC (MinGW): these are Windows-only libraries, and MSVC links
  # them elsewhere and ignores order anyway.
  if (WIN32 AND NOT MSVC)
    target_link_libraries(imgui PUBLIC opengl32 dwmapi)
  endif()

  # <-- Force C++20 for ImGui here
  target_compile_features(imgui PUBLIC cxx_std_20)
endif()

# Engine/game code as a static library. Compile- and link-time usage
# requirements (C++20, include paths, definitions, third-party libraries) are
# attached PUBLIC below so both the Main executable and any test binary that
# links MuClient inherit them automatically.
add_library(MuClient STATIC ${MU_CLIENT_SOURCES})
target_compile_features(MuClient PUBLIC cxx_std_20)

# The in-game shop downloader uses libcurl off Windows (issue #462); on Windows
# it uses the OS WinINet/urlmon stack and needs no extra dependency here.
if(NOT WIN32)
  find_package(CURL REQUIRED)
  target_link_libraries(MuClient PUBLIC CURL::libcurl)
endif()

# The engine relies on self-registering globals whose constructors get
# silently dropped if the linker only pulls archive members on demand, so
# every consumer must link MuClient with WHOLE_ARCHIVE. Rather than make each
# consumer remember that, MuClient::MuClient is an interface wrapper that
# carries the WHOLE_ARCHIVE requirement (and, transitively, all of MuClient's
# public compile/link properties). Executables and unit tests just link
# MuClient::MuClient; link the raw MuClient target directly only when an
# on-demand link is genuinely wanted.
add_library(MuClient_whole INTERFACE)
target_link_libraries(MuClient_whole INTERFACE $<LINK_LIBRARY:WHOLE_ARCHIVE,MuClient>)
add_library(MuClient::MuClient ALIAS MuClient_whole)

# Thin executable: platform bootstrap only, links the engine library. The
# executable shell's sources live under source/App/ (see issue #346). The entry
# point is selected per platform (issue #441): each OS keeps its bootstrap under
# source/App/Platform/<OS>/, so adding a platform is a new entry file plus a
# branch here, not a CMake rewrite. Only the Windows entry point exists today;
# the Linux/macOS sources are added when that work starts.
#
# Unsupported platforms fail loudly rather than silently selecting the Linux
# entry: the mobile targets need a different entry model and a renderer port
# (the engine uses fixed-function desktop OpenGL), so quietly compiling a
# desktop main() for them would be wrong. iOS is matched before the generic
# APPLE/macOS branch, and Android before the generic UNIX/Linux branch.
if (WIN32)
  set(MU_APP_ENTRY "source/App/Platform/Windows/Winmain.cpp")
elseif (CMAKE_SYSTEM_NAME STREQUAL "iOS")
  message(FATAL_ERROR "iOS is not a supported build target yet: it needs an "
    "OpenGL ES/Metal renderer port and a touch UI, and distribution is App "
    "Store restricted. When that work starts, add source/App/Platform/iOS/ "
    "and replace this branch.")
elseif (APPLE)
  set(MU_APP_ENTRY "source/App/Platform/macOS/main.mm")
elseif (ANDROID)
  message(FATAL_ERROR "Android is not a supported build target yet: it needs "
    "an OpenGL ES renderer port, and its entry point is android_main via "
    "native_app_glue built as a shared library, not an executable. When that "
    "work starts, add source/App/Platform/Android/ and replace this branch.")
elseif (UNIX)
  # Linux entry (main.cpp) plus the shared bootstrap/game-loop from Winmain.cpp,
  # which now compiles off Windows (issue #462). main() calls into it.
  set(MU_APP_ENTRY
    "source/App/Platform/Linux/main.cpp"
    "source/App/Platform/Windows/Winmain.cpp")
else()
  message(FATAL_ERROR "No executable entry point defined for this platform "
    "(CMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}). Add source/App/Platform/<OS>/ "
    "and a branch above.")
endif()

add_executable(Main
  "${CMAKE_CURRENT_SOURCE_DIR}/${MU_APP_ENTRY}"
)
target_compile_features(Main PUBLIC cxx_std_20)
target_link_libraries(Main PRIVATE MuClient::MuClient)

if (NOT MSVC)
  set(MU_MAIN_MAP_FILE "${CMAKE_CURRENT_BINARY_DIR}/Main.map")
  target_link_options(Main PRIVATE "-Wl,-Map,${MU_MAIN_MAP_FILE}")
endif()

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
  # Build as a Windows GUI application (no console window) and let CMake
  # add the default system libraries like kernel32, user32, gdi32, etc.
  message(STATUS "=== DEBUG: CMAKE_CURRENT_SOURCE_DIR = ${CMAKE_CURRENT_SOURCE_DIR}")
  message(STATUS "=== DEBUG: CMAKE_CURRENT_BINARY_DIR = ${CMAKE_CURRENT_BINARY_DIR}")
  message(STATUS "=== DEBUG: CMAKE_BINARY_DIR = ${CMAKE_BINARY_DIR}")
  message(STATUS "=== DEBUG: Executable will be at: $<TARGET_FILE:Main>")
  message(STATUS "=== DEBUG: Executable directory: $<TARGET_FILE_DIR:Main>")
  set_target_properties(Main PROPERTIES
    WIN32_EXECUTABLE TRUE
  )

  enable_language(RC)
  target_sources(Main PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/source/App/Platform/Windows/resource.rc"
  )
endif()

# Copy assets directory next to executable when present.
# Source-only checkouts intentionally do not ship proprietary runtime assets
# (client/src/bin). Skip the copy in that case so CI source builds succeed.
set(ASSETS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bin")
message(STATUS "=== DEBUG: Assets directory: ${ASSETS_DIR}")
if(IS_DIRECTORY "${ASSETS_DIR}")
  file(GLOB_RECURSE ASSET_FILES CONFIGURE_DEPENDS "${ASSETS_DIR}/*")
  # $<CONFIG> in the stamp name keeps multi-config generators (Visual
  # Studio, Xcode) honest: each configuration's output directory needs
  # its own stamp, otherwise switching from Debug to Release would see
  # the Debug stamp and skip the copy, leaving the Release dir empty.
  set(ASSETS_STAMP "${CMAKE_CURRENT_BINARY_DIR}/.assets_copied_$<CONFIG>.stamp")
  add_custom_command(
    OUTPUT "${ASSETS_STAMP}"
    COMMAND ${CMAKE_COMMAND} -E echo "=== Copying assets from ${ASSETS_DIR} to $<TARGET_FILE_DIR:Main>"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${ASSETS_DIR}"
            "$<TARGET_FILE_DIR:Main>"
    COMMAND ${CMAKE_COMMAND} -E touch "${ASSETS_STAMP}"
    DEPENDS ${ASSET_FILES}
    COMMENT "Copying game assets (sources changed)"
    VERBATIM
  )
  add_custom_target(CopyAssets DEPENDS "${ASSETS_STAMP}")
  add_dependencies(Main CopyAssets)
else()
  message(STATUS "=== DEBUG: Assets directory missing; skipping runtime asset copy (source-only build)")
endif()

# Seed config.ini from the template only when the runtime asset exists.
# Source-only checkouts intentionally do not ship game runtime assets.
if(EXISTS "${ASSETS_DIR}/config.ini.template")
  add_custom_command(TARGET Main POST_BUILD
    COMMAND "${CMAKE_COMMAND}"
      "-DINPUT=${ASSETS_DIR}/config.ini.template"
      "-DOUTPUT=$<TARGET_FILE_DIR:Main>/config.ini"
      "-P" "${REPO_ROOT}/cmake/SeedConfigIfMissing.cmake"
    VERBATIM
  )
endif()
