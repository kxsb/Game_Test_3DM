#pragma once

#include "raylib.h"

BoundingBox ComputeModelBoundingBox(Model* model);

// Transforme les vertices du modèle pour une scène de jeu urbaine :
// - centre le modèle en X/Z autour de l'origine ;
// - pose le bas du modèle sur groundY ;
// - conserve les hauteurs réelles au lieu de centrer verticalement.
void NormalizeModelToGround(Model* model, float groundY);

// Compatibilité avec les anciens appels.
void CenterModel(Model* model);
