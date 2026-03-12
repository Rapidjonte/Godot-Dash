shader_type canvas_item;

uniform float radius = 16.0;

void fragment() {
    vec2 size = vec2(textureSize(TEXTURE, 0));
    vec2 pos = UV * size;

    vec2 dist = min(pos, size - pos);
    float mask = step(radius, min(dist.x, dist.y));

    vec4 tex = texture(TEXTURE, UV);
    COLOR = tex * mask;
}