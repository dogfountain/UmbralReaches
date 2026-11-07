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
uniform float brightness = 1.2;          // ENS pass: 1.35 -> 1.2, open ground under the moon left no room for warm pools
uniform float broad_normal = 0.35;               // metre-scale lumps so open ground never reads as a smooth dune
uniform float normal_strength = 1.0;
uniform float slope_lo = 0.70;                   // world normal.y: all rock below
uniform float slope_hi = 0.83;                   // all ground above (cos 34 deg)
uniform float cliff_scale = 0.11;
uniform vec3 rim_color = vec3(0.45, 0.72, 1.0);
uniform float rim_strength = 0.14;
uniform float blend_depth = 0.22;                // height-blend softness
uniform float water_y = -0.9;
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
uniform float lamp_gain = 2.4;
uniform float lamp_untint = 0.75;                // how much of the cold grade is undone for positional lights

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
	float salt_t = clamp(1.0 - length(sd) / 18.0, 0.0, 1.0);
	float w_salt = salt_t * salt_t * (3.0 - 2.0 * salt_t);
	float w_rest = w_a.r + w_b.x + w_a.g + w_a.b + w_a.a + w_b.y + w_b.z;
	float w_k = (1.0 - w_salt) / max(w_rest, 0.001);
	float w[8] = float[](w_a.r * w_k, w_b.x * w_k, w_a.g * w_k, w_a.b * w_k, w_a.a * w_k, w_b.y * w_k, w_b.z * w_k, w_salt);
	float path = clamp(w_b.w, 0.0, 1.0);
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
