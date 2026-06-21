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

    SceneModelStats ComputeSceneModelStats(Model* model) {
        SceneModelStats stats = {};

        stats.meshCount = model->meshCount;
        stats.materialCount = model->materialCount;

        for (int meshIndex = 0; meshIndex < model->meshCount; ++meshIndex) {
            Mesh mesh = model->meshes[meshIndex];
            stats.vertexCount += mesh.vertexCount;
            stats.triangleCount += mesh.triangleCount;
        }

        stats.bounds = ComputeModelBoundingBox(model);
        stats.hasBounds = true;

        return stats;
    }
}

void LoadScene(Scene* scene, const char* modelPath) {
    scene->modelPath = modelPath;
    scene->proceduralCity = CreateProceduralCity();
    scene->collisionWorld = BuildCollisionWorldFromProceduralCity(scene->proceduralCity);
    scene->modelStats = {};

    if (FileExists(modelPath)) {
        scene->model = LoadModel(modelPath);
        CenterModel(&scene->model);
        scene->modelStats = ComputeSceneModelStats(&scene->model);
        scene->modelLoaded = true;

        // Les collisions fines des modèles externes seront traitées dans une brique dédiée.
        // Pour l'instant, le mode modèle externe sert à valider le pipeline asset.
        scene->collisionWorld.solidBoxes.clear();

        TraceLog(LOG_INFO, TextFormat("Loaded model: %s", modelPath));
        TraceLog(
            LOG_INFO,
            TextFormat(
                "Model stats: meshes=%d materials=%d vertices=%d triangles=%d",
                scene->modelStats.meshCount,
                scene->modelStats.materialCount,
                scene->modelStats.vertexCount,
                scene->modelStats.triangleCount
            )
        );
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

void DrawSceneDebug(const Scene& scene) {
    if (scene.modelLoaded && scene.modelStats.hasBounds) {
        DrawBoundingBox(scene.modelStats.bounds, BLUE);
    }

    DrawCollisionWorldDebug(scene.collisionWorld);
}

void UnloadScene(Scene* scene) {
    if (scene->modelLoaded) {
        UnloadModel(scene->model);
        scene->modelLoaded = false;
    }

    scene->modelStats = {};
    scene->collisionWorld.solidBoxes.clear();
}
