shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled, world_vertex_coords;
// Realm foliage cards (tree crowns, undergrowth, ground cover) on one atlas
// (art/textures/realm_foliage_atlas.png, tools/gen_realm_foliage.gd). Built by tree_gen.gd:
//   UV     atlas coordinates
//   UV2.x  sway weight: 0 where the card is held (twig, root), 1 at its free end
//   UV2.y  flutter phase 0..1 (per card)
//   COLOR  baked tint * crown/clump occlusion; multiplied by the MultiMesh instance colour
//   NORMAL baked "volume" normals (out of the crown / up out of a tuft), kept on both faces
// `ground` cards also part around push_pos (the player's feet) like world/zones/foliage.gdshader.

global uniform vec3 push_pos;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.42;
uniform float mip_boost = 0.32;        // alpha grows with mip level so distant cards don't thin out
uniform bool ground = false;
uniform float sway = 0.12;             // metres of slow sway at weight 1
uniform float flutter = 0.035;         // metres of fast leaf flutter
uniform float wind_speed = 1.1;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wave_length = 9.0;
uniform float wave_speed = 2.4;
uniform float push_radius = 1.5;
uniform float push_strength = 0.75;
uniform float backlight = 0.5;
uniform float rim_strength = 0.12;
uniform vec3 rim_color = vec3(0.4, 0.68, 1.0);
uniform float roughness = 0.82;
uniform float near_fade = 1.1;         // metres from the camera inside which cards dither out (0 = off); 1.6 filled a canopy interior with a coarse stipple (seen under the moor's oak)
// Distance thinning (realm_flora.gd sets it per undergrowth MultiMesh): while the chunk's origin
// is fade_end .. fade_end + 6 m from the camera (the engine's old fade band) its plants drop out one
// by one, and at fade_end + 6 m the engine culls the chunk. Dropped plants collapse in vertex() (no
// fragments). This replaced the engine's visibility-range fade, which drew a fading 24 m chunk
// alpha-blended (no depth prepass, every overlapping card shaded): up to ~6 ms at 4x pixels at the
// hub. 0 = no thinning (tree crowns).
instance uniform float fade_end = 0.0;
// Density LOD for ground cards (see vertex()): from thin_from metres (per plant) to fade_end the
// cover thins to thin_keep of its plants, survivors widened to keep the coverage. 0 = off.
// Tree crowns' distance fade (set per crown MultiMesh by the tree builder; 0 = the engine's own visibility-range dither, as before): the crown
// dissolves over crown_fade_end .. crown_fade_end + 6 m with a per-pixel interleaved-gradient dither (finer than the engine's coarse screen
// door) and is culled at crown_fade_end + 6 m with no engine fade. The crown keeps its size (the undergrowth's `fade_end` shrinks a plant
// into its origin, which would shrink a tree into its trunk).
instance uniform float crown_fade_end = 0.0;
uniform float thin_from = 0.0;
uniform float thin_keep = 0.6;

// ENS art pass (docs/enshrouded/art.md): painterly colour, not one flat green. Each plant or crown
// leans yellow-green or blue-green by a hash of its origin plus a broad world patch, and leaves get
// lighter toward their free ends (UV2.x) and darker at the held base: a hand-painted value ramp.
uniform float hue_var = 0.16;
uniform float tip_light = 0.26;
uniform float base_dark = 0.22;

// Wind you can see at night: where the travelling wave crest bends a plant over, its blades and
// leaves turn their paler sides to the sky, so each gust crosses the field as a soft band of light
// (the Ghost-of-Tsushima read, without a texture or extra vertex work). Scaled by the live `sway`
// (core/life/wildlife/weather.gd) so a calm night shows almost none. 0 = off.
uniform float wind_sheen = 0.0;
// Thin-leaf translucency: BACKLIGHT is the engine's cheap wrap transmission (light from behind a
// card shows through it). Free ends (UV2.x -> 1) are thin and pass more, held bases and the crown's
// occluded heart (baked into COLOR) pass less, and what comes through is a touch yellower and more
// saturated than the lit face, as light through a leaf is.
uniform vec3 transmit_tint = vec3(1.0, 1.08, 0.8);   // linear multiplier, not a colour pick
// r38 art pass: a backlit or moon-struck crown read neon lime (the albedo tint is boosted to lift a dark atlas, and the
// transmission multiplied the same saturated green again). Painterly leaves keep their value and lose chroma as they
// brighten: pull the lit/transmitted colour toward its luma (olive, not emerald). 0 = as it was.
uniform float lit_desat = 0.32;
uniform float transmit_desat = 0.5;

varying vec3 wpos;
varying float vhue;
varying float vwind;

void vertex() {
	bool collapsed = false;
	if (fade_end > 0.0) {
		// Distance thinning first, so a collapsed plant skips all the wind work below (whole
		// instances branch together: the GPU runs that test coherently).
		vec3 org = MODEL_MATRIX[3].xyz;
		float keep = fract(sin(dot(org.xz, vec2(12.9898, 78.233))) * 43758.5453);
		float dchunk = distance(NODE_POSITION_WORLD, CAMERA_POSITION_WORLD);
		// each plant shrinks away over 3 m instead of vanishing in one frame (Luke, 7 Nov: foliage popped): its own edge
		// is staggered through the 6 m band by its hash, and every edge falls inside the band, so all are gone by the
		// engine's cull at fade_end + 6 m
		float edge = fade_end + 3.0 + keep * 3.0;
		float shrink = 1.0 - smoothstep(edge - 3.0, edge, dchunk);
		float grow = 1.0;
		if (ground && thin_from > 0.0) {
			// density LOD: past thin_from (per plant) ground cover drops toward thin_keep of its
			// plants by fade_end, lowest hash first (the same order as the fade band, so nothing
			// pops back), and the survivors widen by 1/sqrt(kept) so the floor stays covered.
			// Distant grass is where cards stack deepest per pixel (grazing view, depth prepass on
			// every layer), so this trims the costliest overdraw for a carpet that reads the same.
			float kept = mix(1.0, thin_keep, smoothstep(min(thin_from, fade_end * 0.5), fade_end, distance(org, CAMERA_POSITION_WORLD)));
			// thinned plants shrink out across 6 % of the hash (a few metres of walking), not in one step
			shrink = min(shrink, smoothstep(1.0 - kept, 1.0 - kept + 0.06, keep));
			grow = inversesqrt(kept);
		}
		if (shrink <= 0.001) {
			collapsed = true;
			VERTEX = org;                   // collapsed: zero-area triangles draw nothing
			wpos = org;
			vhue = 0.0;
			vwind = 0.0;
		} else {
			VERTEX = org + (VERTEX - org) * vec3(grow, sqrt(grow), grow) * shrink;
		}
	}
	if (!collapsed) {
		wpos = VERTEX;
		vec2 o = MODEL_MATRIX[3].xz;
		float ih = fract(sin(dot(o, vec2(41.37, 289.11))) * 15731.743);
		float wpatch = sin(VERTEX.x * 0.071 + 1.3) * sin(VERTEX.z * 0.053 - 0.7);
		vhue = clamp((ih - 0.5) * 1.4 + wpatch * 0.6, -1.0, 1.0);
		float w = UV2.x;
		vec2 wd = normalize(wind_dir);
		float along = dot(VERTEX.xz, wd);
		float wave = sin((along - TIME * wave_speed) * TAU / wave_length);
		float phase = dot(VERTEX.xz, vec2(0.13, 0.11));
		float gust = sin(TIME * wind_speed + phase) * 0.6 + sin(TIME * wind_speed * 2.1 + phase * 1.9) * 0.4;
		vec3 off = vec3(wd.x, 0.0, wd.y) * mix(gust, wave, 0.5) * sway * w;
		vwind = smoothstep(0.15, 0.95, wave * 0.75 + gust * 0.25) * w * clamp(sway * 8.0, 0.0, 1.6);
		float ph = UV2.y * 6.2832;
		off += vec3(sin(TIME * 3.1 + ph), sin(TIME * 2.3 + ph * 1.7) * 0.6, cos(TIME * 2.7 + ph)) * flutter * w;
		if (ground) {
			vec2 to = VERTEX.xz - push_pos.xz;
			float d = length(to);
			if (d < push_radius && d > 0.0001 && abs(VERTEX.y - push_pos.y) < 2.0) {
				float f = pow(1.0 - d / push_radius, 2.0);
				off += vec3(to.x, -0.35 * d, to.y) / d * f * push_strength * w;
			}
		}
		VERTEX += off;
	}
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec2 sz = vec2(textureSize(albedo_tex, 0));
	vec2 dx = dFdx(UV * sz);
	vec2 dy = dFdy(UV * sz);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	// cards seen edge-on smear into streaks: thin them out by the true face angle
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float edge = smoothstep(0.06, 0.32, abs(dot(fn, VIEW)));
	// the willow's and the hanging moss's strands (atlas cells 3 and 15, column 4): the boost filled the gaps between
	// strands at range and a curtain read as a solid green slab; theirs is a fifth as strong
	float boost = (UV.x > 0.75 && (UV.y < 0.25 || UV.y > 0.75)) ? mip_boost * 0.2 : mip_boost;
	ALPHA = clamp(t.a * (1.0 + lod * boost), 0.0, 1.0) * edge;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	// a crown or willow curtain the camera has backed into filled half the frame with leaves (the
	// camera collides with the world only): cards dither away inside ~1.6 m of the camera. In a
	// directional shadow pass the "camera" is far off, so shadows are untouched.
	float cam_d = distance(wpos, CAMERA_POSITION_WORLD);
	float nf = wpos.y > CAMERA_POSITION_WORLD.y + 1.5 ? near_fade * 2.5 : near_fade;     // cards overhead (the camera under a crown) clear out to 4 m: the wood opens up
	if (cam_d < nf) {
		float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (smoothstep(nf * 0.55, nf, cam_d) < ign) {
			discard;
		}
	}
	if (crown_fade_end > 0.0 && !ground) {
		float cf = 1.0 - smoothstep(crown_fade_end, crown_fade_end + 6.0, cam_d);
		float ign2 = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (cf < ign2) {
			discard;
		}
	}
	// the baked volume normal lights both faces alike (undo the back-face flip)
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 c = t.rgb * tint * COLOR.rgb;
	float mottle = 0.93 + 0.07 * sin(wpos.x * 7.0 + wpos.z * 5.0 + wpos.y * 3.0);
	vec3 warm_g = c * vec3(1.14, 1.06, 0.74);
	vec3 cool_g = c * vec3(0.84, 1.0, 1.12);
	c = mix(c, vhue > 0.0 ? warm_g : cool_g, abs(vhue) * hue_var * 3.0);
	float tip = clamp(UV2.x, 0.0, 1.0);
	c *= mix(1.0 - base_dark, 1.0 + tip_light, tip);
	c *= 1.0 + wind_sheen * vwind;
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	// the brighter the leaf, the more chroma it gives up (dark leaves keep their deep greens); a touch of warmth back
	// grass was the loudest thing in the night (an emerald brighter than the path it grew beside): ground cards give up a share of
	// chroma too, and take a soft shoulder on value so a tuft never outshines what it hides
	c = mix(c, vec3(lum) * vec3(1.06, 1.0, 0.86), (ground ? lit_desat * 0.45 : lit_desat) * smoothstep(0.03, 0.25, lum));
	if (ground) {
		c /= 1.0 + 1.1 * max(lum - 0.09, 0.0);
		c *= vec3(0.95, 1.0, 1.03);
	}
	// the brightest crowns (young birches, sunlit oak tips) took the moon at full value: a shoulder keeps them leaf-green, not mint
	// shrubs and brambles are ground cards (atlas cells 4 and 5, row 2, columns 1 and 2) but read as bright mint crowns: same treatment
	bool shrub = ground && UV.y > 0.25 && UV.y < 0.5 && UV.x < 0.5;
	if (!ground || shrub) {
		float lum2 = dot(c, vec3(0.2126, 0.7152, 0.0722));
		// the brightest cards (the pale mint shrub clusters) lose most of their chroma on top of the shoulder
		c = mix(c, vec3(lum2) * vec3(1.06, 1.0, 0.86), (shrub ? lit_desat : 0.0) * smoothstep(0.03, 0.25, lum2) + 0.5 * smoothstep(0.16, 0.4, lum2));
		// shrubs sit at the crowns' value, not above it: brought to a fixed mid value by luminance, not just desaturated
		if (shrub) {
			c *= 0.62;
		}
		c /= 1.0 + 2.0 * max(lum2 - 0.14, 0.0);
	}
	// the birch cell (atlas column 1, row 0) is the pale round-leaved crown of the young birches and saplings, and the same leaf on
	// ground-card sprays (the bright mint plant under the oak): to the crowns' value on every material
	if (UV.x > 0.25 && UV.x < 0.5 && UV.y < 0.25) {
		c *= ground ? 0.55 : 0.68;
	}
	ALBEDO = c * mottle;
	ROUGHNESS = roughness;
	vec3 thin = mix(ALBEDO, vec3(dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722))) * vec3(1.05, 1.0, 0.8), (ground ? 0.2 : transmit_desat));
	BACKLIGHT = backlight * mix(0.6, 1.3, tip) * transmit_tint * thin;
	EMISSION = rim_color * rim_strength * pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0) * ALBEDO * 3.0;
}
