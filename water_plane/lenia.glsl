#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8) in;

layout(r32f, set = 0, binding = 0) uniform restrict readonly image2D current_image;
layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D output_image;

layout(push_constant, std430) uniform Params {
	vec4 add_wave_point;
	vec2 texture_size;
	float damp;
	float res2;
} params;

vec2 hash( vec2 p )
{
	p = vec2( dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)) );
	return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise( in vec2 p )
{
	const float K1 = 0.366025404; // (sqrt(3)-1)/2;
	const float K2 = 0.211324865; // (3-sqrt(3))/6;

	vec2  i = floor( p + (p.x+p.y)*K1 );
	vec2  a = p - i + (i.x+i.y)*K2;
	float m = step(a.y,a.x); 
	vec2  o = vec2(m,1.0-m);
	vec2  b = a - o + K2;
	vec2  c = a - 1.0 + 2.0*K2;
	vec3  h = max( 0.5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0.0 );
	vec3  n = h*h*h*h*vec3( dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
	return dot( n, vec3(70.0) );
}

const float R = 15.;       // space resolution = kernel radius
const float T = 10.;       // time resolution = number of divisions per unit time
const float dt = 1./T;     // time step
const float mu = 0.14;     // growth center
const float sigma = 0.014; // growth width
const float rho = 0.5;     // kernel center
const float omega = 0.15;  // kernel width

float bell(float x, float m, float s){
	return exp(-(x-m)*(x-m)/s/s/2.);  // bell-shaped curve
}

void main() {
	ivec2 tl = ivec2(0, 0);
	ivec2 size = ivec2(params.texture_size.x - 1, params.texture_size.y - 1);
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

	float sum = 0.;
	float total = 0.;
	for (int x=-int(R); x<=int(R); x++)
		for (int y=-int(R); y<=int(R); y++)
		{
			float r = sqrt(float(x*x + y*y)) / R;
			float val = imageLoad(current_image, clamp(uv + ivec2(x, y), tl, size)).x;
			float weight = bell(r, rho, omega);
			sum += val * weight;
			total += weight;
		}
	float avg = sum / total;

	float val = imageLoad(current_image, uv).x;
	float growth = bell(avg, mu, sigma) * 2. - 1.;
	float c = clamp(val + dt * growth, 0., 1.);

	if (params.add_wave_point.z > 0.0 && uv.x == floor(params.add_wave_point.x) && uv.y == floor(params.add_wave_point.y)) {
		c = 1.0;
	}

	vec4 result_vec = vec4(c,c,c,1.);
	imageStore(output_image, uv, result_vec);
}

// void main() {
// 	// top left
// 	ivec2 tl = ivec2(0, 0);
// 	ivec2 size = ivec2(params.texture_size.x - 1, params.texture_size.y - 1);
// 	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
//
// 	float current_status = imageLoad(current_image, uv).x;
// 	float alive_cells = 0.0;
// 	float total_cells = 0.0;
//
// 	for (int dx = -kernelSize; dx <= kernelSize; dx++) {
// 		for (int dy = -kernelSize; dy <= kernelSize; dy++) {
// 			float cell_value = imageLoad(current_image, clamp(uv + ivec2(dx, dy), tl, size)).x;
// 			float weight = kernelSize - sqrt((dx * dx) + (dy * dy));
// 			alive_cells += cell_value;
// 			total_cells += 1.5 * weight;
// 		}
// 	}
//
// 	float mean = alive_cells / total_cells;
// 	float variance = 0.0;
//
// 	for (int dx = -kernelSize; dx <= kernelSize; dx++) {
// 		for (int dy = -kernelSize; dy <= kernelSize; dy++) {
// 			float cell_value = imageLoad(current_image, clamp(uv + ivec2(dx, dy), tl, size)).x;
// 			variance += (cell_value - mean) * (cell_value - mean);
// 		}
// 	}
//
// 	variance /= total_cells;
// 	float density = sqrt(variance);
//
// 	float next_status = current_status;
//
// 	if (mean > birth_low && mean < birth_high && density > survival_low && density < survival_high) {
// 		next_status = min(1.0, current_status);
// 		// next_status = min(1.0, current_status + 1.5 * rand(uv)); // Increase cell state
// 	} else if (!(mean > survival_low && mean < survival_high && density > survival_low && density < survival_high)) {
// 		next_status = max(0.0, current_status);
// 		// next_status = max(0.0, current_status - 1.5 * rand(uv)); // Decrease cell state
// 	}
//
// 	float result = next_status;
// 	if (params.add_wave_point.z > 0.0 && uv.x == floor(params.add_wave_point.x) && uv.y == floor(params.add_wave_point.y)) {
// 		result = 1.0;
// 	}
// 	vec4 result_vec = vec4(result, result, result, 1.0);
//
// 	imageStore(output_image, uv, result_vec);
// }
