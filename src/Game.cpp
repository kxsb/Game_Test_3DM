#include "Game.h"

#include "AppConfig.h"
#include "Hud.h"
#include "PlayerController.h"
#include "Scene.h"

#include "raylib.h"

namespace {
    Camera3D CreateInitialCamera() {
        Camera3D camera = {};
        camera.position = AppConfig::InitialCameraPosition;
        camera.target = AppConfig::InitialCameraTarget;
        camera.up = AppConfig::CameraUp;
        camera.fovy = AppConfig::CameraFovY;
        camera.projection = CAMERA_PERSPECTIVE;
        return camera;
    }

    const char* ResolveModelPath(int argc, char** argv) {
        if (argc > 1) {
            return argv[1];
        }

        return AppConfig::DefaultModelPath;
    }

    const char* ResolvePhotoModelPath(int argc, char** argv) {
        if (argc > 2) {
            return argv[2];
        }

        if (FileExists(AppConfig::DefaultPhotomodelPath)) {
            return AppConfig::DefaultPhotomodelPath;
        }

        return nullptr;
    }
}

int RunGame(int argc, char** argv) {
    InitWindow(AppConfig::ScreenWidth, AppConfig::ScreenHeight, AppConfig::WindowTitle);

    Camera3D camera = CreateInitialCamera();
    PlayerControllerState player = CreatePlayerController(camera);

    SetTargetFPS(AppConfig::TargetFps);

    Scene scene = {};
    LoadScene(&scene, ResolveModelPath(argc, argv), ResolvePhotoModelPath(argc, argv));

    while (!WindowShouldClose()) {
        UpdatePlayerController(&player, scene.collisionWorld);
        UpdateScenePhotoModelControls(&scene);
        ApplyPlayerToCamera(player, &camera);

        BeginDrawing();
        ClearBackground(RAYWHITE);

        BeginMode3D(camera);
        DrawScene(scene);

        SceneDebugRenderOptions debugOptions = {};
        debugOptions.showBounds = player.boundsDebugEnabled;
        debugOptions.showGroundHeightfield = player.groundDebugEnabled;
        debugOptions.showCollisions = player.collisionDebugEnabled;
        debugOptions.showWireframe = player.wireframeDebugEnabled;

        if (
            debugOptions.showBounds ||
            debugOptions.showGroundHeightfield ||
            debugOptions.showCollisions ||
            debugOptions.showWireframe
        ) {
            DrawSceneDebug(scene, debugOptions);
        }

        EndMode3D();

        DrawHud(scene, player);

        EndDrawing();
    }

    UnloadScene(&scene);

    EnableCursor();
    CloseWindow();

    return 0;
}


