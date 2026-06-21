#pragma once

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

    bool mouseLookEnabled;

    CameraMovementMode movementMode;
};

CameraControllerState CreateCameraController(const Camera3D& camera);
void UpdateCameraController(Camera3D* camera, CameraControllerState* state);

const char* GetCameraMovementModeLabel(CameraMovementMode mode);
