#pragma once

#include "Collision.h"
#include "ProceduralCity.h"
#include "raylib.h"

struct Scene {
    Model model = {};
    bool modelLoaded = false;
    const char* modelPath = nullptr;

    ProceduralCity proceduralCity;
    CollisionWorld collisionWorld;
};

void LoadScene(Scene* scene, const char* modelPath);
void DrawScene(const Scene& scene);
void UnloadScene(Scene* scene);
