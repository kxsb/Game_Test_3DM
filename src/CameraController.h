#pragma once

#include "Collision.h"
#include "raylib.h"

enum class CameraMovementMode {
    Fly,
    Walk
};

struct CameraControllerState {
    Vector3 initialPosition;
    Vector3 initialTarget;

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

    CameraMovementMode movementMode;
};

CameraControllerState CreateCameraController(const Camera3D& camera);
void UpdateCameraController(Camera3D* camera, CameraControllerState* state, const CollisionWorld& world);

const char* GetCameraMovementModeLabel(CameraMovementMode mode);
