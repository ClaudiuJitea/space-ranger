shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.1, 0.8, 1.0, 1.0);
uniform float strength = 1.5;
uniform float opacity = 1.0;
void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float core = exp(-across * across * 65.0);
	float halo = exp(-across * across * 5.0) * 0.22;
	float fade = pow(1.0 - UV.x, 1.4);
	ALBEDO = tint.rgb;
	EMISSION = mix(tint.rgb, vec3(1.0), core * 0.65) * strength;
	ALPHA = (core + halo) * fade * opacity;
}
