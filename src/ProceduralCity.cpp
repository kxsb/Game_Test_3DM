#include "ProceduralCity.h"

ProceduralCity CreateProceduralCity() {
    ProceduralCity city;

    const int gridRadius = 4;
    const float spacing = 4.0f;

    for (int x = -gridRadius; x <= gridRadius; ++x) {
        for (int z = -gridRadius; z <= gridRadius; ++z) {
            // On garde quelques rues vides pour donner une structure lisible.
            if (x == 0 || z == 0) continue;
            if ((x + z) % 5 == 0) continue;

            const float height = 1.5f + static_cast<float>((x * x + z * z) % 7);
            const float width = 1.8f + static_cast<float>((x + gridRadius) % 3) * 0.35f;
            const float depth = 1.8f + static_cast<float>((z + gridRadius) % 3) * 0.35f;

            ProceduralBuilding building;
            building.size = { width, height, depth };
            building.position = {
                static_cast<float>(x) * spacing,
                height * 0.5f,
                static_cast<float>(z) * spacing
            };

            const unsigned char shade = static_cast<unsigned char>(120 + ((x * 13 + z * 29 + 255) % 80));
            building.color = { shade, static_cast<unsigned char>(shade + 10), static_cast<unsigned char>(shade + 20), 255 };

            city.buildings.push_back(building);
        }
    }

    return city;
}

void DrawProceduralCity(const ProceduralCity& city) {
    for (const ProceduralBuilding& building : city.buildings) {
        DrawCubeV(building.position, building.size, building.color);
        DrawCubeWiresV(building.position, building.size, DARKGRAY);
    }
}
