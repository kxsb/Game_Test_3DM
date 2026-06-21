//
// main.cpp -- entry point for Montpellier 3D prototype
//
// This minimal application demonstrates how to set up a raylib
// window, load a 3D model, centre it around the origin and display
// it with a freely movable camera.  It serves as the foundation
// upon which more complex game logic (navigation, collision, AI,
// etc.) can be built.

#include "raylib.h"
#include "ModelUtils.h"

int main(int argc, char** argv) {
    // Configure the window dimensions.  These can be adjusted
    // according to your monitor resolution.
    const int screenWidth  = 1280;
    const int screenHeight = 720;
    InitWindow(screenWidth, screenHeight, "Montpellier 3D Prototype");

    // Initialize a perspective camera positioned at (5,5,5) looking
    // towards the origin.  The CAMERA_FREE mode allows movement
    // controlled by WASD and mouse by default.
    Camera3D camera = { 0 };
    camera.position   = { 5.0f, 5.0f, 5.0f };
    camera.target     = { 0.0f, 0.0f, 0.0f };
    camera.up         = { 0.0f, 1.0f, 0.0f };
    camera.fovy       = 45.0f;
    camera.projection = CAMERA_PERSPECTIVE;

    SetTargetFPS(60);

    // Determine the model path from the command line.  If no
    // argument is provided, fall back to a default placeholder
    // located at assets/models/example.glb.  The application will
    // still run even if the file is missing; it simply displays
    // an empty scene with a ground grid.
    const char* defaultModelPath = "assets/models/example.glb";
    const char* modelPath = defaultModelPath;
    if (argc > 1) {
        modelPath = argv[1];
    }

    Model model = { 0 };
    bool modelLoaded = false;
    if (FileExists(modelPath)) {
        model = LoadModel(modelPath);
        CenterModel(&model);
        modelLoaded = true;
    } else {
        TraceLog(LOG_WARNING, TextFormat("Model file '%s' not found. Continuing without model.", modelPath));
    }

    while (!WindowShouldClose()) {
        // Update the camera.  CAMERA_FREE allows six‑DOF movement via
        // input: W/S forward/backward, A/D left/right, Q/E up/down, and
        // mouse look.  If you need orbit or first‑person behaviour,
        // explore UpdateCamera() documentation and examples.
        UpdateCamera(&camera, CAMERA_FREE);

        // Draw the scene
        BeginDrawing();
        ClearBackground(RAYWHITE);

        BeginMode3D(camera);
        if (modelLoaded) {
            DrawModel(model, { 0.0f, 0.0f, 0.0f }, 1.0f, LIGHTGRAY);
        }
        // Draw a reference grid.  The grid helps with orientation and
        // scale perception.  The parameters are number of cells and
        // size between cells.
        DrawGrid(20, 1.0f);
        EndMode3D();

        DrawFPS(10, 10);
        EndDrawing();
    }

    if (modelLoaded) {
        UnloadModel(model);
    }
    CloseWindow();
    return 0;
}