#include "Scene.h"
#include "AppConfig.h"
#include "ModelUtils.h"

#include <algorithm>
#include <fstream>
#include <sstream>
#include <string>

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

    std::string BuildCollisionSidecarPath(const std::string& modelPath) {
        const size_t slashPos = modelPath.find_last_of("/\\");
        const size_t dotPos = modelPath.find_last_of('.');

        if (dotPos == std::string::npos || (slashPos != std::string::npos && dotPos < slashPos)) {
            return modelPath + ".collisions.txt";
        }

        return modelPath.substr(0, dotPos) + ".collisions.txt";
    }

    bool LoadCollisionSidecar(const std::string& path, CollisionWorld* world) {
        std::ifstream input(path);

        if (!input.is_open()) {
            TraceLog(LOG_WARNING, TextFormat("Collision sidecar open failed: %s", path.c_str()));
            return false;
        }

        world->solidBoxes.clear();

        std::string line;
        int loadedBoxes = 0;
        int parsedBoxLines = 0;
        int failedBoxLines = 0;

        while (std::getline(input, line)) {
            if (line.empty()) {
                continue;
            }

            if (line[0] == '#') {
                continue;
            }

            // Robustesse Windows/fr-FR : accepte les nombres en virgule décimale.
            std::replace(line.begin(), line.end(), ',', '.');

            std::istringstream iss(line);
            std::string kind;
            iss >> kind;

            if (kind != "box") {
                continue;
            }

            parsedBoxLines++;

            CollisionBox box = {};
            iss >> box.center.x >> box.center.y >> box.center.z >> box.size.x >> box.size.y >> box.size.z;

            if (!iss.fail()) {
                world->solidBoxes.push_back(box);
                loadedBoxes++;
            }
            else {
                failedBoxLines++;
            }
        }

        TraceLog(
            LOG_INFO,
            TextFormat(
                "Collision sidecar parse: path=%s lines=%d loaded=%d failed=%d",
                path.c_str(),
                parsedBoxLines,
                loadedBoxes,
                failedBoxLines
            )
        );

        return loadedBoxes > 0;
    }
}

void LoadScene(Scene* scene, const char* modelPath) {
    scene->modelPath = modelPath;
    scene->collisionSidecarPath = BuildCollisionSidecarPath(scene->modelPath);
    scene->externalCollisionLoaded = false;

    scene->proceduralCity = CreateProceduralCity();
    scene->collisionWorld = BuildCollisionWorldFromProceduralCity(scene->proceduralCity);
    scene->modelStats = {};

    if (FileExists(modelPath)) {
        scene->model = LoadModel(modelPath);
        NormalizeModelToGround(&scene->model, AppConfig::GroundY);
        scene->modelStats = ComputeSceneModelStats(&scene->model);
        scene->modelLoaded = true;

        scene->collisionWorld.groundY = AppConfig::GroundY;
        scene->externalCollisionLoaded = LoadCollisionSidecar(scene->collisionSidecarPath, &scene->collisionWorld);

        if (!scene->externalCollisionLoaded) {
            scene->collisionWorld.solidBoxes.clear();
        }

        TraceLog(LOG_INFO, TextFormat("Loaded model: %s", scene->modelPath.c_str()));
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

        if (scene->externalCollisionLoaded) {
            TraceLog(
                LOG_INFO,
                TextFormat(
                    "Loaded collision sidecar: %s (%d boxes)",
                    scene->collisionSidecarPath.c_str(),
                    static_cast<int>(scene->collisionWorld.solidBoxes.size())
                )
            );
        }
        else {
            TraceLog(LOG_WARNING, TextFormat("No usable collision sidecar: %s", scene->collisionSidecarPath.c_str()));
        }
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
