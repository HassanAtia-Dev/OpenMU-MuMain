# Auto-included remainder of client/src/CMakeLists.txt

# Critical include paths — required for #include "stdafx.h" and vendored headers.
target_include_directories(MuClient PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/source"
  # source/App holds stdafx.h (PCH). Bare #include "stdafx.h" needs this path.
  "${CMAKE_CURRENT_SOURCE_DIR}/source/App"
  "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/netcore/includes"
  "${CMAKE_BINARY_DIR}/generated"
)

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

# Warn if vendored dependencies (GLEW headers, turbojpeg, ...) are missing.
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/dependencies/include/gl/glew.h")
  message(WARNING
    "client/src/dependencies/ is missing (expected gl/glew.h). "
    "Copy it from upstream MuMain: https://github.com/sven-n/MuMain/tree/main/src/dependencies")
endif()
