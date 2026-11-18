shader_type spatial;
// OssKit "glow" drawn from its front only (a window pane seen from inside a room shows the night through its leading)
render_mode unshaded, cull_back, shadows_disabled;

#include "res://world/areas/ossuary/oss_glow.gdshaderinc"
