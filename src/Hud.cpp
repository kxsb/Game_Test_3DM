#include "Hud.h"
#include "AppConfig.h"

#include "raylib.h"

void DrawHud(const Scene& scene, const CameraControllerState& cameraController) {
    DrawRectangle(8, 8, 780, 234, Fade(RAYWHITE, 0.88f));

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
        TextFormat("Collisions: %d boites | rayon joueur %.2f | debug B: %s",
            static_cast<int>(scene.collisionWorld.solidBoxes.size()),
            cameraController.playerRadius,
            cameraController.collisionDebugEnabled ? "ON" : "OFF"
        ),
        16,
        108,
        16,
        GRAY
    );

    DrawText(
        "Demarrage: mode Marche | F = Vol/Marche avec retour instantane au sol",
        16,
        130,
        16,
        GRAY
    );

    DrawText(
        "Deplacement: ZQSD/WASD | D droite | Q/A gauche | TAB souris",
        16,
        152,
        16,
        GRAY
    );

    DrawText(
        "Marche: collisions batiments actives | Vol: E monte, C descend",
        16,
        174,
        16,
        GRAY
    );

    DrawText(
        "B affiche les boites rouges de collision | Shift accelere | Ctrl ralentit | R reset",
        16,
        196,
        16,
        GRAY
    );

    DrawText(
        TextFormat("GroundY %.2f | WalkEye %.2f | FlyMin %.2f",
            cameraController.groundY,
            cameraController.walkEyeHeight,
            cameraController.flyMinEyeHeight
        ),
        16,
        218,
        16,
        GRAY
    );

    DrawFPS(16, 246);
}
