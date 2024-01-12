#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8) in;

layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D current_image;
layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D output_image;

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

	float value = imageLoad(current_image, uv).x;

	// devide the value by sum of value of cells

	vec4 result_vec = vec4(val,val,val,1.);
	imageStore(output_image, uv, result_vec);
}
