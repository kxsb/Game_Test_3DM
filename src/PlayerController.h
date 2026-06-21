#pragma once

#include "Collision.h"
#include "raylib.h"

enum class PlayerMovementMode {
    Fly,
    Walk
};

struct PlayerControllerState {
    Vector3 initialPosition;
    Vector3 initialTarget;
    Vector3 position;

    float yaw;
    float pitch;
    float moveSpeed;
    float mouseSensitivity;

    float groundY;
    float walkEyeHeight;
    float flyMinEyeHeight;

    float playerRadius;
    float playerBodyHeight;

    bool mouseLookEnabled;

    bool collisionDebugEnabled;
    bool groundDebugEnabled;
    bool wireframeDebugEnabled;
    bool boundsDebugEnabled;

    PlayerMovementMode movementMode;
};

PlayerControllerState CreatePlayerController(const Camera3D& initialCamera);

void UpdatePlayerController(
    PlayerControllerState* player,
    const CollisionWorld& world
);

void ApplyPlayerToCamera(
    const PlayerControllerState& player,
    Camera3D* camera
);

const char* GetPlayerMovementModeLabel(PlayerMovementMode mode);

