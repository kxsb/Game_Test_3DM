#include "Hud.h"
#include "AppConfig.h"

#include "raylib.h"

void DrawHud(const Scene& scene, const PlayerControllerState& player) {
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
        TextFormat("Joueur: %s | vitesse %.1f | souris %s",
            GetPlayerMovementModeLabel(player.movementMode),
            player.moveSpeed,
            player.mouseLookEnabled ? "capturee" : "libre"
        ),
        16,
        86,
        16,
        GRAY
    );

    DrawText(
        TextFormat("Collisions: %d boites | rayon joueur %.2f | debug B: %s",
            static_cast<int>(scene.collisionWorld.solidBoxes.size()),
            player.playerRadius,
            player.collisionDebugEnabled ? "ON" : "OFF"
        ),
        16,
        108,
        16,
        GRAY
    );

    DrawText(
        "Architecture: PlayerController pilote la position, Camera3D suit le joueur",
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
        "F marche/vol | B debug collisions | Shift accelere | Ctrl ralentit | R reset",
        16,
        174,
        16,
        GRAY
    );

    DrawText(
        "Marche: collisions batiments | Vol: E monte, C descend",
        16,
        196,
        16,
        GRAY
    );

    DrawText(
        TextFormat("Position: %.2f, %.2f, %.2f",
            player.position.x,
            player.position.y,
            player.position.z
        ),
        16,
        218,
        16,
        GRAY
    );

    DrawFPS(16, 246);
}
