shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

// Hold 长键专用 shader
// 与 note_edge.gdshader 同属 blend_mix 渲染管线, 但无边缘遮罩,
// 避免 scale.z 非均匀拉伸时上下边缘被拉宽.
uniform vec4 color : source_color = vec4(0.5647059, 0.6901961, 0.4392157, 1.0);

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
