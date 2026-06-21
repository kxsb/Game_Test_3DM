#include "Scene.h"
#include "AppConfig.h"
#include "ModelUtils.h"

namespace {
    CollisionWorld BuildCollisionWorldFromProceduralCity(const ProceduralCity& city) {
        CollisionWorld world = {};
        world.groundY = AppConfig::GroundY;

        world.solidBoxes.reserve(city.buildings.size());

        for (const ProceduralBuilding& building : city.buildings) {
            world.solidBoxes.push_back(MakeCollisionBox(building.position, building.size));
        }

        return world;
    }
}

void LoadScene(Scene* scene, const char* modelPath) {
    scene->modelPath = modelPath;
    scene->proceduralCity = CreateProceduralCity();
    scene->collisionWorld = BuildCollisionWorldFromProceduralCity(scene->proceduralCity);

    if (FileExists(modelPath)) {
        scene->model = LoadModel(modelPath);
        CenterModel(&scene->model);
        scene->modelLoaded = true;

        // Pour les futurs vrais modèles, on gardera le sol, mais on devra générer
        // une collision dédiée. Pour l'instant, on désactive les boîtes procédurales
        // quand un modèle externe est chargé.
        scene->collisionWorld.solidBoxes.clear();

        TraceLog(LOG_INFO, TextFormat("Loaded model: %s", modelPath));
    }
    else {
        scene->modelLoaded = false;

        TraceLog(
            LOG_WARNING,
            TextFormat("Model file '%s' not found. Using procedural city fallback.", modelPath)
        );
    }
}

void DrawScene(const Scene& scene) {
    DrawGrid(AppConfig::GridSlices, AppConfig::GridSpacing);

    if (scene.modelLoaded) {
        DrawModel(scene.model, { 0.0f, 0.0f, 0.0f }, 1.0f, LIGHTGRAY);
    }
    else {
        DrawProceduralCity(scene.proceduralCity);
    }
}

void UnloadScene(Scene* scene) {
    if (scene->modelLoaded) {
        UnloadModel(scene->model);
        scene->modelLoaded = false;
    }

    scene->collisionWorld.solidBoxes.clear();
}
