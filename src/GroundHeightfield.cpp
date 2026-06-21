#include "GroundHeightfield.h"

#include "raymath.h"

#include <algorithm>
#include <cmath>
#include <cfloat>
#include <fstream>
#include <sstream>
#include <string>

namespace {
    constexpr float MinWalkableNormalY = 0.78f;
    constexpr float MaxTerrainHeightAboveFallback = 3.0f;
    constexpr float MaxTriangleVerticalSpread = 0.90f;

    int CellIndex(const GroundHeightfield& heightfield, int x, int z) {
        return z * heightfield.width + x;
    }

    int ClampInt(int value, int minValue, int maxValue) {
        return std::max(minValue, std::min(value, maxValue));
    }

    float ClampFloat(float value, float minValue, float maxValue) {
        return std::max(minValue, std::min(value, maxValue));
    }

    Vector3 MeshVertexAt(const Mesh& mesh, int vertexIndex) {
        return {
            mesh.vertices[vertexIndex * 3 + 0],
            mesh.vertices[vertexIndex * 3 + 1],
            mesh.vertices[vertexIndex * 3 + 2]
        };
    }

    int MeshTriangleVertexIndex(const Mesh& mesh, int triangleIndex, int cornerIndex) {
        if (mesh.indices != nullptr) {
            return mesh.indices[triangleIndex * 3 + cornerIndex];
        }

        return triangleIndex * 3 + cornerIndex;
    }

    Vector3 MeshTriangleVertex(const Mesh& mesh, int triangleIndex, int cornerIndex) {
        return MeshVertexAt(mesh, MeshTriangleVertexIndex(mesh, triangleIndex, cornerIndex));
    }

    float Percentile(std::vector<float>* values, float percentile) {
        if (values->empty()) {
            return 0.0f;
        }

        std::sort(values->begin(), values->end());

        const float clamped = ClampFloat(percentile, 0.0f, 1.0f);
        const int index = ClampInt(
            static_cast<int>(std::floor(static_cast<float>(values->size() - 1) * clamped)),
            0,
            static_cast<int>(values->size() - 1)
        );

        return (*values)[index];
    }

    void AddSample(
        const GroundHeightfield& heightfield,
        std::vector<std::vector<float>>* samples,
        float fallbackY,
        Vector3 point
    ) {
        if (point.y < fallbackY - 0.50f) {
            return;
        }

        if (point.y > fallbackY + MaxTerrainHeightAboveFallback) {
            return;
        }

        const int x = static_cast<int>(std::floor((point.x - heightfield.minX) / heightfield.cellSize));
        const int z = static_cast<int>(std::floor((point.z - heightfield.minZ) / heightfield.cellSize));

        if (x < 0 || x >= heightfield.width || z < 0 || z >= heightfield.depth) {
            return;
        }

        (*samples)[CellIndex(heightfield, x, z)].push_back(point.y);
    }

    void AddTriangleSamples(
        const GroundHeightfield& heightfield,
        std::vector<std::vector<float>>* samples,
        float fallbackY,
        Vector3 a,
        Vector3 b,
        Vector3 c
    ) {
        const Vector3 ab = Vector3Subtract(b, a);
        const Vector3 ac = Vector3Subtract(c, a);
        const Vector3 normal = Vector3CrossProduct(ab, ac);
        const float normalLength = Vector3Length(normal);

        if (normalLength <= 0.0001f) {
            return;
        }

        const float normalY = std::fabs(normal.y / normalLength);

        // On refuse les façades et pans presque verticaux.
        if (normalY < MinWalkableNormalY) {
            return;
        }

        const float minY = std::min(a.y, std::min(b.y, c.y));
        const float maxY = std::max(a.y, std::max(b.y, c.y));

        // On refuse les triangles trop hauts : sinon les toits deviennent du "sol".
        if (minY > fallbackY + MaxTerrainHeightAboveFallback) {
            return;
        }

        // On refuse les triangles trop inclinés/bruités verticalement.
        if ((maxY - minY) > MaxTriangleVerticalSpread) {
            return;
        }

        const Vector3 centroid = {
            (a.x + b.x + c.x) / 3.0f,
            (a.y + b.y + c.y) / 3.0f,
            (a.z + b.z + c.z) / 3.0f
        };

        AddSample(heightfield, samples, fallbackY, a);
        AddSample(heightfield, samples, fallbackY, b);
        AddSample(heightfield, samples, fallbackY, c);
        AddSample(heightfield, samples, fallbackY, centroid);
    }

    void FillMissingCellsFromNeighbors(GroundHeightfield* heightfield) {
        if (!heightfield->enabled) {
            return;
        }

        int totalFilled = 0;

        for (int pass = 0; pass < 8; ++pass) {
            std::vector<float> nextHeights = heightfield->heights;
            std::vector<unsigned char> nextHasData = heightfield->hasData;

            int filledThisPass = 0;

            for (int z = 0; z < heightfield->depth; ++z) {
                for (int x = 0; x < heightfield->width; ++x) {
                    const int index = CellIndex(*heightfield, x, z);

                    if (heightfield->hasData[index]) {
                        continue;
                    }

                    float sum = 0.0f;
                    int count = 0;

                    for (int dz = -1; dz <= 1; ++dz) {
                        for (int dx = -1; dx <= 1; ++dx) {
                            if (dx == 0 && dz == 0) {
                                continue;
                            }

                            const int nx = x + dx;
                            const int nz = z + dz;

                            if (nx < 0 || nx >= heightfield->width || nz < 0 || nz >= heightfield->depth) {
                                continue;
                            }

                            const int neighborIndex = CellIndex(*heightfield, nx, nz);

                            if (!heightfield->hasData[neighborIndex]) {
                                continue;
                            }

                            sum += heightfield->heights[neighborIndex];
                            count++;
                        }
                    }

                    if (count > 0) {
                        nextHeights[index] = sum / static_cast<float>(count);
                        nextHasData[index] = 1;
                        filledThisPass++;
                    }
                }
            }

            heightfield->heights = nextHeights;
            heightfield->hasData = nextHasData;

            totalFilled += filledThisPass;

            if (filledThisPass == 0) {
                break;
            }
        }

        heightfield->cellsFilledFromNeighbors = totalFilled;
    }

    void RecomputeHeightStats(GroundHeightfield* heightfield) {
        if (!heightfield->enabled || heightfield->heights.empty()) {
            heightfield->minHeight = 0.0f;
            heightfield->maxHeight = 0.0f;
            return;
        }

        float minHeight = FLT_MAX;
        float maxHeight = -FLT_MAX;

        for (float height : heightfield->heights) {
            minHeight = std::min(minHeight, height);
            maxHeight = std::max(maxHeight, height);
        }

        heightfield->minHeight = minHeight;
        heightfield->maxHeight = maxHeight;
    }
}


GroundHeightfield LoadGroundHeightfieldFromFile(
    const char* path,
    float fallbackY
) {
    GroundHeightfield heightfield = {};

    std::ifstream input(path);
    if (!input.is_open()) {
        return heightfield;
    }

    std::string line;
    bool gridRead = false;

    while (std::getline(input, line)) {
        if (line.empty() || line[0] == '#') {
            continue;
        }

        std::replace(line.begin(), line.end(), ',', '.');

        std::istringstream iss(line);
        std::string kind;
        iss >> kind;

        if (kind == "grid") {
            iss >>
                heightfield.minX >>
                heightfield.minZ >>
                heightfield.cellSize >>
                heightfield.width >>
                heightfield.depth >>
                heightfield.minHeight;

            if (iss.fail() || heightfield.width <= 0 || heightfield.depth <= 0 || heightfield.cellSize <= 0.0f) {
                heightfield = {};
                return heightfield;
            }

            heightfield.maxX = heightfield.minX + static_cast<float>(heightfield.width) * heightfield.cellSize;
            heightfield.maxZ = heightfield.minZ + static_cast<float>(heightfield.depth) * heightfield.cellSize;

            const int cellCount = heightfield.width * heightfield.depth;
            heightfield.heights.assign(cellCount, fallbackY);
            heightfield.hasData.assign(cellCount, 0);

            gridRead = true;
            continue;
        }

        if (kind == "cell" && gridRead) {
            int x = 0;
            int z = 0;
            float height = fallbackY;
            int sampleCount = 0;

            iss >> x >> z >> height >> sampleCount;

            if (iss.fail()) {
                continue;
            }

            if (x < 0 || x >= heightfield.width || z < 0 || z >= heightfield.depth) {
                continue;
            }

            const int index = CellIndex(heightfield, x, z);
            heightfield.heights[index] = height;
            heightfield.hasData[index] = 1;
            heightfield.cellsWithSamples++;
        }
    }

    heightfield.enabled = gridRead && heightfield.cellsWithSamples > 0;

    FillMissingCellsFromNeighbors(&heightfield);

    if (heightfield.enabled) {
        const int cellCount = heightfield.width * heightfield.depth;

        for (int i = 0; i < cellCount; ++i) {
            if (!heightfield.hasData[i]) {
                heightfield.heights[i] = fallbackY;
                heightfield.hasData[i] = 1;
            }
        }

        RecomputeHeightStats(&heightfield);
    }

    return heightfield;
}
GroundHeightfield BuildGroundHeightfieldFromModel(
    Model* model,
    const BoundingBox& bounds,
    float fallbackY,
    float cellSize
) {
    GroundHeightfield heightfield = {};

    heightfield.cellSize = std::max(1.0f, cellSize);
    heightfield.minX = std::floor(bounds.min.x / heightfield.cellSize) * heightfield.cellSize;
    heightfield.maxX = std::ceil(bounds.max.x / heightfield.cellSize) * heightfield.cellSize;
    heightfield.minZ = std::floor(bounds.min.z / heightfield.cellSize) * heightfield.cellSize;
    heightfield.maxZ = std::ceil(bounds.max.z / heightfield.cellSize) * heightfield.cellSize;

    heightfield.width = std::max(1, static_cast<int>(std::ceil((heightfield.maxX - heightfield.minX) / heightfield.cellSize)));
    heightfield.depth = std::max(1, static_cast<int>(std::ceil((heightfield.maxZ - heightfield.minZ) / heightfield.cellSize)));

    const int cellCount = heightfield.width * heightfield.depth;
    heightfield.heights.assign(cellCount, fallbackY);
    heightfield.hasData.assign(cellCount, 0);

    std::vector<std::vector<float>> samples;
    samples.resize(cellCount);

    for (int meshIndex = 0; meshIndex < model->meshCount; ++meshIndex) {
        const Mesh mesh = model->meshes[meshIndex];

        for (int triangleIndex = 0; triangleIndex < mesh.triangleCount; ++triangleIndex) {
            const Vector3 a = MeshTriangleVertex(mesh, triangleIndex, 0);
            const Vector3 b = MeshTriangleVertex(mesh, triangleIndex, 1);
            const Vector3 c = MeshTriangleVertex(mesh, triangleIndex, 2);

            AddTriangleSamples(heightfield, &samples, fallbackY, a, b, c);
        }
    }

    for (int i = 0; i < cellCount; ++i) {
        if (samples[i].empty()) {
            continue;
        }

        // Percentile bas plutôt que minimum brut :
        // on suit les points bas locaux sans se jeter dans le premier artefact.
        heightfield.heights[i] = Percentile(&samples[i], 0.12f);
        heightfield.hasData[i] = 1;
        heightfield.cellsWithSamples++;
    }

    heightfield.enabled = heightfield.cellsWithSamples > 0;

    FillMissingCellsFromNeighbors(&heightfield);

    for (int i = 0; i < cellCount; ++i) {
        if (!heightfield.hasData[i]) {
            heightfield.heights[i] = fallbackY;
            heightfield.hasData[i] = 1;
        }
    }

    RecomputeHeightStats(&heightfield);
    return heightfield;
}

float SampleGroundHeightAt(
    const GroundHeightfield& heightfield,
    float fallbackY,
    float x,
    float z
) {
    if (!heightfield.enabled || heightfield.width <= 0 || heightfield.depth <= 0 || heightfield.heights.empty()) {
        return fallbackY;
    }

    const float localX = (x - heightfield.minX) / heightfield.cellSize - 0.5f;
    const float localZ = (z - heightfield.minZ) / heightfield.cellSize - 0.5f;

    int x0 = static_cast<int>(std::floor(localX));
    int z0 = static_cast<int>(std::floor(localZ));

    float tx = localX - static_cast<float>(x0);
    float tz = localZ - static_cast<float>(z0);

    x0 = ClampInt(x0, 0, heightfield.width - 1);
    z0 = ClampInt(z0, 0, heightfield.depth - 1);

    int x1 = ClampInt(x0 + 1, 0, heightfield.width - 1);
    int z1 = ClampInt(z0 + 1, 0, heightfield.depth - 1);

    tx = ClampFloat(tx, 0.0f, 1.0f);
    tz = ClampFloat(tz, 0.0f, 1.0f);

    const float h00 = heightfield.heights[CellIndex(heightfield, x0, z0)];
    const float h10 = heightfield.heights[CellIndex(heightfield, x1, z0)];
    const float h01 = heightfield.heights[CellIndex(heightfield, x0, z1)];
    const float h11 = heightfield.heights[CellIndex(heightfield, x1, z1)];

    const float hx0 = h00 + (h10 - h00) * tx;
    const float hx1 = h01 + (h11 - h01) * tx;

    return hx0 + (hx1 - hx0) * tz;
}

void OffsetGroundHeightfield(
    GroundHeightfield* heightfield,
    float deltaY
) {
    if (!heightfield->enabled) {
        return;
    }

    for (float& height : heightfield->heights) {
        height += deltaY;
    }

    heightfield->minHeight += deltaY;
    heightfield->maxHeight += deltaY;
}

void DrawGroundHeightfieldDebug(
    const GroundHeightfield& heightfield
) {
    if (!heightfield.enabled || heightfield.width <= 1 || heightfield.depth <= 1) {
        return;
    }

    const int stride = std::max(1, static_cast<int>(std::ceil(std::max(heightfield.width, heightfield.depth) / 90.0f)));

    for (int z = 0; z < heightfield.depth; z += stride) {
        for (int x = 0; x < heightfield.width; x += stride) {
            const float worldX = heightfield.minX + (static_cast<float>(x) + 0.5f) * heightfield.cellSize;
            const float worldZ = heightfield.minZ + (static_cast<float>(z) + 0.5f) * heightfield.cellSize;
            const float worldY = heightfield.heights[CellIndex(heightfield, x, z)] + 0.06f;

            if (x + stride < heightfield.width) {
                const int nx = x + stride;
                const float nextX = heightfield.minX + (static_cast<float>(nx) + 0.5f) * heightfield.cellSize;
                const float nextY = heightfield.heights[CellIndex(heightfield, nx, z)] + 0.06f;

                DrawLine3D(
                    { worldX, worldY, worldZ },
                    { nextX, nextY, worldZ },
                    Fade(DARKGREEN, 0.75f)
                );
            }

            if (z + stride < heightfield.depth) {
                const int nz = z + stride;
                const float nextZ = heightfield.minZ + (static_cast<float>(nz) + 0.5f) * heightfield.cellSize;
                const float nextY = heightfield.heights[CellIndex(heightfield, x, nz)] + 0.06f;

                DrawLine3D(
                    { worldX, worldY, worldZ },
                    { worldX, nextY, nextZ },
                    Fade(DARKGREEN, 0.75f)
                );
            }
        }
    }
}


