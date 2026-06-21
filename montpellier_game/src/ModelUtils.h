//
// ModelUtils.h -- utility functions for manipulating raylib models
//
// These helpers provide simple bounding box computation and centering
// for models loaded via raylib.  When loading large datasets it is
// often convenient to recenter meshes around the origin so they fit
// more naturally within the camera frustum.

#pragma once

#include "raylib.h"

#ifdef __cplusplus
extern "C" {
#endif

/// Compute the axis‑aligned bounding box of a model by iterating
/// through all of its meshes.  The returned BoundingBox encloses
/// every vertex.  Note: normals and tangents are ignored.
BoundingBox GetModelBoundingBox(Model* model);

/// Translate the vertices of a model so that its geometric center
/// (midpoint between min and max of its bounding box) is at the origin.
/// The mesh GPU buffers are updated via UploadMesh().
void CenterModel(Model* model);

#ifdef __cplusplus
}
#endif