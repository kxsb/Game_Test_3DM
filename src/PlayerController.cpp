#include "PlayerController.h"
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
        Vector3 right = {
            -flatForward.z,
            0.0f,
            flatForward.x
        };

        return Vector3Normalize(right);
    }

    void UpdateAnglesFromTarget(PlayerControllerState* player, Vector3 target) {
        Vector3 direction = Vector3Normalize(Vector3Subtract(target, player->position));

        player->yaw = std::atan2(direction.x, direction.z);
        player->pitch = std::asin(ClampFloat(direction.y, -1.0f, 1.0f));
    }

    float WalkEyeY(const PlayerControllerState* player, const CollisionWorld& world) {
        return world.groundY + player->walkEyeHeight;
    }

    float FlyMinY(const PlayerControllerState* player, const CollisionWorld& world) {
        return world.groundY + player->flyMinEyeHeight;
    }

    PlayerCollisionBody CreatePlayerBody(const PlayerControllerState* player) {
        PlayerCollisionBody body = {};
        body.radius = player->playerRadius;
        body.height = player->playerBodyHeight;
        body.eyeHeight = player->walkEyeHeight;
        return body;
    }

    void EnterWalkMode(PlayerControllerState* player, const CollisionWorld& world) {
        player->movementMode = PlayerMovementMode::Walk;
        player->position.y = WalkEyeY(player, world);
    }

    void EnterFlyMode(PlayerControllerState* player, const CollisionWorld& world) {
        player->movementMode = PlayerMovementMode::Fly;

        if (player->position.y < FlyMinY(player, world)) {
            player->position.y = FlyMinY(player, world);
        }
    }

    void ApplyGroundConstraint(PlayerControllerState* player, const CollisionWorld& world) {
        if (player->movementMode == PlayerMovementMode::Walk) {
            player->position.y = WalkEyeY(player, world);
            return;
        }

        if (player->position.y < FlyMinY(player, world)) {
            player->position.y = FlyMinY(player, world);
        }
    }
}

const char* GetPlayerMovementModeLabel(PlayerMovementMode mode) {
    switch (mode) {
        case PlayerMovementMode::Fly:
            return "Vol libre";
        case PlayerMovementMode::Walk:
            return "Marche";
        default:
            return "Inconnu";
    }
}

PlayerControllerState CreatePlayerController(const Camera3D& initialCamera) {
    PlayerControllerState player = {};

    player.initialPosition = initialCamera.position;
    player.initialTarget = initialCamera.target;
    player.position = initialCamera.position;

    player.moveSpeed = AppConfig::InitialMoveSpeed;
    player.mouseSensitivity = AppConfig::MouseSensitivity;

    player.groundY = AppConfig::GroundY;
    player.walkEyeHeight = AppConfig::WalkEyeHeight;
    player.flyMinEyeHeight = AppConfig::FlyMinEyeHeight;

    player.playerRadius = AppConfig::PlayerRadius;
    player.playerBodyHeight = AppConfig::PlayerBodyHeight;

    player.mouseLookEnabled = true;
    player.collisionDebugEnabled = false;

    player.movementMode = PlayerMovementMode::Walk;

    UpdateAnglesFromTarget(&player, initialCamera.target);

    DisableCursor();

    return player;
}

void UpdatePlayerController(PlayerControllerState* player, const CollisionWorld& world) {
    const float dt = GetFrameTime();

    if (IsKeyPressed(KEY_TAB)) {
        player->mouseLookEnabled = !player->mouseLookEnabled;

        if (player->mouseLookEnabled) {
            DisableCursor();
        }
        else {
            EnableCursor();
        }
    }

    if (IsKeyPressed(KEY_B)) {
        player->collisionDebugEnabled = !player->collisionDebugEnabled;
    }

    if (IsKeyPressed(KEY_F)) {
        if (player->movementMode == PlayerMovementMode::Walk) {
            EnterFlyMode(player, world);
        }
        else {
            EnterWalkMode(player, world);
        }
    }

    if (IsKeyPressed(KEY_R)) {
        player->position = player->initialPosition;
        UpdateAnglesFromTarget(player, player->initialTarget);

        if (player->movementMode == PlayerMovementMode::Walk) {
            EnterWalkMode(player, world);
        }
        else {
            EnterFlyMode(player, world);
        }
    }

    const float wheel = GetMouseWheelMove();

    if (wheel != 0.0f) {
        player->moveSpeed = ClampFloat(player->moveSpeed + wheel * 1.5f, 1.0f, 80.0f);
    }

    if (player->mouseLookEnabled) {
        Vector2 delta = GetMouseDelta();

        player->yaw -= delta.x * player->mouseSensitivity;
        player->pitch -= delta.y * player->mouseSensitivity;
        player->pitch = ClampFloat(player->pitch, -Pi * 0.48f, Pi * 0.48f);
    }

    Vector3 flatForward = FlatForwardFromAngles(player->yaw);
    Vector3 right = RightFromFlatForward(flatForward);
    Vector3 up = { 0.0f, 1.0f, 0.0f };

    float speed = player->moveSpeed;

    if (IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT)) {
        speed *= 3.0f;
    }

    if (IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL)) {
        speed *= 0.35f;
    }

    Vector3 movement = { 0.0f, 0.0f, 0.0f };

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

    if (player->movementMode == PlayerMovementMode::Fly) {
        if (IsKeyDown(KEY_E)) {
            movement = Vector3Add(movement, up);
        }

        if (IsKeyDown(KEY_C)) {
            movement = Vector3Subtract(movement, up);
        }
    }

    if (Vector3Length(movement) > 0.0001f) {
        movement = Vector3Scale(Vector3Normalize(movement), speed * dt);

        if (player->movementMode == PlayerMovementMode::Walk) {
            PlayerCollisionBody body = CreatePlayerBody(player);
            player->position = ResolveWalkMovement(player->position, movement, body, world);
        }
        else {
            player->position = Vector3Add(player->position, movement);
        }
    }

    ApplyGroundConstraint(player, world);
}

void ApplyPlayerToCamera(const PlayerControllerState& player, Camera3D* camera) {
    camera->position = player.position;
    camera->target = Vector3Add(player.position, ForwardFromAngles(player.yaw, player.pitch));
}
