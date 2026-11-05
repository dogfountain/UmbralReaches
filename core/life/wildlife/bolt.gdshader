shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A lightning bolt (weather.gd builds the ribbons per strike: UV.x across, UV.y top..bottom,
// COLOR.a = branch strength). Sky layer like sky_flash.gdshader. A white-violet core in a blue halo;
// the branches fade toward their tips. Values stay modest: the glow budget is the lead's.

uniform float flash = 0.0;

void vertex() {
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION.z = POSITION.w * 0.000001;
}

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float core = smoothstep(0.4, 0.0, x);
	float halo = exp(-x * x * 2.5) * 0.6;
	float k = COLOR.a * mix(1.0, 0.35, step(COLOR.a, 0.9) * UV.y);
	vec3 c = vec3(0.92, 0.95, 1.25) * core * 2.1 + vec3(0.45, 0.55, 1.0) * halo;
	ALBEDO = c * k * flash;
}
