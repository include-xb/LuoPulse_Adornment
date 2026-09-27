shader_type canvas_item;

uniform float gray_scale   : hint_range(0.0, 1.0) = 0.0;   // 整体灰度
uniform float flash        : hint_range(0.0, 2.0) = 0.0;   // 高亮脉冲 (0 = 无), 供演奏时的背景反馈使用

void fragment() {
	 // 原始颜色
    vec4 img = texture(TEXTURE, UV);
    vec3 color = img.rgb;

	// 灰度调制
	color = mix(vec3(dot(color, vec3(0.299, 0.587, 0.114))), color, (1.0 - gray_scale));

	// 高亮脉冲 (project.godot 已开 hdr_2d, 可以超过 1.0 做过曝)
	color += vec3(flash);

	// 输出（保留原图透明度）
    COLOR = vec4(color, img.a);
}