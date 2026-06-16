shader_type canvas_item;

// ============ 可调参数 ============
// 纸色（泛黄）
uniform vec3 paper_color : source_color = vec3(0.95, 0.88, 0.78);

// 边缘淡出范围（距离中心的归一化半径，0~1）
uniform float fade_start : hint_range(0.0, 0.7) = 0.3;
uniform float fade_end   : hint_range(0.0, 1.0) = 0.9;

// 彩铅颜色调整
uniform float saturation : hint_range(0.0, 1.0) = 1.0;   // 颜色饱和度（越低越灰）
uniform float brightness : hint_range(0.5, 1.5) = 0.9;   // 整体亮度

// 铅笔线条控制
uniform float line_strength : hint_range(0.0, 1.0) = 0.3; // 线条黑度
uniform float edge_threshold : hint_range(0.0, 0.3) = 0.05; // 边缘敏感度（越小线条越多）

// 纸张纹理
uniform float texture_strength : hint_range(0.0, 0.15) = 0.06;
uniform float texture_scale    : hint_range(10.0, 500.0) = 180.0;

// ============ 噪声函数（用于纸张纹理） ============
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 平滑噪声（基于哈希的插值）
float smooth_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);  // 平滑插值
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 分形布朗运动（多层噪声叠加）
float fbm(vec2 p) {
    float value = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 4; i++) {
        value += amp * smooth_noise(p * freq);
        freq *= 2.0;
        amp *= 0.5;
    }
    return value;
}

// ============ 边缘检测（Sobel 近似） ============
float edge_detect(sampler2D tex, vec2 uv, float dx, float dy) {
    // 采样 3x3 邻域
    vec3 c0 = texture(tex, uv + vec2(-dx, -dy)).rgb;
    vec3 c1 = texture(tex, uv + vec2( 0.0, -dy)).rgb;
    vec3 c2 = texture(tex, uv + vec2( dx, -dy)).rgb;
    vec3 c3 = texture(tex, uv + vec2(-dx,  0.0)).rgb;
    vec3 c5 = texture(tex, uv + vec2( dx,  0.0)).rgb;
    vec3 c6 = texture(tex, uv + vec2(-dx,  dy)).rgb;
    vec3 c7 = texture(tex, uv + vec2( 0.0,  dy)).rgb;
    vec3 c8 = texture(tex, uv + vec2( dx,  dy)).rgb;

    // 转为亮度
    float g0 = dot(c0, vec3(0.299, 0.587, 0.114));
    float g1 = dot(c1, vec3(0.299, 0.587, 0.114));
    float g2 = dot(c2, vec3(0.299, 0.587, 0.114));
    float g3 = dot(c3, vec3(0.299, 0.587, 0.114));
    float g5 = dot(c5, vec3(0.299, 0.587, 0.114));
    float g6 = dot(c6, vec3(0.299, 0.587, 0.114));
    float g7 = dot(c7, vec3(0.299, 0.587, 0.114));
    float g8 = dot(c8, vec3(0.299, 0.587, 0.114));

    // Sobel 梯度
    float gx = -g0 + g2 - 2.0*g3 + 2.0*g5 - g6 + g8;
    float gy = -g0 - 2.0*g1 - g2 + g6 + 2.0*g7 + g8;
    float grad = sqrt(gx*gx + gy*gy);
    return clamp(grad, 0.0, 1.0);
}

// ============ 主函数 ============
void fragment() {
    vec2 uv = UV;
    vec2 tex_size = vec2(textureSize(TEXTURE, 0));
    float dx = 1.0 / tex_size.x;
    float dy = 1.0 / tex_size.y;

    // 原始颜色
    vec4 img = texture(TEXTURE, uv);
    vec3 color = img.rgb;

    // ---------- 彩铅颜色处理 ----------
    // 降饱和度
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    color = mix(vec3(gray), color, saturation);
    // 亮度
    color *= brightness;

    // ---------- 铅笔线条（基于边缘） ----------
    float edge = edge_detect(TEXTURE, uv, dx, dy);
    // 用阈值控制线条粗细
    float line_mask = smoothstep(edge_threshold, edge_threshold + 0.15, edge);
    // 线条黑色混合系数（边缘强 => 黑色重）
    float line_mix = line_strength * line_mask;
    // 叠加黑色线条（边缘变黑）
    color = mix(color, vec3(0.0), line_mix);

    // ---------- 边缘淡出至纸色 ----------
    float dist = distance(uv, vec2(0.5, 0.5));
    float max_dist = 0.7071;
    float t = smoothstep(fade_start, fade_end, dist / max_dist);
    vec3 final_color = mix(color, paper_color, t);

    // ---------- 纸张纹理（叠加在最终颜色上） ----------
    vec2 tex_uv = uv * texture_scale;
    float paper_noise = fbm(tex_uv);
    // 纹理强度随边缘淡出而增强（边缘纸纹更明显），但也可均匀
    float texture_factor = texture_strength * (0.5 + 0.5 * t); // 边缘更强
    float texture_offset = (paper_noise - 0.5) * texture_factor * 2.0; // 亮度扰动
    final_color += vec3(texture_offset);

    // 输出（保留原图透明度）
    COLOR = vec4(final_color, img.a);
}