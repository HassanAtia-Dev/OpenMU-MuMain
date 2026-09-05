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
  if (CMAKE_CXX_COMPILER MATCHES "x64|amd64|AMD64")
    set(CMAKE_SIZEOF_VOID_P 8 CACHE INTERNAL "Pointer size" FORCE)
    message(STATUS "Detected x64 from compiler path, setting CMAKE_SIZEOF_VOID_P=8")
  elseif (CMAKE_CXX_COMPILER MATCHES "x86|i386|i686")
    set(CMAKE_SIZEOF_VOID_P 4 CACHE INTERNAL "Pointer size" FORCE)
    message(STATUS "Detected x86 from compiler path, setting CMAKE_SIZEOF_VOID_P=4")
  else()
    set(CMAKE_SIZEOF_VOID_P 4 CACHE INTERNAL "Pointer size" FORCE)
    message(WARNING "Could not detect architecture, defaulting to x86")
  endif()
endif()

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

option(ENABLE_EDITOR "Enable editor features for admin builds" OFF)

file(GLOB_RECURSE MU_CLIENT_SOURCES
  CONFIGURE_DEPENDS
        "source/*.cpp"
)

list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]Platform[/\\][^/\\]+[/\\][Ww]in[Mm]ain\\.[Cc]pp$")
list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]Platform[/\\][^/\\]+[/\\]main\\.(cpp|mm)$")

if(WIN32)
  list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]GameShop[/\\]FileDownloader[/\\]CurlFileDownloader\\.cpp$")
else()
  list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]GameShop[/\\]FileDownloader[/\\](FileDownloader|FTPConnecter|HTTPConnecter|DownloadInfo)\\.cpp$")
endif()

if(ENABLE_EDITOR)
  file(GLOB_RECURSE MU_EDITOR_SOURCES
    CONFIGURE_DEPENDS
    "MuEditor/*.cpp"
  )
  list(APPEND MU_CLIENT_SOURCES ${MU_EDITOR_SOURCES})
endif()

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
  target_link_libraries(imgui PUBLIC SDL3::SDL3)
  if (WIN32 AND NOT MSVC)
    target_link_libraries(imgui PUBLIC opengl32 dwmapi)
  endif()
  target_compile_features(imgui PUBLIC cxx_std_20)
endif()

add_library(MuClient STATIC ${MU_CLIENT_SOURCES})
target_compile_features(MuClient PUBLIC cxx_std_20)

if(NOT WIN32)
  find_package(CURL REQUIRED)
  target_link_libraries(MuClient PUBLIC CURL::libcurl)
endif()

add_library(MuClient_whole INTERFACE)
target_link_libraries(MuClient_whole INTERFACE $<LINK_LIBRARY:WHOLE_ARCHIVE,MuClient>)
add_library(MuClient::MuClient ALIAS MuClient_whole)

if (WIN32)
  set(MU_APP_ENTRY "source/App/Platform/Windows/Winmain.cpp")
elseif (CMAKE_SYSTEM_NAME STREQUAL "iOS")
  message(FATAL_ERROR "iOS is not a supported build target yet.")
elseif (APPLE)
  set(MU_APP_ENTRY "source/App/Platform/macOS/main.mm")
elseif (ANDROID)
  message(FATAL_ERROR "Android is not a supported build target yet.")
elseif (UNIX)
  set(MU_APP_ENTRY
    "source/App/Platform/Linux/main.cpp"
    "source/App/Platform/Windows/Winmain.cpp")
else()
  message(FATAL_ERROR "No executable entry point defined for this platform.")
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
  set_target_properties(Main PROPERTIES WIN32_EXECUTABLE TRUE)
  enable_language(RC)
  target_sources(Main PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/source/App/Platform/Windows/resource.rc"
  )
endif()

# Copy assets when present (source-only builds skip proprietary runtime assets).
set(ASSETS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bin")
message(STATUS "=== DEBUG: Assets directory: ${ASSETS_DIR}")
if(IS_DIRECTORY "${ASSETS_DIR}")
  file(GLOB_RECURSE ASSET_FILES CONFIGURE_DEPENDS "${ASSETS_DIR}/*")
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

if(EXISTS "${ASSETS_DIR}/config.ini.template")
  add_custom_command(TARGET Main POST_BUILD
    COMMAND "${CMAKE_COMMAND}"
      "-DINPUT=${ASSETS_DIR}/config.ini.template"
      "-DOUTPUT=$<TARGET_FILE_DIR:Main>/config.ini"
      "-P" "${REPO_ROOT}/cmake/SeedConfigIfMissing.cmake"
    VERBATIM
  )
endif()

# Remainder: Linux linkage, .NET ClientLibrary, Windows system libs, etc.
include("${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists.rest.cmake")
