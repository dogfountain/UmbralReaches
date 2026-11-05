# Lighting log

Date | Change | Driver | avg ms | 1% low | shadowed positional | notes
--- | --- | --- | --- | --- | --- | ---
2026-10-31 | LightPolicy + greybox window rig + D7/D8/D10 + Balanced defaults | vulkan / Apple M4 Pro | unmeasured | unmeasured | 5 | LIGHTAUDIT total=73 omni=69 spot=3 dir=1 shadowed=6 fog_injecting=6. Palette stair_foot 0.076 luma / 0.1% bright; landing 0.161 / 1.0%; summit 0.108 / 1.0%. No rebake.
2026-11-05 | ENS art pass: grade de-crunch + warm_lean/violet_protect, height haze, aniso 0.5, exposure 1.12, lantern range x1.4, ground cavity/patches, foliage hue ramp (docs/enshrouded/art.md) | Metal / Apple M4 Pro | stress 2x2: new vs old within +-2 % | unchanged | unchanged | perf_tour --points-only --stress=2 A/B with --shader originals. No rebake.
