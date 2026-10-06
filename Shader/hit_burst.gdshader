shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;


// ============ 可调参数 ============
// 矩形颜色 (alpha 由 InputProcesser 每帧写入, 用于淡出)
uniform vec4 burst_color : source_color = vec4(1.0);


// ============ 主函数 ============
void fragment() {
	ALBEDO = burst_color.rgb;
	ALPHA = burst_color.a;
}
