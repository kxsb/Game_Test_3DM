#include "Hud.h"
#include "AppConfig.h"

#include "raylib.h"

void DrawHud(const Scene& scene, const CameraControllerState& cameraController) {
    DrawRectangle(8, 8, 650, 146, Fade(RAYWHITE, 0.88f));

    DrawText(AppConfig::PrototypeLabel, 16, 16, 20, DARKGRAY);

    DrawText(
        scene.modelLoaded ? "Mode: modele charge" : "Mode: mini-ville procedurale",
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
        "Camera: souris + ZQSD/WASD, E monte, C descend",
        16,
        86,
        16,
        GRAY
    );

    DrawText(
        "TAB libere/capture souris | molette vitesse | Shift accelere | Ctrl ralentit | R reset",
        16,
        108,
        16,
        GRAY
    );

    DrawText(
        TextFormat("Vitesse: %.1f | Souris: %s", cameraController.moveSpeed, cameraController.mouseLookEnabled ? "capturee" : "libre"),
        16,
        130,
        16,
        GRAY
    );

    DrawFPS(16, 158);
}
