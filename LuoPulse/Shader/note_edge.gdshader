shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

// ============ 可调参数 ============
// 边缘线颜色（含透明度）
uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
// 上下边缘线粗细（UV 空间，0.0 ~ 0.5）
uniform float edge_width_y : hint_range(0.0, 0.5) = 0.1;
// 左右边缘线粗细（UV 空间，0.0 ~ 0.5）
uniform float edge_width_x : hint_range(0.0, 0.5) = 0.1;
// 本体颜色（含透明度）
uniform vec4 original_color : source_color = vec4(0.0, 0.0, 0.0, 0.3);

// ============ 主函数 ============
void fragment() {
	// 计算当前像素到四条边缘的最小距离
	float dist_to_edge_y = min(UV.y, 1.0 - UV.y);
	
	// 计算当前像素到四条边缘的最小距离
	float dist_to_edge_x = min(UV.x, 1.0 - UV.x);
	
	// 上下边缘遮罩：距离小于 edge_width 的区域为边缘
	float edge_mask = 1.0 - smoothstep(0.0, edge_width_y, dist_to_edge_y);
	
	// 左右边缘遮罩：距离小于 edge_width 的区域为边缘
	float edge_mask_x = 1.0 - smoothstep(0.0, edge_width_x, dist_to_edge_x);
	
	// 第一次混合, 在本体颜色和边缘线颜色之间混合
	vec4 color = mix(original_color, edge_color, edge_mask);
	
	// 混合
	color = mix(color, edge_color, edge_mask_x);
	
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
