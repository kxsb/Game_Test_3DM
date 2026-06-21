#include "Scene.h"
#include "AppConfig.h"
#include "ModelUtils.h"

void LoadScene(Scene* scene, const char* modelPath) {
    scene->modelPath = modelPath;
    scene->proceduralCity = CreateProceduralCity();

    if (FileExists(modelPath)) {
        scene->model = LoadModel(modelPath);
        CenterModel(&scene->model);
        scene->modelLoaded = true;

        TraceLog(LOG_INFO, TextFormat("Loaded model: %s", modelPath));
    }
    else {
        scene->modelLoaded = false;

        TraceLog(
            LOG_WARNING,
            TextFormat("Model file '%s' not found. Using procedural city fallback.", modelPath)
        );
    }
}

void DrawScene(const Scene& scene) {
    DrawGrid(AppConfig::GridSlices, AppConfig::GridSpacing);

    if (scene.modelLoaded) {
        DrawModel(scene.model, { 0.0f, 0.0f, 0.0f }, 1.0f, LIGHTGRAY);
    }
    else {
        DrawProceduralCity(scene.proceduralCity);
    }
}

void UnloadScene(Scene* scene) {
    if (scene->modelLoaded) {
        UnloadModel(scene->model);
        scene->modelLoaded = false;
    }
}
