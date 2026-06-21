#include "ModelUtils.h"

#include <float.h>

BoundingBox ComputeModelBoundingBox(Model* model) {
    Vector3 min = { FLT_MAX, FLT_MAX, FLT_MAX };
    Vector3 max = { -FLT_MAX, -FLT_MAX, -FLT_MAX };

    for (int meshIndex = 0; meshIndex < model->meshCount; meshIndex++) {
        Mesh mesh = model->meshes[meshIndex];

        for (int v = 0; v < mesh.vertexCount; v++) {
            float x = mesh.vertices[3 * v + 0];
            float y = mesh.vertices[3 * v + 1];
            float z = mesh.vertices[3 * v + 2];

            if (x < min.x) min.x = x;
            if (y < min.y) min.y = y;
            if (z < min.z) min.z = z;

            if (x > max.x) max.x = x;
            if (y > max.y) max.y = y;
            if (z > max.z) max.z = z;
        }
    }

    BoundingBox box = {};
    box.min = min;
    box.max = max;
    return box;
}

void NormalizeModelToGround(Model* model, float groundY) {
    BoundingBox box = ComputeModelBoundingBox(model);

    const float centerX = (box.min.x + box.max.x) * 0.5f;
    const float centerZ = (box.min.z + box.max.z) * 0.5f;

    const float offsetX = centerX;
    const float offsetY = box.min.y - groundY;
    const float offsetZ = centerZ;

    for (int meshIndex = 0; meshIndex < model->meshCount; meshIndex++) {
        Mesh* mesh = &model->meshes[meshIndex];

        for (int v = 0; v < mesh->vertexCount; v++) {
            mesh->vertices[3 * v + 0] -= offsetX;
            mesh->vertices[3 * v + 1] -= offsetY;
            mesh->vertices[3 * v + 2] -= offsetZ;
        }

        UploadMesh(mesh, false);
    }
}

void CenterModel(Model* model) {
    NormalizeModelToGround(model, 0.0f);
}
