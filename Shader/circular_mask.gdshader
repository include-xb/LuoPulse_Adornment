shader_type canvas_item;

uniform float gray_scale   : hint_range(0.0, 1.0) = 0.0;   // 整体灰度

void fragment() {
	// 原始颜色
	vec4 img = texture(TEXTURE, UV);
	vec3 color = img.rgb;
	// 灰度调制
	color = mix(vec3(dot(color, vec3(0.299, 0.587, 0.114))), color, (1.0 - gray_scale));
	// 输出（保留原图透明度）
    COLOR = vec4(color, img.a);
	// 圆心在 UV (0.5, 0.5), 半径 0.5 的圆形遮罩
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	// fwidth 提供像素级别的抗锯齿平滑宽度
	float smooth_width = fwidth(dist);
	float alpha = 1.0 - smoothstep(0.5 - smooth_width, 0.5, dist);
	COLOR.a *= alpha;
}
