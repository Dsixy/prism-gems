shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
uniform vec4 ground_color : source_color = vec4(0.885, 0.886, 0.854, 1.0);
uniform vec3 illuminant_tint = vec3(1.0);
uniform vec4 shadow_planes[96];
uniform int shadow_count = 0;
uniform float shadow_softness = 0.65;
uniform float shadow_enabled = 1.0;
uniform float shadow_opacity = 0.55;
uniform float gem_height = 1.28;
uniform vec2 footprint_axes = vec2(1.0);
varying vec3 floor_position;
void vertex() { floor_position = VERTEX; }
void fragment() {
    vec2 p = floor_position.xz;
    float edge = -1000.0;
    for (int i = 0; i < 96; i++) {
        if (i >= shadow_count) { break; }
        edge = max(edge, dot(shadow_planes[i].xy, p) - shadow_planes[i].z);
    }
    float blur = (0.025 + shadow_softness * 0.28) * max(gem_height, 0.25);
    float core = 1.0 - smoothstep(-blur, blur, edge);
    float penumbra = 1.0 - smoothstep(-blur * 0.5, blur * 2.3, edge);
    // Soft ambient occlusion sits below the floating specimen; the main shadow
    // uses its full 3D silhouette projected along the overhead studio light.
    vec2 ambient_p = p / (footprint_axes * (0.82 + gem_height * 0.14));
    float ambient = exp(-dot(ambient_p, ambient_p) * 1.8);
    float occlusion = ((core * 0.70 + penumbra * 0.30) * shadow_opacity
                      + ambient * 0.16) * shadow_enabled;
    vec3 color = ground_color.rgb * (vec3(1.0) - vec3(0.43, 0.37, 0.32) * occlusion);
    ALBEDO = color * mix(vec3(1.0), illuminant_tint, 0.38);
}
