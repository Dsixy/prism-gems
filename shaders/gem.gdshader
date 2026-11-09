shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// The front surface is a real Blender mesh. Only internal light paths are traced.
// Halfspaces are in mesh-local coordinates and share the exported mesh's geometry.
#include "res://shaders/optics_limits.gdshaderinc"
uniform vec4 facet_planes[MAX_FACETS];
uniform int facet_count = 0;
uniform int geometry_mode = 0;
uniform vec3 geometry_axes = vec3(1.0);
uniform vec3 geometry_center = vec3(0.0);
uniform vec4 body_tint : source_color = vec4(0.10, 0.75, 0.51, 1.0);
uniform float refractive_index : hint_range(1.1, 2.7) = 1.85;
uniform float dispersion : hint_range(0.0, 1.0) = 0.48;
uniform float brilliance : hint_range(0.0, 2.0) = 1.0;
uniform float absorption : hint_range(0.0, 2.5) = 0.70;
uniform int bounce_count : hint_range(1, 12) = 10;
uniform float light_rotation = 0.0;
uniform vec3 illuminant_tint = vec3(1.0);
uniform float studio_refinement : hint_range(0.0, 1.0) = 1.0;
// 0 = uniform, 1 = spatial absorption, 2 = alexandrite, 3 = opal,
// 4 = pearl, 5 = cat's eye, 6 = moonstone.
uniform int material_mode = 0;
uniform int zone_shape = 0;
uniform vec4 zone_color_a : source_color = vec4(0.08, 0.72, 0.42, 1.0);
uniform vec4 zone_color_b : source_color = vec4(0.94, 0.23, 0.53, 1.0);
uniform vec3 zone_extent = vec3(1.0);
uniform vec3 zone_axis = vec3(1.0, 0.0, 0.0);
uniform float zone_offset = 0.0;
uniform float zone_softness = 0.10;
uniform sampler2D alex_transmittance : filter_linear, repeat_disable;
uniform float alex_max_path = 32.0;
uniform float illuminant_row = 0.25;
uniform vec3 camera_position_local = vec3(0.0, 3.0, 6.0);
uniform mat3 object_rotation = mat3(1.0);
varying vec3 point_local;
varying vec3 normal_local;

#include "res://shaders/opal.gdshaderinc"

void vertex() {
    point_local = VERTEX;
    normal_local = NORMAL;
}

float rectangle_card(vec3 d, vec3 direction, vec3 up_axis, vec2 half_size) {
    vec3 right_axis = normalize(cross(direction, up_axis));
    vec3 vertical_axis = normalize(cross(right_axis, direction));
    float front = dot(d, direction);
    vec2 projected = vec2(dot(d, right_axis), dot(d, vertical_axis)) / max(front, 0.001);
    vec2 edge = abs(projected) - half_size;
    return (1.0 - smoothstep(-0.015, 0.015, max(edge.x, edge.y))) * step(0.0, front);
}

vec3 studio(vec3 direction) {
    float focus = material_mode <= 1 ? studio_refinement : 0.0;
    float c = cos(light_rotation);
    float s = sin(light_rotation);
    vec3 d = normalize(vec3(c * direction.x - s * direction.z, direction.y,
                           s * direction.x + c * direction.z));
    vec3 result = mix(vec3(0.018, 0.027, 0.042), vec3(0.13, 0.19, 0.24),
                      smoothstep(-0.6, 0.95, d.y));
    result *= mix(1.0, 0.80, focus);
    float azimuth = atan(d.z, d.x);
    float latitude = asin(clamp(d.y, -1.0, 1.0));
    // Narrow strips, divided softboxes and black gaps are reflected repeatedly.
    // Their angular edges create moving, geometric highlights rather than noise.
    float band_height = smoothstep(-1.0, -0.72, latitude) * (1.0 - smoothstep(0.8, 1.2, latitude));
    float boxes = smoothstep(mix(0.43, 0.60, focus), mix(0.48, 0.66, focus), cos(azimuth * 4.0 + latitude * 0.9));
    float divisions = mix(mix(0.30, 0.12, focus), 1.0, smoothstep(-0.22, -0.14, cos(latitude * 8.0 + azimuth * 1.3)));
    result += vec3(3.7, 3.9, 3.7) * boxes * divisions * band_height;
    float ribbons = smoothstep(mix(0.973, 0.985, focus), mix(0.990, 0.995, focus), cos(azimuth * 13.0 - latitude * 3.5));
    result += vec3(7.0, 7.4, 8.0) * ribbons * band_height;
    float fine = smoothstep(0.992, 0.998, cos(azimuth * 23.0 + latitude * 6.0));
    result += vec3(3.3, 2.8, 2.2) * fine * band_height * mix(1.0, 0.55, focus);
    result += vec3(8.4, 8.6, 8.0) * rectangle_card(d, normalize(vec3(-1.2, 1.5, 1.8)), vec3(0, 1, 0), mix(vec2(0.22, 0.45), vec2(0.17, 0.36), focus));
    result += vec3(5.8, 6.2, 7.0) * rectangle_card(d, normalize(vec3(1.6, 0.7, -0.5)), vec3(0, 1, 0), mix(vec2(0.065, 0.85), vec2(0.05, 0.72), focus));
    result += vec3(3.8, 3.4, 2.9) * rectangle_card(d, normalize(vec3(-0.7, -0.5, -1.7)), vec3(0, 1, 0), mix(vec2(0.33, 0.24), vec2(0.27, 0.20), focus)) * mix(1.0, 0.8, focus);
    result += vec3(0.70, 0.95, 1.15) * rectangle_card(d, normalize(vec3(1.0, -1.0, 1.0)), vec3(0, 1, 0), vec2(0.55, 0.35)) * mix(1.0, 0.65, focus);
    // Small white lights produce brief optical glints as their images cross facets.
    float pinlights = pow(max(0.0, dot(d, normalize(vec3(-0.45, 0.68, 1.0)))), 1100.0);
    pinlights += pow(max(0.0, dot(d, normalize(vec3(0.90, -0.30, -1.0)))), 1450.0);
    result += vec3(11.0, 10.5, 9.8) * pinlights;
    return result * illuminant_tint;
}

// Antiderivative of smoothstep(-w,w,x). This integrates both sides of a
// growth boundary exactly over each internal ray segment, including reflections.
float zone_primitive(float x) {
    float w = max(zone_softness, 0.002);
    float t = clamp((x + w) / (2.0 * w), 0.0, 1.0);
    return 2.0 * w * (t * t * t - 0.5 * t * t * t * t) + max(x - w, 0.0);
}

float average_boundary(float a, float b) {
    if (abs(b - a) < 0.0001) {
        return smoothstep(-zone_softness, zone_softness, (a + b) * 0.5);
    }
    return clamp((zone_primitive(b) - zone_primitive(a)) / (b - a), 0.0, 1.0);
}

float segment_zone(vec3 start, vec3 end) {
    vec3 a = start / zone_extent;
    vec3 b = end / zone_extent;
    float u = dot(a, zone_axis) - zone_offset;
    float v = dot(b, zone_axis) - zone_offset;
    if (zone_shape == 1) {
        return average_boundary(u + 0.34, v + 0.34) - average_boundary(u - 0.34, v - 0.34);
    }
    if (zone_shape == 2) {
        // Four spatial samples integrate curved growth shells; no screen UVs or time.
        float sum = 0.0;
        for (int j = 0; j < 4; j++) {
            vec3 p = mix(a, b, (float(j) + 0.5) * 0.25);
            sum += smoothstep(0.59 + zone_offset - zone_softness,
                              0.59 + zone_offset + zone_softness, length(p.xz));
        }
        return sum * 0.25;
    }
    return average_boundary(u, v);
}

vec3 spectral_transmission(float path) {
    float width = float(textureSize(alex_transmittance, 0).x);
    float u = (clamp(path / alex_max_path, 0.0, 1.0) * (width - 1.0) + 0.5) / width;
    return texture(alex_transmittance, vec2(u, illuminant_row)).rgb;
}

// The nearest exiting plane of a convex solid. The ray starts just inside it.
bool next_surface(vec3 origin, vec3 direction, out float travel, out vec3 normal_out) {
    travel = 10000.0;
    normal_out = vec3(0, 1, 0);
    bool found = false;
    if (geometry_mode > 0) {
        vec3 o = (origin - geometry_center) / geometry_axes;
        vec3 d = direction / geometry_axes;
        float a = dot(d, d);
        float b = dot(o, d);
        float discriminant = b * b - a * (dot(o, o) - 1.0);
        if (discriminant >= 0.0) {
            float t = (-b + sqrt(discriminant)) / max(a, 0.00001);
            vec3 hit = origin + direction * t;
            if (t > 0.000015 && (geometry_mode == 1 || hit.y >= geometry_center.y - 0.00001)) {
                travel = t;
                normal_out = normalize((hit - geometry_center) / (geometry_axes * geometry_axes));
                found = true;
            }
        }
        if (geometry_mode == 2 && direction.y < -0.00001) {
            float cap_t = (geometry_center.y - origin.y) / direction.y;
            vec3 cap = (origin + direction * cap_t - geometry_center) / geometry_axes;
            if (cap_t > 0.000015 && cap_t < travel && dot(cap.xz, cap.xz) <= 1.00001) {
                travel = cap_t;
                normal_out = vec3(0.0, -1.0, 0.0);
                found = true;
            }
        }
        return found;
    }
    for (int i = 0; i < MAX_FACETS; i++) {
        if (i >= facet_count) { break; }
        vec3 n = facet_planes[i].xyz;
        float denominator = dot(n, direction);
        if (denominator > 0.00001) {
            float t = (facet_planes[i].w - dot(n, origin)) / denominator;
            if (t > 0.000015 && t < travel) {
                found = true;
                travel = t;
                normal_out = n;
            }
        }
    }
    return found;
}

float fresnel(float cosine, float index) {
    float f0 = (index - 1.0) / (index + 1.0);
    f0 *= f0;
    return f0 + (1.0 - f0) * pow(1.0 - clamp(cosine, 0.0, 1.0), 5.0);
}

float exit_fresnel(float cosine, float index) {
    float sin_transmitted_squared = index * index * (1.0 - cosine * cosine);
    if (sin_transmitted_squared >= 1.0) { return 1.0; }
    float transmitted_cosine = sqrt(max(0.0, 1.0 - sin_transmitted_squared));
    float perpendicular = (index * cosine - transmitted_cosine) / max(index * cosine + transmitted_cosine, 0.00001);
    float parallel = (cosine - index * transmitted_cosine) / max(cosine + index * transmitted_cosine, 0.00001);
    return (perpendicular * perpendicular + parallel * parallel) * 0.5;
}

vec3 trace_band(vec3 surface, vec3 incoming, vec3 normal_in, float index, vec3 extinction) {
    // Each wavelength follows its own path through the *actual* cut planes.
    // Dispersion can change the next facet hit and the total-internal-reflection
    // decision, instead of merely shifting an environment lookup at the end.
    vec3 energy = vec3(1.0);
    vec3 accumulated = vec3(0.0);
    vec3 direction = refract(incoming, normal_in, 1.0 / index);
    vec3 origin = surface - normal_in * 0.00025 + direction * 0.00015;
    float optical_path = 0.0;
    vec3 extinction_a = -log(clamp(zone_color_a.rgb, vec3(0.025), vec3(0.98))) * absorption * 0.52;
    vec3 extinction_b = -log(clamp(zone_color_b.rgb, vec3(0.025), vec3(0.98))) * absorption * 0.52;
    for (int bounce = 0; bounce < 12; bounce++) {
        if (bounce >= bounce_count) { break; }
        float distance_to_exit;
        vec3 exit_normal;
        if (!next_surface(origin, direction, distance_to_exit, exit_normal)) { break; }
        if (material_mode == 3) {
            // Resolve a shallow volume along the first two refracted segments.
            // Deeper paths retain the existing transparent internal reflections.
            if (bounce < 2) {
                accumulated += energy * opal_segment(origin, direction, distance_to_exit);
                accumulated += energy * vec3(0.34, 0.40, 0.43) * opal_haze
                             * (1.0 - exp(-distance_to_exit * 1.5));
            }
            energy *= exp(-distance_to_exit * (0.10 + opal_haze * 1.3));
        }
        vec3 segment_extinction = extinction;
        if (material_mode == 1) {
            segment_extinction = mix(extinction_a, extinction_b,
                segment_zone(origin, origin + direction * distance_to_exit));
        }
        if (material_mode != 2) {
            energy *= exp(-segment_extinction * distance_to_exit);
        }
        optical_path += distance_to_exit * absorption * 0.72;
        origin += direction * distance_to_exit;
        vec3 outgoing = refract(direction, -exit_normal, index);
        float transmitted_length = dot(outgoing, outgoing);
        float reflection = 1.0;
        if (transmitted_length > 0.00001) {
            reflection = exit_fresnel(abs(dot(direction, exit_normal)), index);
            // Slightly favour deeper paths for a readable cut at pixel resolution.
            // Reflection and transmission still share a single energy budget.
            reflection = mix(reflection, sqrt(reflection), 0.40);
            vec3 transmission = material_mode == 2 ? spectral_transmission(optical_path) : vec3(1.0);
            // A gentler transmitted studio keeps crystal-opal color visible
            // beneath the bright, separately evaluated polished surface.
            float environment_gain = material_mode == 3 ? 0.24 : 1.0;
            accumulated += energy * transmission * (1.0 - reflection)
                         * studio(object_rotation * normalize(outgoing)) * environment_gain;
        }
        energy *= reflection;
        direction = reflect(direction, exit_normal);
        origin += direction * 0.0003;
        if (max(energy.r, max(energy.g, energy.b)) < 0.003) { break; }
    }
    // The small residual is only a bounded approximation for paths beyond the cap.
    vec3 residual_transmission = material_mode == 2 ? spectral_transmission(optical_path) : vec3(1.0);
    float residual_gain = material_mode == 3 ? 0.24 : 1.0;
    accumulated += energy * residual_transmission * studio(object_rotation * direction) * 0.35 * residual_gain;
    return accumulated;
}

#include "res://shaders/soft_gems.gdshaderinc"

vec3 dielectric_radiance(vec3 n, vec3 incoming, vec3 tint, vec3 extinction) {
    float spread = dispersion * 0.050 * (refractive_index - 1.0);
    vec3 indices = refractive_index + spread * vec3(-0.46, 0.0, 0.64);
    vec3 red_path = trace_band(point_local, incoming, n, indices.r, extinction);
    vec3 green_path = trace_band(point_local, incoming, n, indices.g, extinction);
    vec3 blue_path = trace_band(point_local, incoming, n, indices.b, extinction);
    vec3 accumulated = mix((red_path + green_path + blue_path) / 3.0,
                          vec3(red_path.r, green_path.g, blue_path.b), 0.62);
    float entry_reflection = fresnel(-dot(incoming, n), refractive_index);
    vec3 reflected = studio(object_rotation * reflect(incoming, n));
    vec3 radiance = mix(accumulated, reflected, entry_reflection);
    return radiance * (0.72 + brilliance * 1.55) + tint * 0.025;
}

void fragment() {
    vec3 n = normalize(normal_local);
    if (geometry_mode > 0 && !(geometry_mode == 2 && normal_local.y < -0.99)) {
        n = normalize((point_local - geometry_center) / (geometry_axes * geometry_axes));
    }
    vec3 incoming = normalize(point_local - camera_position_local);
    vec3 tint = body_tint.rgb;
    if (material_mode == 1) {
        tint = mix(zone_color_a.rgb, zone_color_b.rgb, segment_zone(point_local, point_local));
    } else if (material_mode == 2) {
        tint = spectral_transmission(1.5);
    }
    vec3 extinction = -log(clamp(tint, vec3(0.025), vec3(0.98))) * absorption * 0.36;
    vec3 radiance;
    if (material_mode == 3 && opal_kind == 1) {
        radiance = black_opal_radiance(point_local, incoming, n, tint);
    } else if (material_mode >= 4) {
        vec3 phenomenon;
        radiance = soft_gem_radiance(n, -incoming, tint, phenomenon);
        if (material_mode >= 5 && geometry_mode == 0) {
            // A translucent faceted body still refracts and disperses light.
            // Mix its diffuse/clear body first, then preserve the separate
            // cat's-eye or moonstone response without scaling it away.
            vec3 clear_body = dielectric_radiance(n, incoming, tint, extinction);
            if (material_mode == 6) {
                // A scattering sheen partly veils the bright transmitted image;
                // adding blue onto an unattenuated white softbox would wash it out.
                clear_body *= mix(0.70, 0.88, moon_rainbow);
                float veil = min(mix(0.75, 0.55, moon_rainbow),
                    max(phenomenon.r, max(phenomenon.g, phenomenon.b)) * mix(0.28, 0.23, moon_rainbow));
                clear_body *= 1.0 - veil;
                // A weak colored veil also filters bright transmitted softbox
                // images. Their facet detail survives beneath the broad sheen.
                float sheen_peak = max(phenomenon.r, max(phenomenon.g, phenomenon.b));
                vec3 sheen_filter = vec3(0.12) + 0.88
                    * pow(phenomenon / max(sheen_peak, 0.0001), vec3(1.6));
                clear_body *= mix(vec3(1.0), sheen_filter,
                    moon_rainbow * clamp(sheen_peak * 0.55, 0.0, 0.90));
            }
            radiance = mix(max(radiance - phenomenon, vec3(0.0)), clear_body,
                           facet_transparency) + phenomenon;
        }
    } else {
        radiance = dielectric_radiance(n, incoming, tint, extinction);
    }
    // Filmic shoulder keeps white flashes, saturated midtones and deep facet shadows.
    vec3 color = radiance / (radiance + vec3(0.72));
    float edge_distance = 1000.0;
    for (int i = 0; i < MAX_FACETS; i++) {
        if (i >= facet_count) { break; }
        if (dot(facet_planes[i].xyz, n) < 0.998) {
            edge_distance = min(edge_distance, abs(facet_planes[i].w - dot(facet_planes[i].xyz, point_local)));
        }
    }
    float pixel_width = max(length(dFdx(point_local)), length(dFdy(point_local)));
    float edge = 1.0 - smoothstep(0.0, pixel_width * 0.34, edge_distance);
    color = mix(color, color * 0.74 + tint * 0.025, edge * 0.42);
    ALBEDO = color;
}
