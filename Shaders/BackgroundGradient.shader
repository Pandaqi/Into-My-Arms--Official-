shader_type canvas_item;

uniform vec4 grad_bottom = vec4(0.2, 0.2, 1.0, 1.0);
uniform vec4 grad_top = vec4(0.0, 1.0, 1.0, 1.0);

uniform vec4 next_bottom = vec4(0,0,0,0);
uniform vec4 next_top = vec4(0,0,0,0);

uniform float transition_t = 0;

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	float t = UV.y;
	
	vec4 temp_bottom = grad_bottom * (1.0-transition_t) + next_bottom * transition_t;
	vec4 temp_top = grad_top * (1.0-transition_t) + next_top * transition_t;
	
	COLOR = vec4(temp_bottom.rgb * t + temp_top.rgb * (1.0 - t), 1.0);
	
//	if(rand(vec2(UV.x + TIME, UV.y + TIME)) < 0.0001) {
//		COLOR = COLOR + vec4(0.3, 0.3, 0.3, 0.0)
//	}
}