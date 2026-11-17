shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Realm ground (core/world/realm/realm_land.gd). Biome splat from vertex data:
//   COLOR  r meadow  g forest loam  b fen mud  a ash      UV  x heath  y crag scree
//   UV2    x ruin flagstone  y worn path (overlay)
// Salt crust (the White Pans; its own textures salt_alb / salt_nrm, tools/realm_salt_texture.gd) is weight slot 7:
// not in the vertex data (a custom vertex channel did not survive the terrain's rebuilds) but analytic: the same
// warped rect falloff as RealmLayout.place_weight, from salt_rect; the vertex weights share what it leaves.
// Layers live in two texture arrays (tools/realm_land_textures.gd):
//   alb: rgb albedo, a height      nrm: rg tilt (x, z), b roughness, a AO
// Height-blended between layers; steep ground (> ~35 deg) turns to triplanar cliff rock (layer 8).
// w[] is gathered in the texture array's layer order (meadow, heath, loam, mud, ash, scree, flag; then
// path, cliff), so weight i samples layer i. Until r35 the splat's own slot order (meadow, loam, mud,
// ash, heath, ...) read layer i: forest showed heath straw, fen leaf litter, ash country mud and the
// heath cracked basalt.
// Distance LOD (far_lo..far_hi from the camera): near, each layer at its own scale with its normal
// map; far, the same layer at far_scale and turned (no 3 m repeat lining up across a field), albedo
// only, with the layer's mean roughness/AO (NRM_MEAN, measured from land_normal.png; refresh it if
// tools/realm_land_textures.gd changes). Far pixels fetch half the textures; only the band pays both.

uniform sampler2DArray alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray nrm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D salt_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D salt_nrm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float salt_scale = 0.2;
uniform vec4 salt_rect = vec4(160.0, 112.0, 258.0, 240.0);     // x0 z0 x1 z1 = RealmLayout.PANS
uniform vec3 tint = vec3(0.8, 0.88, 1.0);        // cool night grading of the authored colours
uniform float saturation = 0.95;
uniform float brightness = 0.6;          // 1.2 -> 0.6 (Luke, 7 Nov: the ground twice as dark); lamp_gain doubled so the fire pools hold
uniform float broad_normal = 0.35;               // metre-scale lumps so open ground never reads as a smooth dune
uniform float normal_strength = 1.0;
uniform float slope_lo = 0.70;                   // world normal.y: all rock below
uniform float slope_hi = 0.83;                   // all ground above (cos 34 deg)
uniform float cliff_scale = 0.11;
uniform vec3 rim_color = vec3(0.45, 0.72, 1.0);
uniform float rim_strength = 0.07;                // 0.14 -> 0.07: a glow at grazing angles that the moon and albedo do not touch; halved with the ground
uniform float blend_depth = 0.22;                // height-blend softness
uniform float water_y = -0.9;
uniform int dbg_skip = -1;                       // zz/free_shots --var: drop a weight layer (0..7) or the worn path (8)
uniform float path_bright = 3.0;               // packed earth catches the moon more than turf
// ENS art pass (docs/enshrouded/art.md): painterly ground. Crevices darken the albedo itself (not only
// the ambient), and broad patches drift between mossy green and cold slate, hues the grade keeps.
uniform float cavity = 0.45;
uniform float patch_hue = 0.22;
uniform float far_lo = 20.0;                     // metres: layer detail starts handing over to the far tiling
uniform float far_hi = 32.0;                     // all far beyond this
uniform float far_scale = 0.31;                  // far tiles are ~3x larger
// Lights on the ground. The ground's albedo is dark and graded cold (tint), so a warm lamp, brazier or spell
// light left the road and the plaza near-black beside the grass (whose own shader is brighter and
// translucent). light() below keeps the engine's Burley diffuse but gives every positional light (omni,
// spot) a gain and takes the cold tint back off their colour; the moon (directional) is unchanged.
uniform float lamp_gain = 4.8;                 // 2.4 at brightness 1.2: doubled as the albedo halved, so a fire lights the ground as before
uniform float lamp_untint = 0.75;                // how much of the cold grade is undone for positional lights
// The Ashen Rift's scorch (core/world/realm/rift/scorch.gd sets these): a map over scorch_rect (x0 z0 x1 z1),
// r pale ash drift, g cooled lava flow (0 at its margin .. 1 on its spine), b heat left in it, a burn.
uniform sampler2D scorch_tex : filter_linear, repeat_disable, hint_default_black;
uniform vec4 scorch_rect = vec4(0.0);
uniform vec3 scorch_ash : source_color = vec3(0.4, 0.38, 0.355);
uniform vec3 scorch_crust : source_color = vec3(0.04, 0.038, 0.045);
uniform vec3 scorch_heat : source_color = vec3(1.0, 0.32, 0.07);
uniform float scorch_heat_energy = 1.7;

vec2 rot_c(vec2 p) { return vec2(0.8 * p.x - 0.6 * p.y, 0.6 * p.x + 0.8 * p.y); }

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 w_a;
varying vec4 w_b;

// (the layer scales and turns are local consts in fragment(): global const arrays were left as
// orphan names at exit, zz/quit_probe --verbose)

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	w_a = COLOR;
	w_b = vec4(UV, UV2);
}

// sin-free hash (Hoskins): the lumps and drifts ran 16 sin() a pixel
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}
float lumps(vec2 p) { return vnoise(p * 0.45) * 0.65 + vnoise(rot_c(p) * 1.1) * 0.35; }
// gradient of vnoise (same hashes, analytic derivative of the smoothstep blend)
vec2 vnoise_grad(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = hash21(i), b = hash21(i + vec2(1, 0)), c = hash21(i + vec2(0, 1)), d = hash21(i + vec2(1, 1));
	float k = a - b - c + d;
	return du * vec2(b - a + k * u.y, c - a + k * u.x);
}
// -grad(lumps): what the old forward differences over 0.25 m measured (taken at their midpoint),
// 2 noise lookups instead of 6
vec2 lumps_slope(vec2 p) {
	p += vec2(0.125);
	vec2 g1 = vnoise_grad(p * 0.45) * (0.45 * 0.65);
	vec2 g2 = vnoise_grad(rot_c(p) * 1.1) * (1.1 * 0.35);
	g2 = vec2(0.8 * g2.x + 0.6 * g2.y, -0.6 * g2.x + 0.8 * g2.y);     // back through rot_c
	return -(g1 + g2);
}

vec2 rot(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

void fragment() {
	const float SCALE[9] = float[](0.31, 0.29, 0.38, 0.24, 0.25, 0.33, 0.30, 0.34, 0.11);
	// each layer's mean nrm texel (flat tilt; b roughness, a AO): what the far field uses instead of a fetch
	const vec4 NRM_MEAN[9] = vec4[](vec4(0.5, 0.5, 0.898, 0.774), vec4(0.5, 0.5, 0.898, 0.769), vec4(0.5, 0.5, 0.898, 0.843),
		vec4(0.5, 0.5, 0.471, 0.818), vec4(0.5, 0.5, 0.778, 0.877), vec4(0.5, 0.5, 0.735, 0.861), vec4(0.5, 0.5, 0.795, 0.877),
		vec4(0.5, 0.5, 0.863, 0.768), vec4(0.5, 0.5, 0.820, 0.863));
	// cos/sin of each layer's turn (i * 1.3 rad), so no pixel computes 14 trig calls for constants
	const vec2 LAYER_CS[8] = vec2[](vec2(1.000000000, 0.000000000), vec2(0.267498829, 0.963558185), vec2(-0.856888753, 0.515501372), vec2(-0.725932304, -0.687766159), vec2(0.468516671, -0.883454656), vec2(0.976587626, 0.215119988), vec2(0.053955421, 0.998543345), vec2(-0.947733, 0.319096));
	// layer order (tools/realm_land_textures.gd): meadow r, heath UV.x, loam g, mud b, ash a, crag UV.y, ruin UV2.x
	vec2 sq = wpos.xz;
	sq += vec2(sin(sq.y * 0.09 + 1.3) + 0.6 * sin(sq.y * 0.21 + sq.x * 0.05), sin(sq.x * 0.08 + 0.4) + 0.6 * sin(sq.x * 0.19 - sq.y * 0.06)) * 4.4;
	vec2 sd = max(max(salt_rect.xy - sq, vec2(0.0)), sq - salt_rect.zw);
	// the pans' edge is a stain, not a line: salt creeps out over the bank in patches (a wider, noise-broken falloff)
	float sdl = length(sd);
	float sn = texture(alb, vec3(sq * 0.045, 3.0)).a;
	float salt_t = clamp(1.0 - sdl / 26.0 + (sn - 0.5) * 0.8 * min(sdl / 5.0, 1.0), 0.0, 1.0);
	float w_salt = salt_t * salt_t * (3.0 - 2.0 * salt_t);
	float w_rest = w_a.r + w_b.x + w_a.g + w_a.b + w_a.a + w_b.y + w_b.z;
	float w_k = (1.0 - w_salt) / max(w_rest, 0.001);
	float w[8] = float[](w_a.r * w_k, w_b.x * w_k, w_a.g * w_k, w_a.b * w_k, w_a.a * w_k, w_b.y * w_k, w_b.z * w_k, w_salt);
	if (dbg_skip >= 0 && dbg_skip < 8) { w[dbg_skip] = 0.0; }
	// r38: below its own region the salt crust must not show on other ground at all (its crack network drew white scratches across
	// Saltmarket's flagstones): the weight is cut to nothing under 0.7 and ramps to full by 0.95, so the White Pans proper are unchanged
	w[7] *= smoothstep(0.7, 0.95, w[7]);
	float path = dbg_skip == 8 ? 0.0 : clamp(w_b.w, 0.0, 1.0);
	vec2 p = wpos.xz;
	// distance LOD: near, the tiles at their own scale with their normal maps; far, the same layers
	// at far_scale (turned) so the 3 m repeat never lines up across a field, albedo only (one fetch a
	// layer instead of two; the normal detail is sub-pixel there and only crawled)
	float cdist = length(wpos - CAMERA_POSITION_WORLD);
	float fk = smoothstep(far_lo, far_hi, cdist);
	// very far ground (the camera sees 420 m): only the layers that matter, one cliff axis, no drift noise
	float fz = smoothstep(90.0, 150.0, cdist);
	float wmax = max(max(max(w[0], w[1]), max(w[2], w[3])), max(max(w[4], w[5]), max(w[6], w[7])));
	float wmin = min(mix(0.02, 0.3, fz), wmax * 0.99);
	bool near_on = fk < 0.999;
	bool far_on = fk > 0.001;

	// broad variation (breaks tiling): low-frequency heights of two layers
	float macro = texture(alb, vec3(rot(p, 0.6) * 0.021, 3.0)).a;
	float macro2 = texture(alb, vec3(rot(p, 2.1) * 0.0063, 1.0)).a;

	// biome layers, height-blended
	vec4 a_i[8];
	vec4 n_i[8];
	float s_i[8];
	float smax = -10.0;
	for (int i = 0; i < 8; i++) {
		s_i[i] = -10.0;
		if (w[i] > wmin) {
			vec2 cs = LAYER_CS[i];
			vec2 uv = vec2(cs.x * p.x - cs.y * p.y, cs.y * p.x + cs.x * p.y) * (i == 7 ? salt_scale : SCALE[i]);
			vec4 a;
			vec4 n;
			if (i == 7) {
				// r37: the White Pans' salt crust (its own 2D textures)
				vec2 fuv7 = vec2(0.62 * uv.x - 0.78 * uv.y, 0.78 * uv.x + 0.62 * uv.y) * far_scale;
				// r38: where salt only spills a little (the rim of Saltmarket's paving, w < ~0.6) its pale crack network drew white scratches
				// across the flagstones (isolated by skipping layer 7 in a capture: the dress decals and the flagstone layer were not it):
				// spill takes the crust's seams down to a salt-grey; the White Pans' own crust (w near 1) is unchanged
				
				if (!far_on) {
					a = texture(salt_alb, uv);
					n = texture(salt_nrm, uv);
				} else {
					a = texture(salt_alb, fuv7);
					n = vec4(0.5, 0.5, 0.62, 0.82);
					if (near_on) {
						a = mix(texture(salt_alb, uv), a, fk);
						n = mix(texture(salt_nrm, uv), n, fk);
					}
				}
			} else if (!far_on) {
				a = texture(alb, vec3(uv, float(i)));
				n = texture(nrm, vec3(uv, float(i)));
			} else {
				vec2 fuv = vec2(0.62 * uv.x - 0.78 * uv.y, 0.78 * uv.x + 0.62 * uv.y) * far_scale;
				a = texture(alb, vec3(fuv, float(i)));
				n = NRM_MEAN[i];
				if (near_on) {
					a = mix(texture(alb, vec3(uv, float(i))), a, fk);
					n = mix(texture(nrm, vec3(uv, float(i))), n, fk);
				}
			}
			a_i[i] = a;
			n_i[i] = n;
			// flagstones: the mortar joints sit low in the height map, so a pale neighbour (salt, gravel, scree) won
			// them in the fade of a square's rim and traced every joint white; the joints take the slab's height
			s_i[i] = (i == 6 ? max(a.a, 0.55) : a.a) * 0.6 + w[i] * 1.4;
			smax = max(smax, s_i[i]);
		}
	}
	vec3 col = vec3(0.0);
	vec2 tilt = vec2(0.0);
	float rough = 0.0;
	float ao = 0.0;
	float tot = 0.0;
	for (int i = 0; i < 8; i++) {
		if (s_i[i] > -9.0) {
			float b = max(s_i[i] - (smax - blend_depth), 0.0);
			col += a_i[i].rgb * b;
			tilt += (n_i[i].rg * 2.0 - 1.0) * b;
			rough += n_i[i].b * b;
			ao += n_i[i].a * b;
			tot += b;
		}
	}
	if (tot > 0.0) {
		col /= tot; tilt /= tot; rough /= tot; ao /= tot;
	} else {
		col = vec3(0.15); rough = 0.9; ao = 1.0;
	}

	// mortar: wherever the flagstone layer is present at all, its dark joints stay dark. The blend above lets a pale
	// neighbour (salt crust, gravel) fill the joint pixels as the paving thins out, which drew every joint as a bright line
	if (s_i[6] > -9.0) {
		float joint = 1.0 - smoothstep(0.1, 0.2, dot(a_i[6].rgb, vec3(0.299, 0.587, 0.114)));
		float jk = joint * smoothstep(0.12, 0.55, w[6]);
		col = mix(col, a_i[6].rgb, jk);
		tilt = mix(tilt, n_i[6].rg * 2.0 - 1.0, jk);
		rough = mix(rough, n_i[6].b, jk);
		ao = mix(ao, n_i[6].a, jk);
	}

	// the rift's scorch: charred turf, roped black basalt where the lava ran over the lip (warm seams near the
	// lip), pale ash lying in the lee and the low ground. Before the worn path, so a way crosses it as earth.
	float scorch_glow = 0.0;
	vec2 sc_sz = max(scorch_rect.zw - scorch_rect.xy, vec2(0.001));
	vec2 sct = (p - scorch_rect.xy) / sc_sz;
	if (scorch_rect.z > scorch_rect.x && sct.x > 0.0 && sct.y > 0.0 && sct.x < 1.0 && sct.y < 1.0) {
		vec4 sc = texture(scorch_tex, sct);
		// the ring round the burn is dry (straw, umber); the burn itself is charred
		float lumb = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(lumb) * vec3(1.08, 0.9, 0.66), smoothstep(0.02, 0.4, sc.a) * 0.55);
		col = mix(col, vec3(lumb) * vec3(0.5, 0.44, 0.4), smoothstep(0.45, 0.85, sc.a) * 0.8);
		float gn = sc.g + (vnoise(p * 0.9) - 0.5) * 0.07;
		float fl = smoothstep(0.03, 0.1, gn);
		if (fl > 0.001) {
			// ropes along the flow's isolines, bent by noise (pahoehoe), fading out with distance (they alias into
			// stripes from afar); tumuli (metre-scale swells) and a seam network breaking the crust into plates
			// ropes come in short bunched arcs (a mask of patches), not in one ripple over the whole lobe
			float near_k = (1.0 - smoothstep(12.0, 30.0, cdist)) * smoothstep(0.45, 0.75, vnoise(rot(p, 0.4) * 0.22));
			float ph = gn * 90.0 + vnoise(p * 0.55) * 7.0 + vnoise(p * 1.7) * 1.5;
			float rope = sin(ph) * near_k;
			float gx = texture(scorch_tex, sct + vec2(0.4, 0.0) / sc_sz).g - sc.g;
			float gz = texture(scorch_tex, sct + vec2(0.0, 0.4) / sc_sz).g - sc.g;
			vec2 rope_t = -vec2(gx, gz) * cos(ph) * 90.0 * 0.025 * near_k;
			// tumuli and slabs: the crust heaved in metre swells and broke into plates along a seam network
			vec2 tum = -vnoise_grad(rot(p, 1.9) * 0.32) * 0.32 * 1.8 - vnoise_grad(rot(p, 0.8) * 0.9) * 0.9 * 0.35;
			// cooling cracks: a fine network (plates of half a metre to a metre), a few centimetres wide whatever the distance
			float crk = abs(vnoise(rot(p, 0.7) * 2.1) * 0.75 + vnoise(rot(p, 2.2) * 5.3) * 0.25 - 0.5);
			float seam = 1.0 - smoothstep(0.0, 0.018 + fwidth(crk) * 1.2, crk);
			vec3 crust = scorch_crust * (0.85 + 0.3 * (rope * 0.5 + 0.5)) * (0.8 + 0.4 * vnoise(p * 3.1));
			crust *= 1.0 - seam * 0.6;
			col = mix(col, crust, fl);
			tilt = mix(tilt, rope_t + tum + tilt * 0.25, fl);
			rough = mix(rough, mix(0.74, 0.92, rope * 0.5 + 0.5), fl);      // a dull glass: the crests catch a little moon
			ao = mix(ao, mix(0.8, 1.0, rope * 0.5 + 0.5), fl);
			float pulse = 0.7 + 0.3 * sin(TIME * 0.7 + p.x * 0.31 + p.y * 0.23);
			// the seams glow where the crust is still warm, brightest where they widen; most stay dark
			seam *= smoothstep(0.3, 0.7, vnoise(rot(p, 1.4) * 0.35) + sc.b * 0.35);
			// (the seams are drawn in plan: on a steep face they would stretch into streaks, so they keep to the flat)
			scorch_glow = seam * fl * smoothstep(0.05, 0.6, sc.b) * pulse * smoothstep(0.86, 0.96, wnrm.y);
		}
		// pale ash: drifts fill the hollows and crevices first, streaked by noise
		float ad = smoothstep(0.42, 0.82, sc.r + (vnoise(rot(p, 2.3) * 0.6) - 0.5) * 0.45 + (0.82 - ao) * 0.35);
		col = mix(col, scorch_ash * (0.8 + 0.35 * vnoise(p * 1.7)), ad);
		tilt *= 1.0 - ad * 0.7;
		rough = mix(rough, 0.97, ad);
		ao = mix(ao, 0.96, ad * 0.6);
	}

	// worn path: overlay with an irregular, height-aware edge
	if (path > 0.01) {
		vec2 uv = vec2(0.921061 * p.x - 0.389418 * p.y, 0.389418 * p.x + 0.921061 * p.y) * SCALE[7];   // turned 0.4 rad
		vec4 pa = vec4(0.0);
		vec4 pn = NRM_MEAN[7];
		if (near_on) {
			pa = texture(alb, vec3(uv, 7.0));
			pn = mix(texture(nrm, vec3(uv, 7.0)), pn, fk);
		}
		if (far_on) {
			pa = mix(pa, texture(alb, vec3(vec2(0.62 * uv.x - 0.78 * uv.y, 0.78 * uv.x + 0.62 * uv.y) * far_scale, 7.0)), fk);
		}
		float edge = smoothstep(0.4, 0.62, path + (pa.a - 0.5) * 0.45 + (macro - 0.5) * 0.3);
		col = mix(col, pa.rgb * path_bright, edge);
		tilt = mix(tilt, pn.rg * 2.0 - 1.0, edge);
		rough = mix(rough, pn.b, edge);
		ao = mix(ao, pn.a, edge);
	}

	col *= mix(0.72, 1.22, macro) * mix(0.85, 1.12, macro2);
	col = mix(col, col * vec3(0.82, 1.08, 0.95), smoothstep(0.45, 0.7, macro2) * (1.0 - path));   // greener / browner patches
	// a third, mid-scale patch layer: moss-green drifts and cold slate drifts (painted-in variation)
	float drift = fz > 0.95 ? 0.0 : vnoise(rot(p, 1.1) * 0.045) - vnoise(rot(p, 2.7) * 0.11) * 0.5;
	vec3 moss_c = col * vec3(0.78, 1.12, 0.86);
	vec3 slate_c = col * vec3(0.9, 0.97, 1.1);
	col = mix(col, drift > 0.12 ? moss_c : slate_c, smoothstep(0.08, 0.32, abs(drift)) * patch_hue * 2.5 * (1.0 - path * 0.6));

	// ground normal (tilt applied in world xz) + broad lumps from the cliff layer at low frequency
	// (metre lumps are a pixel or two past far_hi: faded out with the layer normals, not computed there)
	if (near_on) {
		tilt += lumps_slope(p) * broad_normal * (1.0 - path * 0.7) * (1.0 - fk);
	}
	vec3 gn = normalize(wnrm + vec3(tilt.x, 0.0, tilt.y) * normal_strength * 0.9);

	// steep ground: triplanar cliff rock
	float flat_k = smoothstep(slope_lo, slope_hi, wnrm.y + (macro - 0.5) * 0.08);
	vec3 n_ws = gn;
	if (flat_k < 0.999) {
		vec3 bw = pow(abs(wnrm), vec3(4.0));
		if (fz > 0.5) {
			bw = step(bw.yzx, bw) * step(bw.zxy, bw);
		}
		bw /= (bw.x + bw.y + bw.z);
		vec3 rc = vec3(0.0);
		vec3 rn = vec3(0.0);
		float rr = 0.0;
		float ra = 0.0;
		if (bw.x > 0.01) {
			vec4 c = texture(alb, vec3(wpos.zy * cliff_scale, 8.0));
			vec4 n = near_on ? mix(texture(nrm, vec3(wpos.zy * cliff_scale, 8.0)), NRM_MEAN[8], fk) : NRM_MEAN[8];
			vec2 t = n.rg * 2.0 - 1.0;
			rc += c.rgb * bw.x; rn += vec3(0.0, t.y, t.x) * bw.x; rr += n.b * bw.x; ra += n.a * bw.x;
		}
		if (bw.y > 0.01) {
			vec4 c = texture(alb, vec3(wpos.xz * cliff_scale, 8.0));
			vec4 n = near_on ? mix(texture(nrm, vec3(wpos.xz * cliff_scale, 8.0)), NRM_MEAN[8], fk) : NRM_MEAN[8];
			vec2 t = n.rg * 2.0 - 1.0;
			rc += c.rgb * bw.y; rn += vec3(t.x, 0.0, t.y) * bw.y; rr += n.b * bw.y; ra += n.a * bw.y;
		}
		if (bw.z > 0.01) {
			vec4 c = texture(alb, vec3(wpos.xy * cliff_scale, 8.0));
			vec4 n = near_on ? mix(texture(nrm, vec3(wpos.xy * cliff_scale, 8.0)), NRM_MEAN[8], fk) : NRM_MEAN[8];
			vec2 t = n.rg * 2.0 - 1.0;
			rc += c.rgb * bw.z; rn += vec3(t.x, t.y, 0.0) * bw.z; rr += n.b * bw.z; ra += n.a * bw.z;
		}
		vec3 rock_n = normalize(wnrm + rn * normal_strength * 1.1);
		// ash country rock is basalt-dark
		rc *= mix(1.0, 0.55, w[4]);
		if (fz > 0.5) {
			// the far walls (the Crowns at 400 m): pale ledges and dark crevice streaks keyed to height, in the far path only
			float ledge = sin(wpos.y * 0.45 + vnoise(wpos.xz * 0.03) * 6.0);
			rc *= mix(0.8, 1.18, smoothstep(-0.3, 0.7, ledge));
		}
		col = mix(rc, col, flat_k);
		n_ws = normalize(mix(rock_n, gn, flat_k));
		rough = mix(rr, rough, flat_k);
		ao = mix(ra, ao, flat_k);
	}

	// fen: wet, darker mud near the water line
	float wet = w[3] * (1.0 - smoothstep(water_y + 0.05, water_y + 0.55, wpos.y));
	col *= 1.0 - wet * 0.45;
	rough = mix(rough, 0.18, wet * 0.8);

	// crevices and pebble gaps (the layers' baked AO) darken the albedo: dark seams, lit tops
	col *= mix(1.0 - cavity, 1.0 + cavity * 0.25, ao);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	ALBEDO = col * tint * brightness;
	NORMAL = normalize((VIEW_MATRIX * vec4(n_ws, 0.0)).xyz);
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	AO = mix(1.0, ao, 0.85);
	AO_LIGHT_AFFECT = 0.35;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	EMISSION = rim_color * rim_strength * fres * (0.4 + 0.6 * flat_k);
	EMISSION += scorch_heat * scorch_glow * scorch_heat_energy * (1.0 - path);
}

// The engine's Burley diffuse with a gain on positional lights, and a plain GGX highlight (the ground is rough:
// this is the wet fen and the wet flagstones catching a flame).
void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float NdotV = clamp(dot(NORMAL, VIEW), 0.0001, 1.0);
	vec3 H = normalize(VIEW + LIGHT);
	float LdotH = clamp(dot(LIGHT, H), 0.0, 1.0);
	float fd90 = 0.5 + 2.0 * LdotH * LdotH * ROUGHNESS;
	float fl = 1.0 + (fd90 - 1.0) * pow(1.0 - NdotL, 5.0);
	float fv = 1.0 + (fd90 - 1.0) * pow(1.0 - NdotV, 5.0);
	vec3 lc = LIGHT_COLOR;
	if (!LIGHT_IS_DIRECTIONAL) {
		lc *= lamp_gain * mix(vec3(1.0), vec3(1.0) / tint, lamp_untint);
	}
	DIFFUSE_LIGHT += lc * ATTENUATION * NdotL * fl * fv / PI;
	float a = max(ROUGHNESS * ROUGHNESS, 0.04);
	float NdotH = clamp(dot(NORMAL, H), 0.0, 1.0);
	float dd = NdotH * NdotH * (a * a - 1.0) + 1.0;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * NdotL * (a * a / (PI * dd * dd)) * 0.04 * SPECULAR_AMOUNT;
}
