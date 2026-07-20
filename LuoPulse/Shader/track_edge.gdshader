shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

// ============ 可调参数 ============
// 边缘线颜色（含透明度）
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 0.078);
// 边缘线粗细（UV 空间，0.0 ~ 0.1）
uniform float edge_width : hint_range(0.0, 0.5) = 0.5;
// 轨道本体颜色（含透明度）
uniform vec4 track_color : source_color = vec4(0.0, 0.0, 0.0, 0.47);
// 触屏高亮强度 (0.0 ~ 1.0)
uniform float highlight : hint_range(0.0, 1.0) = 0.0;

// ============ 主函数 ============
void fragment() {
	// 计算当前像素到左右边缘的最小距离
	float dist_to_edge = min(UV.x, 1.0 - UV.x);

	// 边缘遮罩：距离小于 edge_width 的区域为边缘
	float edge_mask = 1.0 - smoothstep(0.0, edge_width, dist_to_edge);

	// 在轨道本体颜色和边缘线颜色之间混合
	vec4 color = mix(track_color, edge_color, edge_mask);

	// 触屏高亮：叠加亮色
	color = mix(color, color + vec4(0.5, 0.5, 0.5, 0.25), highlight);

	ALBEDO = color.rgb;
	ALPHA = color.a;
}
