shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/optics_limits.gdshaderinc"
uniform vec4 facet_planes[MAX_FACETS];
uniform int facet_count = 0;
uniform int geometry_mode = 0;
uniform vec3 geometry_axes = vec3(1.0);
uniform vec3 geometry_center = vec3(0.0);
uniform vec3 zone_extent = vec3(1.0);
uniform mat3 gem_rotation = mat3(1.0);
uniform vec3 gem_position = vec3(0.0, 1.28, 0.0);
uniform vec3 light_direction = vec3(-0.244, 0.868, 0.434);
uniform float source_radius = 1.8;
uniform float seed_step = 0.025;
uniform float refractive_index = 1.85;
uniform float dispersion = 0.48;
uniform float absorption = 0.70;
uniform vec4 gem_color : source_color = vec4(0.1, 0.75, 0.51, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.1, 0.75, 0.51, 1.0);
uniform int material_mode = 0;
uniform int zone_shape = 0;
uniform vec3 zone_axis = vec3(1.0, 0.0, 0.0);
uniform float zone_offset = 0.0;
uniform float zone_softness = 0.1;
uniform vec3 illuminant_tint = vec3(1.0);
uniform float strength = 1.0;
uniform float material_transmission = 1.0;
varying vec3 photon_color;
varying vec2 splat_coordinate;

// Interval intersection supports both the entering ray and internal exits.
bool interval(vec3 o, vec3 d, out float near_t, out float far_t,
              out vec3 near_n, out vec3 far_n) {
    near_t = -10000.0;
    far_t = 10000.0;
    near_n = vec3(0.0, 1.0, 0.0);
    far_n = vec3(0.0, -1.0, 0.0);
    if (geometry_mode > 0) {
        vec3 q = (o - geometry_center) / geometry_axes;
        vec3 v = d / geometry_axes;
        float a = dot(v, v);
        float b = dot(q, v);
        float disc = b * b - a * (dot(q, q) - 1.0);
        if (disc < 0.0) { return false; }
        near_t = (-b - sqrt(disc)) / a;
        far_t = (-b + sqrt(disc)) / a;
        near_n = normalize((o + d * near_t - geometry_center) / (geometry_axes * geometry_axes));
        far_n = normalize((o + d * far_t - geometry_center) / (geometry_axes * geometry_axes));
        if (geometry_mode == 2) {
            if (abs(d.y) < 0.00001) {
                if (o.y < geometry_center.y) { return false; }
            } else {
                float cap = (geometry_center.y - o.y) / d.y;
                if (d.y > 0.0 && cap > near_t) { near_t = cap; near_n = vec3(0.0, -1.0, 0.0); }
                if (d.y < 0.0 && cap < far_t) { far_t = cap; far_n = vec3(0.0, -1.0, 0.0); }
            }
        }
    } else {
        for (int i = 0; i < MAX_FACETS; i++) {
            if (i >= facet_count) { break; }
            vec3 n = facet_planes[i].xyz;
            float denominator = dot(n, d);
            float distance = facet_planes[i].w - dot(n, o);
            if (abs(denominator) < 0.00001) {
                if (distance < 0.0) { return false; }
            } else {
                float t = distance / denominator;
                if (denominator < 0.0 && t > near_t) { near_t = t; near_n = n; }
                if (denominator > 0.0 && t < far_t) { far_t = t; far_n = n; }
            }
        }
    }
    return far_t > max(near_t, 0.00001);
}

float fresnel_weight(float cosine, float index) {
    float f = pow((index - 1.0) / (index + 1.0), 2.0);
    return f + (1.0 - f) * pow(1.0 - clamp(cosine, 0.0, 1.0), 5.0);
}

vec3 local_tint(vec3 p) {
    if (material_mode != 1) { return gem_color.rgb; }
    vec3 q = p / zone_extent;
    float u = dot(q, zone_axis) - zone_offset;
    float width = max(zone_softness, 0.002);
    float blend = smoothstep(-width, width, u);
    if (zone_shape == 1) {
        blend = smoothstep(-width, width, u + 0.34) - smoothstep(-width, width, u - 0.34);
    } else if (zone_shape == 2) {
        blend = smoothstep(-width, width, length(q.xz) - 0.60 - zone_offset);
    }
    return mix(gem_color.rgb, secondary_color.rgb, blend);
}

bool project_photon(vec2 seed, float index, int band, out vec2 target, out float power) {
    vec3 u = normalize(cross(light_direction, vec3(0.0, 1.0, 0.0)));
    vec3 v = cross(light_direction, u);
    vec3 source = light_direction * (source_radius * 2.2)
                + (u * (seed.x * 2.0 - 1.0) + v * (seed.y * 2.0 - 1.0)) * source_radius;
    mat3 inverse_rotation = transpose(gem_rotation);
    vec3 o = inverse_rotation * source;
    vec3 d = inverse_rotation * -light_direction;
    float entry_t, exit_t;
    vec3 entry_n, exit_n;
    target = vec2(0.0);
    power = 0.0;
    if (!interval(o, d, entry_t, exit_t, entry_n, exit_n) || entry_t < 0.0) { return false; }
    o += d * entry_t;
    float energy = 1.0 - fresnel_weight(-dot(d, entry_n), index);
    d = refract(d, entry_n, 1.0 / index);
    o += d * 0.0005;
    for (int bounce = 0; bounce < 6; bounce++) {
        if (!interval(o, d, entry_t, exit_t, entry_n, exit_n)) { return false; }
        vec3 tint = local_tint(o + d * exit_t * 0.5);
        vec3 extinction = -log(clamp(tint, vec3(0.025), vec3(0.98))) * absorption * 0.36;
        energy *= exp(-extinction[band] * exit_t);
        o += d * exit_t;
        vec3 outgoing = refract(d, -exit_n, index);
        if (dot(outgoing, outgoing) > 0.00001) {
            vec3 world_d = gem_rotation * outgoing;
            vec3 world_o = gem_rotation * o + gem_position;
            if (world_d.y >= -0.035) { return false; }
            float ground_t = (0.006 - world_o.y) / world_d.y;
            target = (world_o + world_d * ground_t).xz;
            power = energy * (1.0 - fresnel_weight(abs(dot(d, exit_n)), index));
            // Reject distant, near-horizontal escapes from the showcase.
            power *= 1.0 - smoothstep(3.1, 4.1, length(target));
            return ground_t > 0.0 && power > 0.001;
        }
        d = reflect(d, exit_n);
        o += d * 0.0005;
    }
    return false;
}

void vertex() {
    int band = int(VERTEX.y + 0.5);
    float band_shift = band == 0 ? -0.46 : (band == 1 ? 0.0 : 0.64);
    float index = refractive_index + dispersion * 0.050 * (refractive_index - 1.0) * band_shift;
    vec2 target, next_x, next_y;
    float energy, unused_power;
    bool valid = project_photon(UV2, index, band, target, energy);
    bool valid_x = project_photon(UV2 + vec2(seed_step, 0.0), index, band, next_x, unused_power);
    bool valid_y = project_photon(UV2 + vec2(0.0, seed_step), index, band, next_y, unused_power);
    vec2 dx = valid_x ? next_x - target : vec2(0.06, 0.0);
    vec2 dy = valid_y ? next_y - target : vec2(0.0, 0.06);
    vec2 major_vector = length(dx) > length(dy) ? dx : dy;
    float major_length = max(length(major_vector), 0.0001);
    vec2 axis = major_vector / major_length;
    vec2 perpendicular = vec2(-axis.y, axis.x);
    float major = clamp(major_length * 0.65 + 0.014, 0.024, 0.15);
    float minor = clamp(abs(dx.x * dy.y - dx.y * dy.x) / major_length * 0.65 + 0.014, 0.024, major);
    vec2 footprint = target + (axis * UV.x * major + perpendicular * UV.y * minor) * 2.8;
    VERTEX = vec3(footprint.x, 0.006, footprint.y);
    float input_area = pow(source_radius * 2.0 * seed_step, 2.0);
    float density = input_area / (6.2831853 * major * minor);
    photon_color = vec3(0.0);
    photon_color[band] = valid ? energy * density * strength * material_transmission * 0.90 : 0.0;
    photon_color *= illuminant_tint;
    splat_coordinate = UV * 2.8;
}

void fragment() {
    float kernel = exp(-0.5 * dot(splat_coordinate, splat_coordinate));
    kernel *= 1.0 - smoothstep(2.4, 2.8, length(splat_coordinate));
    ALBEDO = photon_color;
    ALPHA = kernel;
}
