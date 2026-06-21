#pragma once

#include "raylib.h"
#include "ProceduralCity.h"

struct Scene {
    Model model = {};
    bool modelLoaded = false;
    const char* modelPath = nullptr;
    ProceduralCity proceduralCity;
};

void LoadScene(Scene* scene, const char* modelPath);
void DrawScene(const Scene& scene);
void UnloadScene(Scene* scene);
