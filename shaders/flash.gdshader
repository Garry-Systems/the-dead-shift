shader_type canvas_item;
// Hit-flash for sprites. `flash` (0..1) mixes the sprite toward white on impact.
// `base_tint` replaces the node's modulate (so we never depend on the MODULATE
// built-in) — white for normal enemies, red for the boss.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // white default; player uses red

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb * base_tint.rgb;
	rgb = mix(rgb, flash_color.rgb, flash);
	COLOR = vec4(rgb, tex.a * base_tint.a);
}
