shader_type spatial;
// Lit glass and live coals (OssKit "glow"): a lantern's panes, a window, a cresset's bed of coals. The kit's boxes have no
// UVs, so the pattern is laid in world space on the face's own plane: upright faces get leaded quarries (a diamond lattice of
// dark came, each pane a little hotter or cooler than its neighbours), flat faces a mottle of hot and dull coals. Glass seen
// edge-on dims, so each face of a lantern reads at its own brightness instead of one flat orange plate. Far off, where the
// lattice is finer than a pixel, it blends to the glass's average (no shimmer).
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://world/areas/ossuary/oss_glow.gdshaderinc"
