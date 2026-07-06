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
}