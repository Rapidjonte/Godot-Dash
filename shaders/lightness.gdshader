shader_type canvas_item;

uniform float lightness : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 grayscale = vec3(gray);

    float saturation = 1.0 + lightness;

    vec3 col = mix(grayscale, tex.rgb, saturation);
    col = mix(col, vec3(1.0), lightness);

    // calculate color saturation (how far from gray it is)
    float maxc = max(tex.r, max(tex.g, tex.b));
    float minc = min(tex.r, min(tex.g, tex.b));
    float sat = maxc - minc;

    // apply effect mostly to saturated colors
    tex.rgb = mix(tex.rgb, col, sat);

    COLOR = tex;
}