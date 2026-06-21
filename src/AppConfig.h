#pragma once

#include "raylib.h"

namespace AppConfig {
    constexpr int ScreenWidth = 1280;
    constexpr int ScreenHeight = 720;

    constexpr const char* WindowTitle = "Montpellier 3D Prototype";
    constexpr const char* PrototypeLabel = "Montpellier Game - Prototype 1O-FIX1-PHOTOMODEL-SAFE";
    constexpr const char* DefaultModelPath = "assets/models/example.glb";
    constexpr const char* DefaultPhotomodelPath = "data/raw/montpellier/photomodel_exports/C06_minimal/C06_minimal.obj";

    constexpr int TargetFps = 60;

    constexpr Vector3 InitialCameraPosition = { 18.0f, 1.75f, 18.0f };
    constexpr Vector3 InitialCameraTarget = { 0.0f, 1.75f, 0.0f };
    constexpr Vector3 CameraUp = { 0.0f, 1.0f, 0.0f };

    constexpr float CameraFovY = 45.0f;

    constexpr float InitialMoveSpeed = 6.0f;
    constexpr float MouseSensitivity = 0.0030f;

    constexpr float GroundY = 0.0f;
    constexpr float GroundHeightfieldCellSize = 6.0f;
    constexpr float MaxWalkSlopeRatio = 0.75f;
    constexpr float MaxWalkStepHeight = 0.65f;

    constexpr float WalkEyeHeight = 1.75f;
    constexpr float FlyMinEyeHeight = 0.35f;

    constexpr float PlayerRadius = 0.55f;
    constexpr float PlayerBodyHeight = 1.75f;

    constexpr int GridSlices = 40;
    constexpr float GridSpacing = 1.0f;
}














