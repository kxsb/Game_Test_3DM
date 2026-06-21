//
// ModelUtils.cpp -- implementation of simple model manipulation
//
// This source file defines helpers to compute a bounding box and
// centre a raylib Model around the origin.  These utilities are
// useful when loading models with very large world coordinates, such
// as georeferenced CAD exports.  Bringing the geometry near the
// origin improves depth buffer precision and camera control.

#include "ModelUtils.h"
#include <float.h>

// Compute the axisâ€‘aligned bounding box for the given model.  We
// iterate over each mesh and each vertex, tracking the minimum and
// maximum coordinates on each axis.  Raysan's Mesh structure
// stores positions in the `vertices` array as interleaved floats
// [x0,y0,z0,x1,y1,z1,...].
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
    BoundingBox box;
    box.min = min;
    box.max = max;
    return box;
}

// Translate the model so that its centre lies at the origin.  We
// compute the bounding box, derive the centre as the midpoint
// between min and max, then subtract that centre from every vertex.
// After modifying CPUâ€‘side vertex data we call UploadMesh() to send
// the updated positions to the GPU.  We do not modify bones or
// animations here.
void CenterModel(Model* model) {
    BoundingBox box = ComputeModelBoundingBox(model);
    Vector3 centre;
    centre.x = (box.min.x + box.max.x) * 0.5f;
    centre.y = (box.min.y + box.max.y) * 0.5f;
    centre.z = (box.min.z + box.max.z) * 0.5f;

    for (int meshIndex = 0; meshIndex < model->meshCount; meshIndex++) {
        Mesh* mesh = &model->meshes[meshIndex];
        for (int v = 0; v < mesh->vertexCount; v++) {
            mesh->vertices[3 * v + 0] -= centre.x;
            mesh->vertices[3 * v + 1] -= centre.y;
            mesh->vertices[3 * v + 2] -= centre.z;
        }
        // Upload the modified vertex buffer to GPU.  The second
        // parameter indicates whether the old GPU buffers should be
        // deleted (false keeps them allocated and simply updates
        // their contents).  Setting this parameter to false avoids
        // unnecessary reallocation.
        UploadMesh(mesh, false);
    }
}

