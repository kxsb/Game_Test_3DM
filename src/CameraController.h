#pragma once

#include "raylib.h"

struct CameraControllerState {
    Vector3 initialPosition;
    Vector3 initialTarget;
    float yaw;
    float pitch;
    float moveSpeed;
    float mouseSensitivity;
    bool mouseLookEnabled;
};

CameraControllerState CreateCameraController(const Camera3D& camera);
void UpdateCameraController(Camera3D* camera, CameraControllerState* state);
