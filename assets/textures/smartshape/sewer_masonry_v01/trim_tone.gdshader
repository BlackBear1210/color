shader_type canvas_item;
// Keep baked bevel highlights dark; proximity lighting is a separate later pass.
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	COLOR = vec4(sample_color.rgb * 0.42, sample_color.a);
}
