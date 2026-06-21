#pragma once

#include "raylib.h"

#include <vector>

struct GroundHeightfield {
    bool enabled = false;

    float cellSize = 6.0f;
    int width = 0;
    int depth = 0;

    float minX = 0.0f;
    float maxX = 0.0f;
    float minZ = 0.0f;
    float maxZ = 0.0f;

    int cellsWithSamples = 0;
    int cellsFilledFromNeighbors = 0;

    float minHeight = 0.0f;
    float maxHeight = 0.0f;

    std::vector<float> heights;
    std::vector<unsigned char> hasData;
};

GroundHeightfield BuildGroundHeightfieldFromModel(
    Model* model,
    const BoundingBox& bounds,
    float fallbackY,
    float cellSize
);

GroundHeightfield LoadGroundHeightfieldFromFile(
    const char* path,
    float fallbackY
);

float SampleGroundHeightAt(
    const GroundHeightfield& heightfield,
    float fallbackY,
    float x,
    float z
);

void OffsetGroundHeightfield(
    GroundHeightfield* heightfield,
    float deltaY
);

void DrawGroundHeightfieldDebug(
    const GroundHeightfield& heightfield
);

