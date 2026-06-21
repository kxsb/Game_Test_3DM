# DXF tile pipeline

DXF001B ajoute une extraction spatiale par fenêtre.

Exemple depuis la racine du projet :

```powershell
.\scripts\run_dxf_tile_centre.ps1 -Width 250 -Depth 250 -MaxFaces 50000
```

Ou avec un centre Lambert explicite :

```powershell
.\scripts\dxf_extract_tile_obj.ps1 `
  -Path "..\VilleMTP_MTP_Modele3D\Centre_BATIMENTS_2016.dxf" `
  -OutputPath "assets\models\dxf_tile_custom.obj" `
  -CenterX 770000 `
  -CenterY 6282000 `
  -Width 200 `
  -Depth 200 `
  -MaxFaces 50000

.\scripts\run_windows.ps1 -ModelPath "assets\models\dxf_tile_custom.obj"
```

But : éviter l'effet « premières faces du fichier » et obtenir un morceau urbain cohérent.
