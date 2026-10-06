shader_type canvas_item;

// ============ 可调参数 ============
// 光晕强度 (0 ~ 1), 由 HeartVignette 每帧写入
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// 最强的整体透明度
uniform float max_alpha : hint_range(0.0, 1.0) = 0.75;

// 血色 (与 HeartLine 的 line_color 同色, 整条带子只有这一个颜色)
uniform vec4 edge_color : source_color = vec4(0.4392157, 0.05882353, 0.05882353, 1.0);

// 边缘带的内外边界 (以屏幕高度为单位: 0 = 贴边, 越大越往屏幕中心)
uniform float band_inner : hint_range(0.0, 1.0) = 0.0;
uniform float band_outer : hint_range(0.0, 1.0) = 0.1;

// 四角额外往里铺开的边界 —— 比 band_outer 大多少, 四角就比边中点浓多少
// INFO: 四角离屏幕中心最远, 一圈等厚的框在角上反而显得"薄"; 让外边界在角上放宽,
//       暗色就顺着对角往中心多铺一段 (越接近角越明显)
uniform float corner_outer : hint_range(0.0, 1.0) = 0.2;

// 宽高比 (宽 / 高), 由 HeartVignette 在尺寸变化时写入
// INFO: 不修正的话, 按 UV 算出来的带子会左右比上下厚 1.78 倍 (16:9 屏)
uniform float aspect : hint_range(0.1, 10.0) = 1.7777778;

// ============ 纸张粗糙纹理 ============
// 浓度扰动的幅度 (0 = 光滑色块, 越大纸越糙)
uniform float texture_strength : hint_range(0.0, 1.0) = 0.6;

// 纸纹密度 (越大颗粒越细)
uniform float texture_scale : hint_range(1.0, 800.0) = 180.0;


// ============ 噪声 (与 Shader/dark_manager.gdshader 同一套) ============
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


// 分形布朗运动 (多层噪声叠加)
// INFO: dark_manager 叠 4 层来铺满整张画面; 这里只是一圈边带, 2 层就够糙了 ——
//       全屏逐像素的 sin() 在移动端是实打实的开销
float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < 2; i++) {
		value += amp * smooth_noise(p * freq);
		freq *= 2.0;
		amp *= 0.5;
	}
	return value / 0.75; // 两层幅度和是 0.75, 归一化回 0~1
}


// ============ 主函数 ============
void fragment() {
	// 到最近一条屏幕边的距离, 换算成"屏幕高度"为单位 —— 四周的带子像素宽度就一致了
	vec2 to_edge = min(UV, vec2(1.0) - UV);
	to_edge.x *= aspect;
	float dist = min(to_edge.x, to_edge.y);

	float alpha = 0.0;

	// 比最宽的那条边界还靠中心的, 一定是全透明的 —— 整段算下来直接跳过噪声
	// (移动端: 屏幕中心一大片像素就这样省下来了)
	// INFO: 这里不能靠 `return` 提前退出: Godot 的着色语言不允许在 fragment 里写裸 return
	if (dist <= corner_outer) {
		// "靠边程度": 0 = 该方向的中线上, 1 = 贴到边。两个方向相乘, 只有四角接近 1
		// INFO: 特意不用"到中心的径向距离" —— 宽屏的左右边离中心本就远, 会被误判成角
		vec2 toward = vec2(1.0) - min(UV, vec2(1.0) - UV) * 2.0;
		float corner = toward.x * toward.y;

		// 带子的外边界: 边中点用 band_outer, 四角放宽到 corner_outer
		float outer = mix(band_outer, corner_outer, corner);
		float band = 1.0 - smoothstep(band_inner, outer, dist);
		band = band * band;

		// ---------- 纸张粗糙纹理 ----------
		// INFO: 扰动的是"浓度"(alpha)而不是亮度 —— 纸糙表现在墨的厚薄不匀。
		//       噪声坐标按宽高比修正, 否则 16:9 屏上的颗粒会被横向拉长
		float grain = fbm(vec2(UV.x * aspect, UV.y) * texture_scale) - 0.5;
		float rough = 1.0 + texture_strength * grain * 2.0;

		alpha = clamp(band * rough * max_alpha * intensity, 0.0, 1.0);
	}

	COLOR = vec4(edge_color.rgb, alpha);
}
