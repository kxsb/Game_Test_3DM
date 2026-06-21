#include "Scene.h"
#include "AppConfig.h"
#include "ModelUtils.h"
#include "GroundHeightfield.h"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <sstream>
#include <string>

namespace {
    CollisionWorld BuildCollisionWorldFromProceduralCity(const ProceduralCity& city) {
        CollisionWorld world = {};
        world.groundY = AppConfig::GroundY;
        world.maxWalkSlopeRatio = AppConfig::MaxWalkSlopeRatio;
        world.maxWalkStepHeight = AppConfig::MaxWalkStepHeight;

        world.solidBoxes.reserve(city.buildings.size());

        for (const ProceduralBuilding& building : city.buildings) {
            world.solidBoxes.push_back(MakeCollisionBox(building.position, building.size));
        }

        return world;
    }

    float EstimateWalkGroundY(const BoundingBox& bounds) {
        // Pour les tuiles DXF, on normalise déjà l'altitude minimale à Y=0.
        // En attendant un vrai terrain, le niveau de marche doit rester à 0.
        (void)bounds;
        return 0.0f;
    }

    SceneGroundPlane BuildGroundPlaneFromBounds(const BoundingBox& bounds, float y) {
        SceneGroundPlane plane = {};
        plane.enabled = true;
        plane.y = y;

        const float padding = 20.0f;

        plane.minX = bounds.min.x - padding;
        plane.maxX = bounds.max.x + padding;
        plane.minZ = bounds.min.z - padding;
        plane.maxZ = bounds.max.z + padding;

        return plane;
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
        stats.estimatedWalkGroundY = EstimateWalkGroundY(stats.bounds);

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

    std::string BuildGroundSidecarPath(const std::string& modelPath) {
        const size_t slashPos = modelPath.find_last_of("/\\");
        const size_t dotPos = modelPath.find_last_of('.');

        if (dotPos == std::string::npos || (slashPos != std::string::npos && dotPos < slashPos)) {
            return modelPath + ".ground.txt";
        }

        return modelPath.substr(0, dotPos) + ".ground.txt";
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

    float ComputeGridSpacing(float extent) {
        if (extent > 300.0f) {
            return 10.0f;
        }

        if (extent > 120.0f) {
            return 5.0f;
        }

        return AppConfig::GridSpacing;
    }

    void DrawGroundGridAtY(float y, float minX, float maxX, float minZ, float maxZ, float spacing) {
        const float startX = std::floor(minX / spacing) * spacing;
        const float endX = std::ceil(maxX / spacing) * spacing;

        const float startZ = std::floor(minZ / spacing) * spacing;
        const float endZ = std::ceil(maxZ / spacing) * spacing;

        for (float x = startX; x <= endX + 0.001f; x += spacing) {
            const bool isAxis = std::fabs(x) < 0.001f;
            const Color color = isAxis ? BLUE : Fade(DARKGRAY, 0.28f);

            DrawLine3D(
                { x, y + 0.01f, startZ },
                { x, y + 0.01f, endZ },
                color
            );
        }

        for (float z = startZ; z <= endZ + 0.001f; z += spacing) {
            const bool isAxis = std::fabs(z) < 0.001f;
            const Color color = isAxis ? BLUE : Fade(DARKGRAY, 0.28f);

            DrawLine3D(
                { startX, y + 0.01f, z },
                { endX, y + 0.01f, z },
                color
            );
        }
    }

    void DrawGroundPlane(const SceneGroundPlane& plane) {
        const float centerX = (plane.minX + plane.maxX) * 0.5f;
        const float centerZ = (plane.minZ + plane.maxZ) * 0.5f;
        const float sizeX = plane.maxX - plane.minX;
        const float sizeZ = plane.maxZ - plane.minZ;

        DrawCube(
            { centerX, plane.y - 0.03f, centerZ },
            sizeX,
            0.04f,
            sizeZ,
            Color{ 205, 210, 205, 255 }
        );

        DrawCubeWires(
            { centerX, plane.y - 0.02f, centerZ },
            sizeX,
            0.04f,
            sizeZ,
            Fade(DARKGREEN, 0.55f)
        );
    }
}

void LoadScene(Scene* scene, const char* modelPath) {
    scene->modelPath = modelPath;
    scene->collisionSidecarPath = BuildCollisionSidecarPath(scene->modelPath);
    scene->externalCollisionLoaded = false;
    scene->groundPlane = {};

    scene->proceduralCity = CreateProceduralCity();
    scene->collisionWorld = BuildCollisionWorldFromProceduralCity(scene->proceduralCity);
    scene->modelStats = {};

    if (FileExists(modelPath)) {
        scene->model = LoadModel(modelPath);
        NormalizeModelToGround(&scene->model, AppConfig::GroundY);

        scene->modelStats = ComputeSceneModelStats(&scene->model);
        scene->modelLoaded = true;

        scene->collisionWorld.groundY = scene->modelStats.estimatedWalkGroundY;
        scene->collisionWorld.maxWalkSlopeRatio = AppConfig::MaxWalkSlopeRatio;
        scene->collisionWorld.maxWalkStepHeight = AppConfig::MaxWalkStepHeight;

        const std::string groundSidecarPath = BuildGroundSidecarPath(scene->modelPath);

        if (FileExists(groundSidecarPath.c_str())) {
            scene->collisionWorld.groundHeightfield = LoadGroundHeightfieldFromFile(
                groundSidecarPath.c_str(),
                scene->collisionWorld.groundY
            );

            if (scene->collisionWorld.groundHeightfield.enabled) {
                TraceLog(LOG_INFO, TextFormat("Loaded ground sidecar: %s", groundSidecarPath.c_str()));
            }
            else {
                TraceLog(LOG_WARNING, TextFormat("Ground sidecar unusable: %s", groundSidecarPath.c_str()));
            }
        }

        if (!scene->collisionWorld.groundHeightfield.enabled) {
            scene->collisionWorld.groundHeightfield = BuildGroundHeightfieldFromModel(
                &scene->model,
                scene->modelStats.bounds,
                scene->collisionWorld.groundY,
                AppConfig::GroundHeightfieldCellSize
            );
        }

        scene->groundPlane = BuildGroundPlaneFromBounds(scene->modelStats.bounds, scene->collisionWorld.groundY);

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

        TraceLog(
            LOG_INFO,
            TextFormat(
                "Walk ground: %.2f",
                scene->collisionWorld.groundY
            )
        );

        if (scene->collisionWorld.groundHeightfield.enabled) {
            TraceLog(
                LOG_INFO,
                TextFormat(
                    "Ground heightfield: %dx%d cell=%.2f sampled=%d filled=%d height=[%.2f %.2f]",
                    scene->collisionWorld.groundHeightfield.width,
                    scene->collisionWorld.groundHeightfield.depth,
                    scene->collisionWorld.groundHeightfield.cellSize,
                    scene->collisionWorld.groundHeightfield.cellsWithSamples,
                    scene->collisionWorld.groundHeightfield.cellsFilledFromNeighbors,
                    scene->collisionWorld.groundHeightfield.minHeight,
                    scene->collisionWorld.groundHeightfield.maxHeight
                )
            );
        }
        else {
            TraceLog(LOG_WARNING, "Ground heightfield: disabled, using flat ground fallback");
        }

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
    if (scene.groundPlane.enabled) {
        const float extentX = scene.groundPlane.maxX - scene.groundPlane.minX;
        const float extentZ = scene.groundPlane.maxZ - scene.groundPlane.minZ;
        const float spacing = ComputeGridSpacing(std::max(extentX, extentZ));

        DrawGroundPlane(scene.groundPlane);
        DrawGroundGridAtY(
            scene.groundPlane.y,
            scene.groundPlane.minX,
            scene.groundPlane.maxX,
            scene.groundPlane.minZ,
            scene.groundPlane.maxZ,
            spacing
        );
    }
    else {
        DrawGrid(AppConfig::GridSlices, AppConfig::GridSpacing);
    }

    if (scene.modelLoaded) {
        // Color WHITE laisse les matériaux OBJ/MTL faire leur travail.
        DrawModel(scene.model, { 0.0f, 0.0f, 0.0f }, 1.0f, WHITE);

        // Contours discrets pour lire les bâtiments et les rues.
        DrawModelWires(scene.model, { 0.0f, 0.0f, 0.0f }, 1.0f, Fade(BLACK, 0.22f));
    }
    else {
        DrawProceduralCity(scene.proceduralCity);
    }
}

void DrawSceneDebug(const Scene& scene) {
    if (scene.modelLoaded && scene.modelStats.hasBounds) {
        DrawBoundingBox(scene.modelStats.bounds, BLUE);
    }

    DrawGroundHeightfieldDebug(scene.collisionWorld.groundHeightfield);
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

void AdjustSceneGround(Scene* scene, float deltaY) {
    scene->collisionWorld.groundY += deltaY;
    OffsetGroundHeightfield(&scene->collisionWorld.groundHeightfield, deltaY);

    if (scene->groundPlane.enabled) {
        scene->groundPlane.y = scene->collisionWorld.groundY;
    }
}

void ResetSceneGroundToEstimated(Scene* scene) {
    const float previousGroundY = scene->collisionWorld.groundY;

    if (scene->modelLoaded && scene->modelStats.hasBounds) {
        scene->collisionWorld.groundY = scene->modelStats.estimatedWalkGroundY;
    }
    else {
        scene->collisionWorld.groundY = AppConfig::GroundY;
    }

    const float deltaY = scene->collisionWorld.groundY - previousGroundY;
    OffsetGroundHeightfield(&scene->collisionWorld.groundHeightfield, deltaY);

    if (scene->groundPlane.enabled) {
        scene->groundPlane.y = scene->collisionWorld.groundY;
    }
}









