#include "Hud.h"
#include "AppConfig.h"

#include "raylib.h"

void DrawHud(const Scene& scene, const CameraControllerState& cameraController) {
    DrawRectangle(8, 8, 700, 168, Fade(RAYWHITE, 0.88f));

    DrawText(AppConfig::PrototypeLabel, 16, 16, 20, DARKGRAY);

    DrawText(
        scene.modelLoaded ? "Mode scene: modele charge" : "Mode scene: mini-ville procedurale",
        16,
        42,
        16,
        GRAY
    );

    DrawText(
        scene.modelLoaded ? scene.modelPath : "Fallback: aucun modele GLB/OBJ charge",
        16,
        64,
        16,
        GRAY
    );

    DrawText(
        TextFormat("Camera: %s | vitesse %.1f | souris %s",
            GetCameraMovementModeLabel(cameraController.movementMode),
            cameraController.moveSpeed,
            cameraController.mouseLookEnabled ? "capturee" : "libre"
        ),
        16,
        86,
        16,
        GRAY
    );

    DrawText(
        "Deplacement: ZQSD/WASD | F vol/marche | TAB souris | molette vitesse",
        16,
        108,
        16,
        GRAY
    );

    DrawText(
        "Vol: E monte, C descend | Shift accelere | Ctrl ralentit | R reset",
        16,
        130,
        16,
        GRAY
    );

    DrawText(
        "Marche: hauteur humaine fixe, deplacement horizontal",
        16,
        152,
        16,
        GRAY
    );

    DrawFPS(16, 180);
}
