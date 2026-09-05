cmake_minimum_required(VERSION 3.25)

project(MuMain)

cmake_path(GET CMAKE_CURRENT_SOURCE_DIR PARENT_PATH REPO_ROOT)

include("${REPO_ROOT}/cmake/EnsureSubmodule.cmake")

mu_ensure_submodule("ThirdParty/SDL"
  INDICATOR "CMakeLists.txt"
  URL "https://github.com/libsdl-org/SDL.git")

mu_ensure_submodule("ThirdParty/SDL_mixer"
  INDICATOR "CMakeLists.txt"
  URL "https://github.com/libsdl-org/SDL_mixer.git")

set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
set(SDL_INSTALL OFF CACHE BOOL "" FORCE)
add_subdirectory(ThirdParty/SDL EXCLUDE_FROM_ALL)

set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(SDLMIXER_INSTALL OFF CACHE BOOL "" FORCE)
set(SDLMIXER_VENDORED ON CACHE BOOL "" FORCE)
set(SDLMIXER_SAMPLES OFF CACHE BOOL "" FORCE)
set(SDLMIXER_MP3 ON CACHE BOOL "" FORCE)
set(SDLMIXER_MP3_DRMP3 ON CACHE BOOL "" FORCE)
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

if (NOT DEFINED CMAKE_SIZEOF_VOID_P OR CMAKE_SIZEOF_VOID_P EQUAL 0)
  if (CMAKE_CXX_COMPILER MATCHES "x64|amd64|AMD64")
    set(CMAKE_SIZEOF_VOID_P 8 CACHE INTERNAL "Pointer size" FORCE)
  elseif (CMAKE_CXX_COMPILER MATCHES "x86|i386|i686")
    set(CMAKE_SIZEOF_VOID_P 4 CACHE INTERNAL "Pointer size" FORCE)
  else()
    set(CMAKE_SIZEOF_VOID_P 4 CACHE INTERNAL "Pointer size" FORCE)
  endif()
endif()

if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
endif()

option(ENABLE_EDITOR "Enable editor features for admin builds" OFF)

file(GLOB_RECURSE MU_CLIENT_SOURCES CONFIGURE_DEPENDS "source/*.cpp")
list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]Platform[/\\][^/\\]+[/\\][Ww]in[Mm]ain\\.[Cc]pp$")
list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]Platform[/\\][^/\\]+[/\\]main\\.(cpp|mm)$")

if(WIN32)
  list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]GameShop[/\\]FileDownloader[/\\]CurlFileDownloader\\.cpp$")
else()
  list(FILTER MU_CLIENT_SOURCES EXCLUDE REGEX "[/\\]GameShop[/\\]FileDownloader[/\\](FileDownloader|FTPConnecter|HTTPConnecter|DownloadInfo)\\.cpp$")
endif()

if(ENABLE_EDITOR)
  file(GLOB_RECURSE MU_EDITOR_SOURCES CONFIGURE_DEPENDS "MuEditor/*.cpp")
  list(APPEND MU_CLIENT_SOURCES ${MU_EDITOR_SOURCES})
  mu_ensure_submodule("ThirdParty/imgui" INDICATOR "imgui.cpp" URL "https://github.com/ocornut/imgui.git")
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

target_include_directories(MuClient PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/source"
  "${CMAKE_CURRENT_SOURCE_DIR}/source/App"
  "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/netcore/includes"
  "${CMAKE_BINARY_DIR}/generated"
)

target_link_libraries(MuClient PUBLIC SDL3::SDL3 SDL3_mixer::SDL3_mixer)

if(NOT WIN32)
  find_package(CURL REQUIRED)
  target_link_libraries(MuClient PUBLIC CURL::libcurl)
endif()

if(ENABLE_EDITOR)
  target_link_libraries(MuClient PUBLIC imgui)
endif()

if (WIN32)
  target_link_libraries(MuClient PUBLIC
    opengl32 glu32 gdi32 user32 kernel32 winmm imm32
    ole32 oleaut32 uuid comdlg32 advapi32
  )
endif()

# --- Wire-size generated header (WSclient.h includes it) ---------------------
find_program(DOTNET_EXECUTABLE NAMES dotnet.exe dotnet)
set(MU_NUGET_CACHE_DIR "${CMAKE_SOURCE_DIR}/.nuget" CACHE PATH "NuGet package cache")
file(MAKE_DIRECTORY "${MU_NUGET_CACHE_DIR}")

# Match ClientLibrary package version (0.9.9 in this fork).
set(OPENMU_PACKETS_VERSION "0.9.9" CACHE STRING
    "Version of MUnique.OpenMU.Network.Packets for packet XML")
set(OPENMU_PACKETS_XML
    "${MU_NUGET_CACHE_DIR}/munique.openmu.network.packets/${OPENMU_PACKETS_VERSION}/contentFiles/any/net10.0/ServerToClient/ServerToClientPackets.xml")

if (NOT EXISTS "${OPENMU_PACKETS_XML}")
  if (NOT DOTNET_EXECUTABLE)
    message(FATAL_ERROR
      "wire-size codegen needs MUnique.OpenMU.Network.Packets v${OPENMU_PACKETS_VERSION} "
      "but no .NET SDK was found to restore it.")
  endif()
  message(STATUS "Restoring MUnique.OpenMU.Network.Packets v${OPENMU_PACKETS_VERSION}...")
  set(_packets_csproj "${CMAKE_CURRENT_SOURCE_DIR}/../ClientLibrary/MUnique.Client.Library.csproj")
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env
            "NUGET_PACKAGES=${MU_NUGET_CACHE_DIR}"
            "${DOTNET_EXECUTABLE}" restore "${_packets_csproj}" --nologo
    RESULT_VARIABLE _restore_rc
  )
  if (NOT _restore_rc EQUAL 0)
    message(FATAL_ERROR "dotnet restore failed (rc=${_restore_rc})")
  endif()
  if (NOT EXISTS "${OPENMU_PACKETS_XML}")
    message(FATAL_ERROR
      "dotnet restore completed but ServerToClientPackets.xml still missing at\n  ${OPENMU_PACKETS_XML}")
  endif()
endif()

set(WIRE_SIZES_GEN_SCRIPT "${REPO_ROOT}/tools/gen_wire_sizes.py")
set(WIRE_SIZES_GEN_HEADER "${CMAKE_BINARY_DIR}/generated/Network/Server/wire_sizes.generated.h")
find_package(Python3 COMPONENTS Interpreter REQUIRED)
add_custom_command(
  OUTPUT "${WIRE_SIZES_GEN_HEADER}"
  COMMAND "${Python3_EXECUTABLE}" "${WIRE_SIZES_GEN_SCRIPT}"
          --xml "${OPENMU_PACKETS_XML}"
          --source-label "MUnique.OpenMU.Network.Packets v${OPENMU_PACKETS_VERSION} (NuGet)"
          --output "${WIRE_SIZES_GEN_HEADER}"
  DEPENDS "${WIRE_SIZES_GEN_SCRIPT}" "${OPENMU_PACKETS_XML}"
  COMMENT "Generating wire_sizes.generated.h from OpenMU packet XML..."
  VERBATIM
)
add_custom_target(GenWireSizes DEPENDS "${WIRE_SIZES_GEN_HEADER}")
add_dependencies(MuClient GenWireSizes)

add_library(MuClient_whole INTERFACE)
target_link_libraries(MuClient_whole INTERFACE $<LINK_LIBRARY:WHOLE_ARCHIVE,MuClient>)
add_library(MuClient::MuClient ALIAS MuClient_whole)

if (WIN32)
  set(MU_APP_ENTRY "source/App/Platform/Windows/Winmain.cpp")
elseif (APPLE)
  set(MU_APP_ENTRY "source/App/Platform/macOS/main.mm")
elseif (UNIX)
  set(MU_APP_ENTRY
    "source/App/Platform/Linux/main.cpp"
    "source/App/Platform/Windows/Winmain.cpp")
else()
  message(FATAL_ERROR "No executable entry point for this platform.")
endif()

add_executable(Main "${CMAKE_CURRENT_SOURCE_DIR}/${MU_APP_ENTRY}")
target_compile_features(Main PUBLIC cxx_std_20)
target_link_libraries(Main PRIVATE MuClient::MuClient)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set_target_properties(Main PROPERTIES WIN32_EXECUTABLE TRUE)
  enable_language(RC)
  target_sources(Main PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/source/App/Platform/Windows/resource.rc"
  )
endif()

set(ASSETS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bin")
if(IS_DIRECTORY "${ASSETS_DIR}")
  file(GLOB_RECURSE ASSET_FILES CONFIGURE_DEPENDS "${ASSETS_DIR}/*")
  set(ASSETS_STAMP "${CMAKE_CURRENT_BINARY_DIR}/.assets_copied_$<CONFIG>.stamp")
  add_custom_command(
    OUTPUT "${ASSETS_STAMP}"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${ASSETS_DIR}" "$<TARGET_FILE_DIR:Main>"
    COMMAND ${CMAKE_COMMAND} -E touch "${ASSETS_STAMP}"
    DEPENDS ${ASSET_FILES}
    COMMENT "Copying game assets"
    VERBATIM
  )
  add_custom_target(CopyAssets DEPENDS "${ASSETS_STAMP}")
  add_dependencies(Main CopyAssets)
else()
  message(STATUS "Assets directory missing; skipping runtime asset copy")
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

if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/include/gl/glew.h")
  message(WARNING "dependencies/include/gl/glew.h missing — CI should fetch it from upstream MuMain")
endif()
