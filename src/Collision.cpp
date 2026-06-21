#include "Collision.h"

#include "raymath.h"

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

        return (dx * dx + dz * dz) <= (body.radius * body.radius);
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

        return playerMaxY >= boxMinY && playerMinY <= boxMaxY;
    }

    bool PlayerVerticalOverlapsSegment(
        Vector3 eyePosition,
        const PlayerCollisionBody& body,
        const CollisionSegment& segment
    ) {
        const float playerMinY = eyePosition.y - body.eyeHeight;
        const float playerMaxY = playerMinY + body.height;

        const float segmentMinY = std::min(segment.minY, segment.maxY);
        const float segmentMaxY = std::max(segment.minY, segment.maxY);

        return playerMaxY >= segmentMinY && playerMinY <= segmentMaxY;
    }

    float DistanceSquaredPointToSegmentXZ(
        Vector3 point,
        Vector3 a,
        Vector3 b
    ) {
        const float abX = b.x - a.x;
        const float abZ = b.z - a.z;

        const float apX = point.x - a.x;
        const float apZ = point.z - a.z;

        const float abLengthSquared = abX * abX + abZ * abZ;

        if (abLengthSquared <= 0.000001f) {
            const float dx = point.x - a.x;
            const float dz = point.z - a.z;
            return dx * dx + dz * dz;
        }

        const float t = ClampFloat(
            (apX * abX + apZ * abZ) / abLengthSquared,
            0.0f,
            1.0f
        );

        const float nearestX = a.x + abX * t;
        const float nearestZ = a.z + abZ * t;

        const float dx = point.x - nearestX;
        const float dz = point.z - nearestZ;

        return dx * dx + dz * dz;
    }

    bool PlayerCylinderOverlapsSegmentXZ(
        Vector3 eyePosition,
        const PlayerCollisionBody& body,
        const CollisionSegment& segment
    ) {
        const float collisionRadius = body.radius + segment.thickness * 0.5f;
        const float distanceSquared = DistanceSquaredPointToSegmentXZ(
            eyePosition,
            segment.a,
            segment.b
        );

        return distanceSquared <= collisionRadius * collisionRadius;
    }

    float WalkEyeYAtPosition(
        Vector3 eyePosition,
        const PlayerCollisionBody& body,
        const CollisionWorld& world
    ) {
        return GetCollisionGroundYAtPosition(world, eyePosition.x, eyePosition.z) + body.eyeHeight;
    }

    bool IsGroundTransitionWalkable(
        Vector3 fromEyePosition,
        Vector3 toEyePosition,
        const CollisionWorld& world
    ) {
        const float dx = toEyePosition.x - fromEyePosition.x;
        const float dz = toEyePosition.z - fromEyePosition.z;
        const float horizontalDistance = std::sqrt(dx * dx + dz * dz);

        if (horizontalDistance <= 0.0001f) {
            return true;
        }

        const float deltaY = toEyePosition.y - fromEyePosition.y;

        if (std::fabs(deltaY) > world.maxWalkStepHeight) {
            return false;
        }

        const float slopeRatio = std::fabs(deltaY) / horizontalDistance;
        return slopeRatio <= world.maxWalkSlopeRatio;
    }

    Vector3 ResolveWalkMovementStep(
        Vector3 eyePosition,
        Vector3 movement,
        const PlayerCollisionBody& body,
        const CollisionWorld& world
    ) {
        Vector3 resolved = eyePosition;
        resolved.y = WalkEyeYAtPosition(resolved, body, world);

        Vector3 tryX = resolved;
        tryX.x += movement.x;
        tryX.y = WalkEyeYAtPosition(tryX, body, world);

        if (
            IsGroundTransitionWalkable(resolved, tryX, world) &&
            !IsPlayerCollidingAtPosition(tryX, body, world)
        ) {
            resolved = tryX;
        }

        Vector3 tryZ = resolved;
        tryZ.z += movement.z;
        tryZ.y = WalkEyeYAtPosition(tryZ, body, world);

        if (
            IsGroundTransitionWalkable(resolved, tryZ, world) &&
            !IsPlayerCollidingAtPosition(tryZ, body, world)
        ) {
            resolved = tryZ;
        }

        resolved.y = WalkEyeYAtPosition(resolved, body, world);
        return resolved;
    }
}

CollisionBox MakeCollisionBox(Vector3 center, Vector3 size) {
    CollisionBox box = {};
    box.center = center;
    box.size = size;
    return box;
}

float GetCollisionGroundYAtPosition(
    const CollisionWorld& world,
    float x,
    float z
) {
    return SampleGroundHeightAt(world.groundHeightfield, world.groundY, x, z);
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

    for (const CollisionSegment& segment : world.solidSegments) {
        if (!PlayerVerticalOverlapsSegment(eyePosition, body, segment)) {
            continue;
        }

        if (PlayerCylinderOverlapsSegmentXZ(eyePosition, body, segment)) {
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
    const float movementLength = Vector3Length(movement);

    if (movementLength <= 0.0001f) {
        return eyePosition;
    }

    // Anti-tunneling simple : on découpe les mouvements en petits pas.
    // Cela évite de traverser un bâtiment lorsque la vitesse est élevée.
    const float maxStep = std::max(0.05f, body.radius * 0.35f);
    const int steps = std::max(1, static_cast<int>(std::ceil(movementLength / maxStep)));

    Vector3 stepMovement = Vector3Scale(movement, 1.0f / static_cast<float>(steps));
    Vector3 resolved = eyePosition;

    for (int i = 0; i < steps; ++i) {
        resolved = ResolveWalkMovementStep(resolved, stepMovement, body, world);
    }

    return resolved;
}

void DrawCollisionWorldDebug(const CollisionWorld& world) {
    for (const CollisionBox& box : world.solidBoxes) {
        const float boxMinY = box.center.y - box.size.y * 0.5f;

        const float footprintHeight = 0.18f;
        const Vector3 footprintCenter = {
            box.center.x,
            boxMinY + footprintHeight * 0.5f,
            box.center.z
        };
        const Vector3 footprintSize = {
            box.size.x,
            footprintHeight,
            box.size.z
        };

        DrawCubeWiresV(footprintCenter, footprintSize, Fade(RED, 0.35f));
    }

    for (const CollisionSegment& segment : world.solidSegments) {
        const float y = std::min(segment.minY, segment.maxY) + 0.08f;
        const float topY = std::min(std::max(segment.minY, segment.maxY), y + 2.0f);

        const Vector3 a = { segment.a.x, y, segment.a.z };
        const Vector3 b = { segment.b.x, y, segment.b.z };
        const Vector3 aTop = { segment.a.x, topY, segment.a.z };
        const Vector3 bTop = { segment.b.x, topY, segment.b.z };

        DrawLine3D(a, b, RED);
        DrawLine3D(aTop, bTop, Fade(RED, 0.35f));
        DrawLine3D(a, aTop, Fade(RED, 0.25f));
        DrawLine3D(b, bTop, Fade(RED, 0.25f));
    }
}





