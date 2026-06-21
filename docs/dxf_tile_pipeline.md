# DXF tile pipeline, fix 1

This pack fixes the PowerShell `op_Division` crash by avoiding array-based point structures during tile extraction.

Usage:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_dxf_tile_centre.ps1 -Width 250 -Depth 250 -MaxFaces 50000
```

Optional explicit center:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_dxf_tile_centre.ps1 -Width 250 -Depth 250 -CenterX "770727.18" -CenterY "6279737.513"
```
