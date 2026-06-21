#include "Hud.h"
#include "AppConfig.h"

#include "raylib.h"

void DrawHud(const Scene& scene, const PlayerControllerState& player) {
    DrawRectangle(8, 8, 980, 370, Fade(RAYWHITE, 0.88f));

    DrawText(AppConfig::PrototypeLabel, 16, 16, 20, DARKGRAY);

    DrawText(
        scene.modelLoaded ? "Mode scene: modele externe charge" : "Mode scene: mini-ville procedurale",
        16,
        42,
        16,
        GRAY
    );

    DrawText(
        scene.modelLoaded ? scene.modelPath.c_str() : "Fallback: aucun modele GLB/OBJ charge",
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
        TextFormat("Collisions: %d boites + %d segments | rayon joueur %.2f | B:%s G:%s V:%s N:%s",
            static_cast<int>(scene.collisionWorld.solidBoxes.size()),
            static_cast<int>(scene.collisionWorld.solidSegments.size()),
            player.playerRadius,
            player.collisionDebugEnabled ? "ON" : "OFF",
            player.groundDebugEnabled ? "ON" : "OFF",
            player.wireframeDebugEnabled ? "ON" : "OFF",
            player.boundsDebugEnabled ? "ON" : "OFF"
        ),
        16,
        108,
        16,
        GRAY
    );

    if (scene.modelLoaded) {
        DrawText(
            TextFormat(
                "Modele: meshes %d | materiaux %d | vertices %d | triangles %d",
                scene.modelStats.meshCount,
                scene.modelStats.materialCount,
                scene.modelStats.vertexCount,
                scene.modelStats.triangleCount
            ),
            16,
            130,
            16,
            GRAY
        );

        DrawText(
            TextFormat(
                "Bounds: min(%.2f %.2f %.2f) max(%.2f %.2f %.2f)",
                scene.modelStats.bounds.min.x,
                scene.modelStats.bounds.min.y,
                scene.modelStats.bounds.min.z,
                scene.modelStats.bounds.max.x,
                scene.modelStats.bounds.max.y,
                scene.modelStats.bounds.max.z
            ),
            16,
            152,
            16,
            GRAY
        );

        DrawText(
            scene.externalCollisionLoaded ? "Sidecar collisions: charge" : "Sidecar collisions: absent",
            16,
            174,
            16,
            GRAY
        );
    }
    else {
        DrawText(
            "Modele: fallback procedural, collisions batiments actives",
            16,
            130,
            16,
            GRAY
        );

        DrawText(
            "Astuce: lance scripts/run_test_model.ps1 pour tester un OBJ externe genere",
            16,
            152,
            16,
            GRAY
        );
    }

    DrawText(
        TextFormat(
            "Visuel: CityGML %s | Photo %s | Photo offset %.2f %.2f %.2f | scale %.3f",
            scene.primaryModelVisible ? "ON" : "OFF",
            (scene.photoModel.loaded && scene.photoModel.visible) ? "ON" : "OFF",
            scene.photoModel.position.x,
            scene.photoModel.position.y,
            scene.photoModel.position.z,
            scene.photoModel.scale
        ),
        16,
        196,
        16,
        GRAY
    );

    DrawText(
        "B collisions | G sol/heightfield | V wireframe | N bounds | P photo | X CityGML",
        16,
        218,
        16,
        GRAY
    );

    DrawText(
        "Align photo: I/K avant-arriere | J/L gauche-droite | U/O hauteur | +/- echelle",
        16,
        240,
        16,
        GRAY
    );

    DrawText(
        "Deplacement: ZQSD/WASD | D droite | Q/A gauche | TAB souris",
        16,
        262,
        16,
        GRAY
    );

    DrawText(
        "F marche/vol | Shift accelere | Ctrl ralentit | R reset",
        16,
        284,
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
        306,
        16,
        GRAY
    );

    DrawFPS(16, 334);
}




