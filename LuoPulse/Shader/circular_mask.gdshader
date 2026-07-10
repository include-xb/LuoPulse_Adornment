shader_type canvas_item;

void fragment() {
	// 圆心在 UV (0.5, 0.5), 半径 0.5 的圆形遮罩
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	// fwidth 提供像素级别的抗锯齿平滑宽度
	float smooth_width = fwidth(dist);
	float alpha = 1.0 - smoothstep(0.5 - smooth_width, 0.5, dist);
	COLOR.a *= alpha;
}
