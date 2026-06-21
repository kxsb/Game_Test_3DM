# Montpellier Game – Prototype 0

This repository contains the first building block of an experimental
3D exploration game based on the 2016 Montpellier building dataset.
It is designed to compile on Windows, Linux and macOS using
[raylib](https://www.raylib.com/), a lightweight game programming
library.  The goal of this prototype is to load a single 3D model,
recentre it around the origin and display it with a free‑movement
camera.  Later iterations can expand on this to implement chunk
loading, collision, agents, textures and more.

## Highlights

- **C++** source code with CMake build system.
- Integrates **raylib 6.0** via CMake’s `FetchContent` module, so
  external dependencies are minimal.
- Supports loading **glTF/GLB**, **OBJ**, **IQM**, **Vox** and the new
  **M3D** format added in raylib 6.0【99204103476631†L2368-L2374】.  DXF files are **not** loaded
  directly; please convert them first.
- Utility functions to compute a bounding box for a model and
  recenter it around the origin.
- A simple free‑camera controlled with mouse and WASD/QE keys.

## Building

You need a working C++ compiler (MSVC 2019+/g++/clang), CMake ≥ 3.16
and the system libraries used by raylib (OpenGL, X11, etc.).  On
Windows, these are automatically provided by Visual Studio; on Linux
you may need to install `libx11-dev libxi-dev libgl1-mesa-dev` and
related packages.  See raylib documentation for details.

Clone this repository, create a build folder and run CMake:

```bash
git clone <this repository>
cd montpellier_game
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

The resulting executable (`montpellier` or `montpellier.exe`) will
appear in the build directory.  The assets folder is copied there
automatically.

## Running

By default the program attempts to load `assets/models/example.glb`.
You can override this by passing a file path on the command line:

```bash
./montpellier assets/models/Centre.glb
```

If the file does not exist the program will still run; it simply
renders an empty scene with a reference grid.

## Preparing the Montpellier DXF files

The dataset provided consists of several **DXF** files, one per
district.  Raylib cannot read DXF natively.  You must convert each
DXF into a supported format such as GLB/GLTF or OBJ.  This can be
done with the [Assimp](https://www.assimp.org/) command‑line tool
(`assimp export Centre_BATIMENTS_2016.dxf Centre.glb`) or by importing
the DXF into **Blender** and exporting as glTF 2.0.

Once converted, copy the resulting `.glb`/`.gltf`/`.obj` file into
`assets/models/` and rename it to `example.glb` or pass its path on
the command line.

## Controlling the camera

The application uses `UpdateCamera()` in `CAMERA_FREE` mode.  The
default key bindings are:

- **W/S** – move forward/backward
- **A/D** – move left/right
- **Q/E** – move down/up
- **Mouse** – look around

Adjust `camera.position` in `src/main.cpp` to change the initial
viewpoint.

## Future directions

This prototype is intentionally simple.  Potential next steps include:

1. **Chunk loading** – split the city into manageable pieces and load/unload on demand.
2. **Collision detection** – prevent the camera from flying through buildings and add ground collision so you can walk at street level.
3. **Level of detail** – simplify distant geometry to maintain performance.
4. **AI and agents** – populate the world with autonomous agents for simulation or gameplay.
5. **User interface** – add HUD elements, mini‑maps, menus and other UI.

Contributions and patches are welcome in future iterations.