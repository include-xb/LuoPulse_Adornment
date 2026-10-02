shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

// ============ 可调参数 ============
// 轨道本体颜色（含透明度）
uniform vec4 track_color : source_color = vec4(0.0, 0.0, 0.0, 0.58);
// 高亮强度 (0.0 ~ 2.0), 由 InputProcesser 在触屏/命中时驱动
uniform float highlight : hint_range(0.0, 2.0) = 0.0;
// 高亮叠加效果: rgb 为叠加色, a 为同时提升的不透明度与叠加幅度
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 0.35);

// ============ 主函数 ============
void fragment() {
	vec4 color = track_color;

	// 高亮：按强度叠加亮色并提升不透明度
	color.rgb += highlight_color.rgb * highlight_color.a * highlight;
	color.a = min(1.0, color.a + highlight_color.a * highlight);

	ALBEDO = color.rgb;
	ALPHA = color.a;
}
