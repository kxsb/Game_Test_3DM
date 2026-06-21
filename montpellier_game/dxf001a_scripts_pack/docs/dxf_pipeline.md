# DXF pipeline

Le modèle Montpellier est composé de fichiers DXF contenant des entités `3DFACE`.

## Inspecter un DXF

```powershell
.\scripts\dxf_inspect.ps1 -Path "..\VilleMTP_MTP_Modele3D\Centre_BATIMENTS_2016.dxf" -MaxFaces 10000
```

## Extraire un échantillon OBJ

```powershell
.\scripts\dxf_extract_sample_obj.ps1 `
  -Path "..\VilleMTP_MTP_Modele3D\Centre_BATIMENTS_2016.dxf" `
  -OutputPath "assets\models\dxf_sample_centre.obj" `
  -MaxFaces 5000
```

Puis lancer :

```powershell
.\scripts\run_windows.ps1 -ModelPath "assets\models\dxf_sample_centre.obj"
```

Transformation provisoire :

- Lambert X devient X jeu ;
- Lambert Y devient Z jeu ;
- altitude DXF Z devient Y jeu ;
- le modèle est recentré en X/Z ;
- le point le plus bas est posé sur `Y = 0`.
