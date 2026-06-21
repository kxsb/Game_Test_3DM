#include "raylib.h"
#include "ModelUtils.h"
#include "ProceduralCity.h"
#include "CameraController.h"

int main(int argc, char** argv) {
    const int screenWidth  = 1280;
    const int screenHeight = 720;

    InitWindow(screenWidth, screenHeight, "Montpellier 3D Prototype");

    Camera3D camera = { 0 };
    camera.position   = { 18.0f, 14.0f, 18.0f };
    camera.target     = { 0.0f, 2.0f, 0.0f };
    camera.up         = { 0.0f, 1.0f, 0.0f };
    camera.fovy       = 45.0f;
    camera.projection = CAMERA_PERSPECTIVE;

    CameraControllerState cameraController = CreateCameraController(camera);

    SetTargetFPS(60);

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
        TraceLog(LOG_INFO, TextFormat("Loaded model: %s", modelPath));
    }
    else {
        TraceLog(LOG_WARNING, TextFormat("Model file '%s' not found. Using procedural city fallback.", modelPath));
    }

    ProceduralCity proceduralCity = CreateProceduralCity();

    while (!WindowShouldClose()) {
        UpdateCameraController(&camera, &cameraController);

        BeginDrawing();
        ClearBackground(RAYWHITE);

        BeginMode3D(camera);

        DrawGrid(40, 1.0f);

        if (modelLoaded) {
            DrawModel(model, { 0.0f, 0.0f, 0.0f }, 1.0f, LIGHTGRAY);
        }
        else {
            DrawProceduralCity(proceduralCity);
        }

        EndMode3D();

        DrawRectangle(8, 8, 590, 128, Fade(RAYWHITE, 0.88f));
        DrawText("Montpellier Game - Prototype 1B", 16, 16, 20, DARKGRAY);
        DrawText(modelLoaded ? "Mode: modele charge" : "Mode: mini-ville procedurale", 16, 42, 16, GRAY);
        DrawText("Camera: souris + ZQSD/WASD, E monte, C descend", 16, 64, 16, GRAY);
        DrawText("TAB libere/capture souris | molette vitesse | Shift accelere | R reset", 16, 86, 16, GRAY);
        DrawText(TextFormat("Vitesse: %.1f", cameraController.moveSpeed), 16, 108, 16, GRAY);
        DrawFPS(16, 136);

        EndDrawing();
    }

    if (modelLoaded) {
        UnloadModel(model);
    }

    EnableCursor();
    CloseWindow();

    return 0;
}
