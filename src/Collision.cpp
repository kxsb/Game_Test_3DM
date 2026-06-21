#include "Collision.h"

#include <algorithm>
#include <cmath>

namespace {
    float ClampFloat(float value, float minValue, float maxValue) {
        return std::max(minValue, std::min(value, maxValue));
    }

    bool PlayerCylinderOverlapsBoxXZ(
        Vector3 eyePosition,
        const PlayerCollisionBody& body,
        const CollisionBox& box
    ) {
        const float boxMinX = box.center.x - box.size.x * 0.5f;
        const float boxMaxX = box.center.x + box.size.x * 0.5f;
        const float boxMinZ = box.center.z - box.size.z * 0.5f;
        const float boxMaxZ = box.center.z + box.size.z * 0.5f;

        const float nearestX = ClampFloat(eyePosition.x, boxMinX, boxMaxX);
        const float nearestZ = ClampFloat(eyePosition.z, boxMinZ, boxMaxZ);

        const float dx = eyePosition.x - nearestX;
        const float dz = eyePosition.z - nearestZ;

        return (dx * dx + dz * dz) < (body.radius * body.radius);
    }

    bool PlayerVerticalOverlapsBox(
        Vector3 eyePosition,
        const PlayerCollisionBody& body,
        const CollisionBox& box
    ) {
        const float playerMinY = eyePosition.y - body.eyeHeight;
        const float playerMaxY = playerMinY + body.height;

        const float boxMinY = box.center.y - box.size.y * 0.5f;
        const float boxMaxY = box.center.y + box.size.y * 0.5f;

        return playerMaxY > boxMinY && playerMinY < boxMaxY;
    }
}

CollisionBox MakeCollisionBox(Vector3 center, Vector3 size) {
    CollisionBox box = {};
    box.center = center;
    box.size = size;
    return box;
}

bool IsPlayerCollidingAtPosition(
    Vector3 eyePosition,
    const PlayerCollisionBody& body,
    const CollisionWorld& world
) {
    for (const CollisionBox& box : world.solidBoxes) {
        if (!PlayerVerticalOverlapsBox(eyePosition, body, box)) {
            continue;
        }

        if (PlayerCylinderOverlapsBoxXZ(eyePosition, body, box)) {
            return true;
        }
    }

    return false;
}

Vector3 ResolveWalkMovement(
    Vector3 eyePosition,
    Vector3 movement,
    const PlayerCollisionBody& body,
    const CollisionWorld& world
) {
    Vector3 resolved = eyePosition;

    // Résolution axe par axe : cela donne une glisse simple le long des murs,
    // au lieu de bloquer tout le mouvement diagonal.
    Vector3 tryX = resolved;
    tryX.x += movement.x;

    if (!IsPlayerCollidingAtPosition(tryX, body, world)) {
        resolved.x = tryX.x;
    }

    Vector3 tryZ = resolved;
    tryZ.z += movement.z;

    if (!IsPlayerCollidingAtPosition(tryZ, body, world)) {
        resolved.z = tryZ.z;
    }

    return resolved;
}
