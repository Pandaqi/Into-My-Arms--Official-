shader_type canvas_item;

uniform sampler2D normal;
uniform vec2 tile_vec = vec2(64.0, 32.0); // the tile half size in pixels

void fragment() {
//	vec2 ywnormal = texture(normal, UV).wy * vec2(2.0,2.0) - vec2(1.0,1.0);
//	NORMAL = vec3(ywnormal, sqrt(1.0 - (ywnormal.x * ywnormal.x) - (ywnormal.y * ywnormal.y) ));
//
//	COLOR = vec4(NORMAL.x, NORMAL.x, NORMAL.x, 1.0);
//	COLOR = vec4(NORMAL.y, NORMAL.y, NORMAL.y, 1.0);
//	COLOR = vec4(NORMAL.z, NORMAL.z, NORMAL.z, 1.0);
}

void light() {
//	// compute a 3D postion for the light
	vec3 light_3d = vec3(-LIGHT_VEC.x, LIGHT_HEIGHT, LIGHT_VEC.y);
//
//	// rotate the normal map to the same coordinates as the pseudo 3d point
//	// this could be optimized

	// FIRST, it finds the angle of the isomatric grid 
	//  => in our case, we have the standard 2:1 ratio, which gives  us 30 degrees
	float r = asin(tile_vec.y/tile_vec.x);

	// THEN, it rotates this amount around the X-axis
	mat3 rot_mat = mat3( vec3(1,0,0), vec3(0,cos(r),-sin(r)), vec3(0,sin(r),cos(r)));

	// THEN, it applies this rotation to the normal
	vec3 n = rot_mat * NORMAL;

	// FINALLY, it flips the Y-axis
	// WHY????
	n.y = -n.y;

//	//compute diffuse light
	// CALCULATE dot product between normal and inverse light direction 
	//   => the closer it is to 1, the more they are parallel, and thus the more light should hit this surface
	//   => if, instead, they are (near) anti-parallel, this value will be near -1, so dp keeps the numbers positive
	float dp = max( dot(normalize(n), -normalize(light_3d)), 0);

	// And then, simply apply this light over the existing texture, mix the light color, and amplify (*3.0)
	LIGHT = vec4( vec3(dp), 1.0) * texture(TEXTURE, UV) * LIGHT_COLOR * 3.0;
}
