shader_type canvas_item;

varying vec2 VAR1;

void vertex() {
	// NOTE: Vertices are in LOCAL coordinates, seen from the CENTER/PIVOT POINT of the object
	// In our case: width = (-64, 64) and height = (-64, 64)
	VAR1 = VERTEX;
}

//void fragment() {
//	COLOR = vec4(NORMAL.z, NORMAL.z, NORMAL.z, 1.0);
//}

void light() {
	// LINK ON CARTESION->ISOMETRIC: https://stackoverflow.com/questions/31577053/convert-cartesian-width-and-height-to-isometric
	
	/* THIS IS THE PLAN:
	*
	* First,  a simple case: pretend the light is on the same "height level" as us
		* Grab the LIGHT_VEC
		* This is in _cartesian coordinates_ (regular screen coordinates)
		* Convert them to _isometric coordinates_ with these formulas:
			* isoX = carX + carY
			* isoY = carY - carX * 0.5
		* If we pretend we have a 3 axis system, with X = BACK, Y = TOP, Z = SIDE, we now know the light position: (isoX, 0, isoY)
	
	* Important: check if the above algorithm works!
		* Make each fragment display the DISTANCE to the light vector, and we should see fragments further away become darker
		* Check this for all axes separately
	
	*/
	
	
	
	
	
	
	
	
	
	
	
	// this is the half size of the tile in pixels
	vec2 tile_vec = vec2(64, 32);

	// convert vertex to point in 2D
	// take the lowest Y-point (64), and subtract the other coordinates from that,
	// so that the Y value gets higher and higher further up the object
	vec2 point_2d = vec2(VAR1.x, (64.0 - VAR1.y));
	
	// Because our isometric view is 2:1, the Y offset is always 1/2 * X offset
	// WHY THE ABSOLUTE VALUE?!?
	float y_ofs = abs(VAR1.x * 0.5);

	// compute a pseudo 3D point for both the light and the texel
	// this makes the normalmap calculation work properly
	vec3 point_3d = vec3( point_2d.x, point_2d.y - y_ofs, y_ofs );
	vec3 light_3d = vec3( point_2d.x - LIGHT_VEC.x, LIGHT_HEIGHT, (-(VAR1.y - (LIGHT_VEC.y)) + 64.0));

	// this could be optimized
	// a rotation matrix is created to convert the normalmap vector
	// to the same coordinate space as our pseudo 3d point and light
	float r = asin(0.5);
	mat3 rot_mat = mat3( vec3(1,0,0), vec3(0,cos(r),-sin(r)), vec3(0,sin(r),cos(r)));
	vec3 n = rot_mat * NORMAL;
	n.y = -n.y;

	// CHANGES I MADE
	// Swapped "COLOR" for "texture(TEXTURE, UV)", as that has worked before

	// finally compute the dot product. Simple diffuse is computed here,
	// but specular could be added and it will look prettier
	float dp = max( dot(normalize(n), -normalize(light_3d-point_3d)), 0);
	LIGHT = vec4( vec3(dp), 1.0) * texture(TEXTURE, UV) * LIGHT_COLOR * 3.0;

	//finally, after light was computed, make the light "flat"
	//this makes the shadows work properly
	//the +2 is added to avoid z-fighting between caster and pseudo 3d coords.
	// LIGHT_VEC.y += point_3d.y + 2.0;

	//SHADOW_VEC = LIGHT_VEC;
}