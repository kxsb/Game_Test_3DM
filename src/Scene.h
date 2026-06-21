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
};

struct Scene {
    Model model = {};
    bool modelLoaded = false;
    std::string modelPath;
    std::string collisionSidecarPath;
    bool externalCollisionLoaded = false;

    SceneModelStats modelStats;

    ProceduralCity proceduralCity;
    CollisionWorld collisionWorld;
};

void LoadScene(Scene* scene, const char* modelPath);
void DrawScene(const Scene& scene);
void DrawSceneDebug(const Scene& scene);
void UnloadScene(Scene* scene);
