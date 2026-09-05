# Skeleton Linux-native linkage. This intentionally depends only on
# ubiquitous system libraries so we can focus on getting the project to
# compile; more platform-specific adjustments will follow as we iterate.
if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
  # The engine uses fixed-function desktop OpenGL via GLEW; link the system GL
  # and GLEW so the gl*/glew* symbols resolve in the Linux executable.
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
