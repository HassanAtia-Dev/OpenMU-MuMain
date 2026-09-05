# Auto-included remainder of client/src/CMakeLists.txt (restored after accidental truncation).
# Skeleton Linux-native linkage. This intentionally depends only on
# ubiquitous system libraries so we can focus on getting the project to
# compile; more platform-specific adjustments will follow as we iterate.
if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
  find_package(OpenGL REQUIRED)
  find_library(GLEW_LIBRARY NAMES GLEW glew32 REQUIRED)
  find_library(TURBOJPEG_LIBRARY NAMES turbojpeg REQUIRED)
  target_link_libraries(MuClient PUBLIC
    pthread
    dl
    m
    OpenGL::GL
    OpenGL::GLU
    ${GLEW_LIBRARY}
    ${TURBOJPEG_LIBRARY}
  )
endif()

# --- .NET / NuGet infrastructure (shared by wire-sizes codegen and ClientLibrary)
if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
  find_program(DOTNET_EXECUTABLE dotnet)
  if (NOT DOTNET_EXECUTABLE)
    find_program(DOTNET_EXECUTABLE dotnet.exe)
  endif()
else()
  find_program(DOTNET_EXECUTABLE dotnet.exe)
  if (NOT DOTNET_EXECUTABLE)
    find_program(DOTNET_EXECUTABLE dotnet)
  endif()
endif()

function(mu_native_path input_path output_var)
  if (DOTNET_EXECUTABLE MATCHES "\\.exe$" AND CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    execute_process(
      COMMAND wslpath -w "${input_path}"
      OUTPUT_VARIABLE native_path
      RESULT_VARIABLE rc
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if (rc EQUAL 0)
      set(${output_var} "${native_path}" PARENT_SCOPE)
    else()
      message(FATAL_ERROR "wslpath failed for '${input_path}'. Ensure wslpath is available.")
    endif()
  else()
    set(${output_var} "${input_path}" PARENT_SCOPE)
  endif()
endfunction()

set(MU_NUGET_CACHE_DIR "${CMAKE_SOURCE_DIR}/.nuget" CACHE PATH "NuGet package cache directory")
file(MAKE_DIRECTORY "${MU_NUGET_CACHE_DIR}")

set(OPENMU_PACKETS_VERSION "0.9.9" CACHE STRING
    "Version of MUnique.OpenMU.Network.Packets to source packet XML from")
set(OPENMU_PACKETS_XML
    "${MU_NUGET_CACHE_DIR}/munique.openmu.network.packets/${OPENMU_PACKETS_VERSION}/contentFiles/any/net10.0/ServerToClient/ServerToClientPackets.xml")

if (NOT EXISTS "${OPENMU_PACKETS_XML}")
  if (NOT DOTNET_EXECUTABLE)
    message(FATAL_ERROR
      "wire-size codegen needs MUnique.OpenMU.Network.Packets v${OPENMU_PACKETS_VERSION} "
      "but it is not cached and no .NET SDK was found.")
  endif()
  message(STATUS "Restoring MUnique.OpenMU.Network.Packets v${OPENMU_PACKETS_VERSION}...")
  set(_packets_csproj "${CMAKE_CURRENT_SOURCE_DIR}/../ClientLibrary/MUnique.Client.Library.csproj")
  mu_native_path("${_packets_csproj}" _packets_csproj_native)
  mu_native_path("${MU_NUGET_CACHE_DIR}" _packets_nuget_native)
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E env
            "WSLENV=NUGET_PACKAGES/w"
            "NUGET_PACKAGES=${_packets_nuget_native}"
            "${DOTNET_EXECUTABLE}" restore "${_packets_csproj_native}"
            --packages "${_packets_nuget_native}"
    RESULT_VARIABLE _restore_rc
  )
  if (NOT _restore_rc EQUAL 0)
    message(FATAL_ERROR "Failed to restore MUnique.OpenMU.Network.Packets")
  endif()
endif()

# Link SDL3 + SDL3_mixer on all platforms.
target_link_libraries(MuClient PUBLIC
  SDL3::SDL3
  SDL3_mixer::SDL3_mixer
)

if(ENABLE_EDITOR)
  target_link_libraries(MuClient PUBLIC imgui)
endif()

if (WIN32)
  target_link_libraries(MuClient PUBLIC
    opengl32
    glu32
    gdi32
    user32
    kernel32
    winmm
    imm32
    ole32
    oleaut32
    uuid
    comdlg32
    advapi32
  )
endif()
