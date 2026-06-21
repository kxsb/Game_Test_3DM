#include "CameraController.h"
#include "AppConfig.h"
#include "raymath.h"

#include <algorithm>
#include <cmath>

namespace {
    constexpr float Pi = 3.14159265358979323846f;

    float ClampFloat(float value, float minValue, float maxValue) {
        return std::max(minValue, std::min(value, maxValue));
    }

    Vector3 ForwardFromAngles(float yaw, float pitch) {
        Vector3 forward = {
            std::cos(pitch) * std::sin(yaw),
            std::sin(pitch),
            std::cos(pitch) * std::cos(yaw)
        };

        return Vector3Normalize(forward);
    }

    Vector3 FlatForwardFromAngles(float yaw) {
        Vector3 forward = {
            std::sin(yaw),
            0.0f,
            std::cos(yaw)
        };

        return Vector3Normalize(forward);
    }

    Vector3 RightFromFlatForward(Vector3 flatForward) {
        // Main droite corrigée pour le repère raylib utilisé ici.
        // Avant : { flatForward.z, 0, -flatForward.x }, ce qui inversait droite/gauche.
        Vector3 right = {
            -flatForward.z,
            0.0f,
            flatForward.x
        };

        return Vector3Normalize(right);
    }

    void UpdateAnglesFromCamera(Camera3D* camera, CameraControllerState* state) {
        Vector3 direction = Vector3Normalize(Vector3Subtract(camera->target, camera->position));

        state->yaw = std::atan2(direction.x, direction.z);
        state->pitch = std::asin(ClampFloat(direction.y, -1.0f, 1.0f));
    }

    float WalkEyeY(const CameraControllerState* state) {
        return state->groundY + state->walkEyeHeight;
    }

    float FlyMinY(const CameraControllerState* state) {
        return state->groundY + state->flyMinEyeHeight;
    }

    void ApplyGroundConstraint(Camera3D* camera, const CameraControllerState* state) {
        if (state->movementMode == CameraMovementMode::Walk) {
            camera->position.y = WalkEyeY(state);
            return;
        }

        if (camera->position.y < FlyMinY(state)) {
            camera->position.y = FlyMinY(state);
        }
    }
}

const char* GetCameraMovementModeLabel(CameraMovementMode mode) {
    switch (mode) {
        case CameraMovementMode::Fly:
            return "Vol libre";
        case CameraMovementMode::Walk:
            return "Marche";
        default:
            return "Inconnu";
    }
}

CameraControllerState CreateCameraController(const Camera3D& camera) {
    CameraControllerState state = {};

    state.initialPosition = camera.position;
    state.initialTarget = camera.target;

    state.moveSpeed = AppConfig::InitialMoveSpeed;
    state.mouseSensitivity = AppConfig::MouseSensitivity;

    state.groundY = AppConfig::GroundY;
    state.walkEyeHeight = AppConfig::WalkEyeHeight;
    state.flyMinEyeHeight = AppConfig::FlyMinEyeHeight;

    state.mouseLookEnabled = true;
    state.movementMode = CameraMovementMode::Fly;

    Vector3 direction = Vector3Normalize(Vector3Subtract(camera.target, camera.position));

    state.yaw = std::atan2(direction.x, direction.z);
    state.pitch = std::asin(ClampFloat(direction.y, -1.0f, 1.0f));

    DisableCursor();

    return state;
}

void UpdateCameraController(Camera3D* camera, CameraControllerState* state) {
    const float dt = GetFrameTime();

    if (IsKeyPressed(KEY_TAB)) {
        state->mouseLookEnabled = !state->mouseLookEnabled;

        if (state->mouseLookEnabled) {
            DisableCursor();
        }
        else {
            EnableCursor();
        }
    }

    if (IsKeyPressed(KEY_F)) {
        if (state->movementMode == CameraMovementMode::Fly) {
            state->movementMode = CameraMovementMode::Walk;
        }
        else {
            state->movementMode = CameraMovementMode::Fly;
        }

        ApplyGroundConstraint(camera, state);
    }

    if (IsKeyPressed(KEY_R)) {
        camera->position = state->initialPosition;
        camera->target = state->initialTarget;
        UpdateAnglesFromCamera(camera, state);
        ApplyGroundConstraint(camera, state);
    }

    const float wheel = GetMouseWheelMove();

    if (wheel != 0.0f) {
        state->moveSpeed = ClampFloat(state->moveSpeed + wheel * 1.5f, 1.0f, 80.0f);
    }

    if (state->mouseLookEnabled) {
        Vector2 delta = GetMouseDelta();

        state->yaw -= delta.x * state->mouseSensitivity;
        state->pitch -= delta.y * state->mouseSensitivity;
        state->pitch = ClampFloat(state->pitch, -Pi * 0.48f, Pi * 0.48f);
    }

    Vector3 forward = ForwardFromAngles(state->yaw, state->pitch);
    Vector3 flatForward = FlatForwardFromAngles(state->yaw);
    Vector3 right = RightFromFlatForward(flatForward);
    Vector3 up = { 0.0f, 1.0f, 0.0f };

    float speed = state->moveSpeed;

    if (IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT)) {
        speed *= 3.0f;
    }

    if (IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL)) {
        speed *= 0.35f;
    }

    Vector3 movement = { 0.0f, 0.0f, 0.0f };

    // AZERTY + QWERTY friendly:
    // Z/W forward, S backward, Q/A left, D right.
    if (IsKeyDown(KEY_W) || IsKeyDown(KEY_Z)) {
        movement = Vector3Add(movement, flatForward);
    }

    if (IsKeyDown(KEY_S)) {
        movement = Vector3Subtract(movement, flatForward);
    }

    if (IsKeyDown(KEY_D)) {
        movement = Vector3Add(movement, right);
    }

    if (IsKeyDown(KEY_A) || IsKeyDown(KEY_Q)) {
        movement = Vector3Subtract(movement, right);
    }

    if (state->movementMode == CameraMovementMode::Fly) {
        if (IsKeyDown(KEY_E)) {
            movement = Vector3Add(movement, up);
        }

        if (IsKeyDown(KEY_C)) {
            movement = Vector3Subtract(movement, up);
        }
    }

    if (Vector3Length(movement) > 0.0001f) {
        movement = Vector3Scale(Vector3Normalize(movement), speed * dt);
        camera->position = Vector3Add(camera->position, movement);
    }

    ApplyGroundConstraint(camera, state);

    camera->target = Vector3Add(camera->position, forward);
}
