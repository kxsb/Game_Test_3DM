#pragma once

#include "raylib.h"

#include <vector>

struct CollisionBox {
    Vector3 center;
    Vector3 size;
};

struct CollisionWorld {
    float groundY = 0.0f;
    std::vector<CollisionBox> solidBoxes;
};

struct PlayerCollisionBody {
    float radius = 0.35f;
    float height = 1.75f;
    float eyeHeight = 1.75f;
};

CollisionBox MakeCollisionBox(Vector3 center, Vector3 size);

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
