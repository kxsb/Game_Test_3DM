#pragma once

#include "raylib.h"
#include <vector>

struct ProceduralBuilding {
    Vector3 position;
    Vector3 size;
    Color color;
};

struct ProceduralCity {
    std::vector<ProceduralBuilding> buildings;
};

ProceduralCity CreateProceduralCity();
void DrawProceduralCity(const ProceduralCity& city);
