shader_type canvas_item;

uniform sampler2D paper_texture;
// uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
	vec4 paper = texture(paper_texture, UV);
	// vec4 screen = texture(screen_texture, SCREEN_UV);
	// vec4 color = texture(TEXTURE, UV);
	
	float height = (paper.r + paper.g + paper.b) / 3.0f;
	
	COLOR.rgb = COLOR.rgb * height;
	
}