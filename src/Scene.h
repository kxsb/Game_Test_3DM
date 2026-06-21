#pragma once

#include "Collision.h"
#include "ProceduralCity.h"
#include "raylib.h"

#include <string>

struct SceneModelStats {
    int meshCount = 0;
    int materialCount = 0;
    int vertexCount = 0;
    int triangleCount = 0;

    BoundingBox bounds = {};
    bool hasBounds = false;

    float estimatedWalkGroundY = 0.0f;
};

struct SceneGroundPlane {
    bool enabled = false;
    float y = 0.0f;
    float minX = -20.0f;
    float maxX = 20.0f;
    float minZ = -20.0f;
    float maxZ = 20.0f;
};

struct SceneDebugRenderOptions {
    bool showBounds = false;
    bool showGroundHeightfield = false;
    bool showCollisions = false;
    bool showWireframe = false;
};

struct Scene {
    Model model = {};
    bool modelLoaded = false;

    std::string modelPath;
    std::string collisionSidecarPath;
    bool externalCollisionLoaded = false;

    SceneModelStats modelStats;
    SceneGroundPlane groundPlane;

    ProceduralCity proceduralCity;
    CollisionWorld collisionWorld;
};

void LoadScene(Scene* scene, const char* modelPath);
void DrawScene(const Scene& scene);
void DrawSceneDebug(
    const Scene& scene,
    const SceneDebugRenderOptions& options
);
void UnloadScene(Scene* scene);

void AdjustSceneGround(Scene* scene, float deltaY);
void ResetSceneGroundToEstimated(Scene* scene);
