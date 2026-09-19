shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.1, 0.8, 1.0, 1.0);
uniform float opacity = 1.0;
void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float hot = exp(-across * across * 30.0);
	float soft = exp(-across * across * 5.0);
	float length_fade = pow(1.0 - UV.x, 1.6);
	ALBEDO = tint.rgb;
	EMISSION = mix(tint.rgb, vec3(1.0), hot * 0.75) * 2.5;
	ALPHA = soft * length_fade * opacity;
}
