#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8) in;

layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D current_image;
layout(r32f, set = 1, binding = 0) uniform restrict readonly image2D previous_image;
layout(r32f, set = 2, binding = 0) uniform restrict writeonly image2D output_image;

layout(push_constant, std430) uniform Params {
	vec4 add_wave_point;
	vec2 texture_size;
	float damp;
	float res2;
} params;

const int kernelSize = 5; // Define the kernel size here
const float birth_low = 0.278;
const float birth_high = 0.8; // Increased to allow for more births
const float survival_low = 0.367;
const float survival_high = 0.945;

void main() {
	ivec2 tl = ivec2(0, 0);
  ivec2 size = ivec2(params.texture_size.x - 1, params.texture_size.y - 1);
  ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

	float current_status = imageLoad(current_image, uv, tl, size).x;
  float alive_cells = 0.0;
  float total_cells = 0.0;

	for (int dx = -kernelSize; dx <= kernelSize; dx++) {
		for (int dy = -kernelSize; dy <= kernelSize; dy++) {
			float cell_value = imageLoad(current_image, clamp(uv + ivec2(dx, dy), tl, size)).x;
			float weight = kernelSize - sqrt((dx * dx) + (dy * dy));
			alive_cells += cell_value;
			total_cells += 1.5 * weight;
		}
	}

	float mean = alive_cells / total_cells;
	float variance = 0.0;

	for (int dx = -kernelSize; dx <= kernelSize; dx++) {
		for (int dy = -kernelSize; dy <= kernelSize; dy++) {
			float cell_value = imageLoad(current_image, clamp(uv + ivec2(dx, dy), tl, size)).x;
			variance += (cell_value - mean) * (cell_value - mean);
		}
	}

	variance /= total_cells;
	float density = sqrt(variance);

  float next_status = current_status;

  if (mean > birth_low && mean < birth_high && density > survival_low && density < survival_high) {
    next_status = min(1.0, current_status + 1.5 * rand(cell_idx)); // Increase cell state
  } else if (!(mean > survival_low && mean < survival_high && density > survival_low && density < survival_high)) {
    next_status = max(0.0, current_status - 1.5 * rand(cell_idx)); // Decrease cell state
  }

  float result = next_status;
  imageStore(cells_out, gidx, vec4(vec3(next_status.x), 1.0));
  imageStore(output_image, uv, result)
}

float rand(vec2 co){
  return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
