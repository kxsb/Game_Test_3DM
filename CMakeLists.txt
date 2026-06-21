cmake_minimum_required(VERSION 3.16)
project(montpellier_game LANGUAGES C CXX)

# Configure C and C++ standards
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Use FetchContent to download and build raylib at configure time.  This
# simplifies the setup for users who do not have raylib preinstalled.
# The stable release 6.0 from AprilÂ 2026 is used by defaultã€99204103476631â€ L2368-L2374ã€‘.
include(FetchContent)

set(BUILD_EXAMPLES OFF CACHE BOOL "Disable raylib examples" FORCE)
set(ENABLE_INSTALL OFF CACHE BOOL "Disable raylib install target" FORCE)

FetchContent_Declare(
  raylib
  GIT_REPOSITORY https://github.com/raysan5/raylib.git
  GIT_TAG        6.0
)
FetchContent_MakeAvailable(raylib)

# Define the executable from our sources.  Additional source files can be
# added as the project grows.
add_executable(montpellier
  src/main.cpp
  src/ModelUtils.cpp
  src/ProceduralCity.cpp
  src/PlayerController.cpp
  src/Collision.cpp
  src/Hud.cpp
  src/Scene.cpp
  src/Game.cpp
)

# Link against the raylib target.  Raylib brings in all required
# system libraries on supported platforms (GL, X11, Win32, etc.).
target_link_libraries(montpellier PRIVATE raylib)

# Copy the assets folder into the build directory so the executable
# can find the models and textures without manual fiddling.  CMake
# generates a postâ€‘build command to perform this copy.
add_custom_command(TARGET montpellier POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_directory
          ${CMAKE_SOURCE_DIR}/assets
          $<TARGET_FILE_DIR:montpellier>/assets
)





