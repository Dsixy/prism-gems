shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 ground_color : source_color = vec4(0.885, 0.886, 0.854, 1.0);
uniform vec4 gem_color : source_color = vec4(0.10, 0.75, 0.51, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.10, 0.75, 0.51, 1.0);
uniform bool special_material = false;
uniform vec3 illuminant_tint = vec3(1.0);
uniform float strength : hint_range(0.0, 2.0) = 1.0;
uniform float material_caustic = 1.0;
uniform bool smooth_form = false;
uniform float phase = 0.0;
uniform float clock_time = 0.0;
uniform float gem_height = 1.25;
uniform vec2 footprint_axes = vec2(1.0);
uniform vec4 outline_planes[32];
uniform int outline_count = 0;
uniform float outline_rotation = 0.0;
varying vec3 floor_position;

void vertex() { floor_position = VERTEX; }

float pool(vec2 point, vec2 center, vec2 scale, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    vec2 p = point - center;
    p = vec2(c * p.x - s * p.y, s * p.x + c * p.y) / scale;
    float a = atan(p.y, p.x);
    float r = length(p) + 0.05 * sin(a * 5.0 + angle);
    return 1.0 - smoothstep(0.84, 1.0, r);
}

void fragment() {
    vec2 p = floor_position.xz;
    vec2 shadow_center = vec2(0.27, 0.07);
    float sc = cos(outline_rotation);
    float ss = sin(outline_rotation);
    vec2 shadow_local = p - shadow_center;
    shadow_local = vec2(sc * shadow_local.x - ss * shadow_local.y,
                        ss * shadow_local.x + sc * shadow_local.y) / 1.12;
    float signed_edge = -1000.0;
    for (int i = 0; i < 32; i++) {
        if (i >= outline_count) { break; }
        signed_edge = max(signed_edge, dot(outline_planes[i].xy, shadow_local) - outline_planes[i].z);
    }
    float shadow = 1.0 - smoothstep(smooth_form ? -0.045 : -0.025, smooth_form ? 0.08 : 0.025, signed_edge);
    vec3 color = mix(ground_color.rgb, ground_color.rgb * vec3(0.64, 0.69, 0.73), shadow * 0.68);
    float c = cos(phase * 0.60);
    float s = sin(phase * 0.60);
    vec2 q = p - vec2(0.30, 0.06);
    q = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
    q /= footprint_axes * (1.0 + sin(clock_time * 1.2) * 0.025);
    float a = pool(q, vec2(-0.26, 0.05), vec2(0.64, 0.48), -0.3);
    float b = pool(q, vec2(0.25, -0.02), vec2(0.57, 0.43), 0.25);
    float inner = pool(q, vec2(0.0), vec2(0.50, 0.30), -0.2);
    float core = pool(q, vec2(-0.04, 0.0), vec2(0.24, 0.26), 0.6);
    vec3 tint = gem_color.rgb;
    vec3 cyan = mix(vec3(0.10, 0.80, 0.78), tint, 0.50);
    vec3 violet = mix(vec3(0.60, 0.25, 0.96), tint.brg, 0.25);
    if (special_material) {
        cyan = mix(tint, vec3(1.0), 0.18);
        violet = mix(secondary_color.rgb, vec3(1.0), 0.16);
    }
    float pool_strength = strength * material_caustic;
    color = mix(color, cyan, clamp(a * pool_strength * 0.68, 0.0, 1.0));
    color = mix(color, violet, clamp(b * pool_strength * 0.70, 0.0, 1.0));
    color = mix(color, mix(vec3(0.82, 0.99, 0.86), tint, 0.18), clamp(inner * pool_strength * 0.84, 0.0, 1.0));
    color = mix(color, vec3(0.98, 1.0, 0.93), clamp(core * pool_strength, 0.0, 1.0));
    ALBEDO = color * mix(vec3(1.0), illuminant_tint, 0.38);
}
