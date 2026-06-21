#pragma once

#include "GroundHeightfield.h"
#include "raylib.h"

#include <vector>

struct CollisionBox {
    Vector3 center;
    Vector3 size;
};

struct CollisionWorld {
    float groundY = 0.0f;

    GroundHeightfield groundHeightfield;

    float maxWalkSlopeRatio = 0.75f;
    float maxWalkStepHeight = 0.65f;

    std::vector<CollisionBox> solidBoxes;
};

struct PlayerCollisionBody {
    float radius = 0.55f;
    float height = 1.75f;
    float eyeHeight = 1.75f;
};

CollisionBox MakeCollisionBox(Vector3 center, Vector3 size);

float GetCollisionGroundYAtPosition(
    const CollisionWorld& world,
    float x,
    float z
);

bool IsPlayerCollidingAtPosition(
    Vector3 eyePosition,
    const PlayerCollisionBody& body,
    const CollisionWorld& world
);

Vector3 ResolveWalkMovement(
    Vector3 eyePosition,
    Vector3 movement,
    const PlayerCollisionBody& body,
    const CollisionWorld& world
);

void DrawCollisionWorldDebug(const CollisionWorld& world);



