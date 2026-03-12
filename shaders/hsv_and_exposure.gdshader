// Copyright (c) 2024 roland.marchand@protonmail.com
// SPDX short identifier: 0BSD

shader_type canvas_item;

#define F_STOP_SQUARE 1.0
#define MIN_FLOAT 1.17549435e-38
#define MAX_FLOAT 3.402823466e+38
#define EPSILON 0.00001

uniform float hue: hint_range(-0.5, 0.5, 0.01) = 0.0;
uniform float saturation: hint_range(-1.0, 1.0, 0.01) = 0.0;
uniform float value: hint_range(-1.0, 1.0, 0.01) = 0.0;
// https://upload.wikimedia.org/wikipedia/commons/d/d8/Exposure_program_chart.gif
uniform float exposure: hint_range(0.0, 1.0, 0.01) = 0.5;

bool nearly_equal(float a, float b) {
	float absA = abs(a);
	float absB = abs(b);
	float diff = abs(a - b);

	if (abs(a - b) < EPSILON) { // shortcut, handles infinities
		return true;
	} else if (a == 0.0 || b == 0.0 || (absA + absB < MIN_FLOAT)) {
		// a or b is zero or both are extremely close to it
		// relative error is less meaningful here
		return diff < (EPSILON * MIN_FLOAT);
	} else { // use relative error
		return diff / min((absA + absB), MAX_FLOAT) < EPSILON;
	}
}

float get_hue(vec3 rgb) {
	float minimum = min(min(rgb.r, rgb.g), rgb.b);
	float maximum = max(max(rgb.r, rgb.g), rgb.b);
	float delta = maximum - minimum;

	if (nearly_equal(delta, 0.0)) {
		return 0.0;
	}

	float ret;
	if (nearly_equal(rgb.r, maximum)) {
		ret = (rgb.g - rgb.b) / delta; // between yellow & magenta
	} else if (nearly_equal(rgb.g, maximum)) {
		ret = 2.0 + (rgb.b - rgb.r) / delta; // between cyan & yellow
	} else {
		ret = 4.0 + (rgb.r - rgb.g) / delta;// between magenta & cyan
	}

	ret /= 6.0;
	if (ret < 0.0) {
		ret += 1.0;
	}

	return ret;
}

float get_saturation(vec3 rgb) {
	float minimum = min(min(rgb.r, rgb.g), rgb.b);
	float maximum = max(max(rgb.r, rgb.g), rgb.b);
	float delta = maximum - minimum;
	return abs(maximum - 0.0) < EPSILON ? 0.0 : delta / maximum;
}

float get_value(vec3 rgb) {
	return max(max(rgb.r, rgb.g), rgb.b);
}

vec3 get_hsv(vec3 rgb) {
	return vec3(get_hue(rgb), get_saturation(rgb), get_value(rgb));
}

vec3 get_rgb(vec3 hsv) {
	vec3 rgb;
	int i;
	float f, p, q, t;

	if (nearly_equal(hsv.y, 0.0)) {
		rgb.r = rgb.g = rgb.b = hsv.z;
		return rgb;
	}

	hsv.x *= 6.0;
	hsv.x = mod(hsv.x, 6.0);
	i = int(floor(hsv.x));

	f = hsv.x - float(i);
	p = hsv.z * (1.0 - hsv.y);
	q = hsv.z * (1.0 - hsv.y * f);
	t = hsv.z * (1.0 - hsv.y * (1.0 - f));

	switch (i) {
		case 0: // Red is the dominant color
			rgb.r = hsv.z;
			rgb.g = t;
			rgb.b = p;
			break;
		case 1: // Green is the dominant color
			rgb.r = q;
			rgb.g = hsv.z;
			rgb.b = p;
			break;
		case 2:
			rgb.r = p;
			rgb.g = hsv.z;
			rgb.b = t;
			break;
		case 3: // Blue is the dominant color
			rgb.r = p;
			rgb.g = q;
			rgb.b = hsv.z;
			break;
		case 4:
			rgb.r = t;
			rgb.g = p;
			rgb.b = hsv.z;
			break;
		default: // (5) Red is the dominant color
			rgb.r = hsv.z;
			rgb.g = p;
			rgb.b = q;
			break;
	}

	return rgb;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);

	vec3 HSV = get_hsv(COLOR.rgb);

	HSV.x = mod(HSV.x + hue, 1.0);
	HSV.y = clamp(HSV.y + saturation, 0.0, 1.0);
	HSV.z = clamp(HSV.z + value, 0.0, 1.0);

	COLOR.rgb = get_rgb(HSV);

	// Exposure
	COLOR.rgb *= log2(F_STOP_SQUARE / exposure);
}