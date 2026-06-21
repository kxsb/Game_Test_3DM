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

    Vector3 CenterOfBounds(const BoundingBox& bounds) {
        return {
            (bounds.min.x + bounds.max.x) * 0.5f,
            (bounds.min.y + bounds.max.y) * 0.5f,
            (bounds.min.z + bounds.max.z) * 0.5f
        };
    }

    BoundingBox TransformBounds(const BoundingBox& bounds, Vector3 position, float scale) {
        BoundingBox transformed = {};
        transformed.min = {
            bounds.min.x * scale + position.x,
            bounds.min.y * scale + position.y,
            bounds.min.z * scale + position.z
        };
        transformed.max = {
            bounds.max.x * scale + position.x,
            bounds.max.y * scale + position.y,
            bounds.max.z * scale + position.z
        };
        return transformed;
    }

    Vector3 ComputeInitialPhotoModelPosition(const Scene& scene, const BoundingBox& photoBounds, float scale) {
        Vector3 position = { 0.0f, 0.0f, 0.0f };

        if (!scene.modelLoaded || !scene.modelStats.hasBounds) {
            return position;
        }

        const Vector3 cityCenter = CenterOfBounds(scene.modelStats.bounds);
        const Vector3 photoCenter = CenterOfBounds(photoBounds);

        position.x = cityCenter.x - photoCenter.x * scale;
        position.y = scene.modelStats.bounds.min.y - photoBounds.min.y * scale;
        position.z = cityCenter.z - photoCenter.z * scale;

        return position;
    }

    void LoadPhotoModel(Scene* scene, const char* photoModelPath) {
        scene->photoModel = {};

        if (photoModelPath == nullptr || photoModelPath[0] == '\0') {
            TraceLog(LOG_INFO, "Photomodel: no path provided");
            return;
        }

        if (!FileExists(photoModelPath)) {
            TraceLog(LOG_WARNING, TextFormat("Photomodel file not found: %s", photoModelPath));
            return;
        }

        scene->photoModel.model = LoadModel(photoModelPath);
        scene->photoModel.loaded = true;
        scene->photoModel.visible = true;
        scene->photoModel.path = photoModelPath;
        scene->photoModel.bounds = ComputeModelBoundingBox(&scene->photoModel.model);
        scene->photoModel.hasBounds = true;
        scene->photoModel.scale = 1.0f;
        scene->photoModel.position = ComputeInitialPhotoModelPosition(
            *scene,
            scene->photoModel.bounds,
            scene->photoModel.scale
        );

        TraceLog(
            LOG_INFO,
            TextFormat(
                "Loaded photomodel: %s offset=(%.2f %.2f %.2f) scale=%.3f",
                scene->photoModel.path.c_str(),
                scene->photoModel.position.x,
                scene->photoModel.position.y,
                scene->photoModel.position.z,
                scene->photoModel.scale
            )
        );
    }
    bool LoadCollisionSidecar(const std::string& path, CollisionWorld* world) {
        std::ifstream input(path);

        if (!input.is_open()) {
            TraceLog(LOG_WARNING, TextFormat("Collision sidecar open failed: %s", path.c_str()));
            return false;
        }

        world->solidBoxes.clear();
        world->solidSegments.clear();

        std::string line;
        int loadedBoxes = 0;
        int parsedBoxLines = 0;
        int failedBoxLines = 0;

        int loadedSegments = 0;
        int parsedSegmentLines = 0;
        int failedSegmentLines = 0;

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

            if (kind == "box") {
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

                continue;
            }

            if (kind == "seg") {
                parsedSegmentLines++;

                CollisionSegment segment = {};
                iss >>
                    segment.a.x >>
                    segment.a.z >>
                    segment.b.x >>
                    segment.b.z >>
                    segment.minY >>
                    segment.maxY >>
                    segment.thickness;

                if (!iss.fail()) {
                    if (segment.maxY < segment.minY) {
                        std::swap(segment.minY, segment.maxY);
                    }

                    if (segment.thickness <= 0.0f) {
                        segment.thickness = 0.35f;
                    }

                    segment.a.y = segment.minY;
                    segment.b.y = segment.minY;

                    world->solidSegments.push_back(segment);
                    loadedSegments++;
                }
                else {
                    failedSegmentLines++;
                }

                continue;
            }
        }

        TraceLog(
            LOG_INFO,
            TextFormat(
                "Collision sidecar parse: path=%s boxLines=%d boxes=%d boxFailed=%d segLines=%d segments=%d segFailed=%d",
                path.c_str(),
                parsedBoxLines,
                loadedBoxes,
                failedBoxLines,
                parsedSegmentLines,
                loadedSegments,
                failedSegmentLines
            )
        );

        return loadedBoxes > 0 || loadedSegments > 0;
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

void LoadScene(Scene* scene, const char* modelPath, const char* photoModelPath) {
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
            scene->collisionWorld.solidSegments.clear();
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

    LoadPhotoModel(scene, photoModelPath);
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
        if (scene.primaryModelVisible) {
            // Color WHITE laisse les matériaux OBJ/MTL faire leur travail.
            DrawModel(scene.model, { 0.0f, 0.0f, 0.0f }, 1.0f, WHITE);
        }
    }
    else {
        DrawProceduralCity(scene.proceduralCity);
    }

    if (scene.photoModel.loaded && scene.photoModel.visible) {
        DrawModel(
            scene.photoModel.model,
            scene.photoModel.position,
            scene.photoModel.scale,
            WHITE
        );
    }
}

void DrawSceneDebug(
    const Scene& scene,
    const SceneDebugRenderOptions& options
) {
    if (scene.modelLoaded && scene.primaryModelVisible && options.showWireframe) {
        DrawModelWires(scene.model, { 0.0f, 0.0f, 0.0f }, 1.0f, Fade(BLACK, 0.22f));
    }

    if (scene.photoModel.loaded && scene.photoModel.visible && options.showWireframe) {
        DrawModelWires(
            scene.photoModel.model,
            scene.photoModel.position,
            scene.photoModel.scale,
            Fade(MAROON, 0.32f)
        );
    }

    if (scene.modelLoaded && scene.primaryModelVisible && scene.modelStats.hasBounds && options.showBounds) {
        DrawBoundingBox(scene.modelStats.bounds, BLUE);
    }

    if (scene.photoModel.loaded && scene.photoModel.visible && scene.photoModel.hasBounds && options.showBounds) {
        DrawBoundingBox(
            TransformBounds(scene.photoModel.bounds, scene.photoModel.position, scene.photoModel.scale),
            ORANGE
        );
    }

    if (options.showGroundHeightfield) {
        DrawGroundHeightfieldDebug(scene.collisionWorld.groundHeightfield);
    }

    if (options.showCollisions) {
        DrawCollisionWorldDebug(scene.collisionWorld);
    }
}

void UpdateScenePhotoModelControls(Scene* scene) {
    if (IsKeyPressed(KEY_P) && scene->photoModel.loaded) {
        scene->photoModel.visible = !scene->photoModel.visible;
    }

    if (IsKeyPressed(KEY_X) && scene->modelLoaded) {
        scene->primaryModelVisible = !scene->primaryModelVisible;
    }

    if (!scene->photoModel.loaded) {
        return;
    }

    const float dt = GetFrameTime();
    const float moveSpeed = (IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT)) ? 25.0f : 4.0f;
    const float step = moveSpeed * dt;

    if (IsKeyDown(KEY_J)) {
        scene->photoModel.position.x -= step;
    }

    if (IsKeyDown(KEY_L)) {
        scene->photoModel.position.x += step;
    }

    if (IsKeyDown(KEY_I)) {
        scene->photoModel.position.z -= step;
    }

    if (IsKeyDown(KEY_K)) {
        scene->photoModel.position.z += step;
    }

    if (IsKeyDown(KEY_U)) {
        scene->photoModel.position.y += step;
    }

    if (IsKeyDown(KEY_O)) {
        scene->photoModel.position.y -= step;
    }

    if (IsKeyDown(KEY_EQUAL) || IsKeyDown(KEY_KP_ADD)) {
        scene->photoModel.scale += dt * 0.08f;
    }

    if (IsKeyDown(KEY_MINUS) || IsKeyDown(KEY_KP_SUBTRACT)) {
        scene->photoModel.scale -= dt * 0.08f;
    }

    scene->photoModel.scale = std::max(0.05f, scene->photoModel.scale);
}
void UnloadScene(Scene* scene) {
    if (scene->modelLoaded) {
        UnloadModel(scene->model);
        scene->modelLoaded = false;
    }

    if (scene->photoModel.loaded) {
        UnloadModel(scene->photoModel.model);
        scene->photoModel.loaded = false;
        scene->photoModel.visible = false;
    }

    scene->modelStats = {};
    scene->photoModel = {};
    scene->collisionWorld.solidBoxes.clear();
    scene->collisionWorld.solidSegments.clear();
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












