shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

// ============ 可调参数 ============
// 本体颜色（含透明度）
uniform vec4 original_color : source_color = vec4(0.0, 0.0, 0.0, 0.3);

// ============ 主函数 ============
void fragment() {
	vec4 color = original_color;
	
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
