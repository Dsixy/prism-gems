// Separate surface/volume responses for pearl, chatoyancy and adularescence.
// All structures are in object space; only light/view directions drive motion.
uniform vec3 key_light_local = vec3(-0.35, 0.55, 0.76);
uniform vec3 fill_light_local = vec3(0.8, 0.35, -0.3);
uniform float pearl_luster = 0.72;
uniform float pearl_orient = 0.45;
uniform float eye_strength = 1.0;
uniform float eye_width = 0.055;
uniform vec3 eye_axis = vec3(1.0, 0.0, 0.0);
uniform float moon_strength = 1.0;
uniform float moon_spread = 0.78;
uniform float moon_depth = 0.55;
uniform float moon_rainbow : hint_range(0.0, 1.0) = 0.85;
uniform float facet_transparency : hint_range(0.0, 1.0) = 0.70;

vec3 nacre_film(vec3 n, vec3 view) {
    float cosine = clamp(0.5 * (dot(n, view) + dot(n, key_light_local)), 0.0, 1.0);
    float internal_cosine = sqrt(1.0 - (1.0 - cosine * cosine) / (1.53 * 1.53));
    float thickness = 405.0 + 9.0 * sin(point_local.x * 8.0 + point_local.z * 5.0)
                            * sin(point_local.y * 6.0 + 0.7);
    vec3 phase = 6.2831853 * (2.0 * 1.53 * thickness * internal_cosine)
                 / vec3(615.0, 535.0, 450.0);
    return 0.5 + 0.5 * cos(phase);
}

vec3 soft_gem_radiance(vec3 n, vec3 view, vec3 tint, out vec3 phenomenon) {
    phenomenon = vec3(0.0);
    vec3 h = normalize(view + key_light_local);
    vec3 fill_h = normalize(view + fill_light_local);
    float nh = max(dot(n, h), 0.0);
    float key_wrap = clamp((dot(n, key_light_local) + 0.45) / 1.45, 0.0, 1.0);
    float fill_wrap = clamp((dot(n, fill_light_local) + 0.40) / 1.40, 0.0, 1.0);
    float facing = max(dot(n, view), 0.0);
    float rim = pow(1.0 - facing, 3.0);
    vec3 result = vec3(0.0);
    if (material_mode == 4) {
        // Opaque, softly scattering nacre; no diamond-like transmitted facets.
        float lighting = 0.23 + key_wrap * 0.75 + fill_wrap * 0.28;
        vec3 film = nacre_film(n, view);
        vec3 overtone = (film - vec3((film.r + film.g + film.b) / 3.0)) * pearl_orient;
        result = tint * lighting * 3.1;
        result += overtone * (1.8 + rim * 1.9) * lighting;
        float specular = pow(nh, mix(18.0, 85.0, pearl_luster));
        float soft_halo = pow(nh, 9.0) * 0.65;
        float fill_gloss = pow(max(dot(n, fill_h), 0.0), 48.0) * 1.0;
        result += (vec3(1.0) + overtone * 0.75)
                  * (specular * 14.0 + soft_halo + fill_gloss * 2.0) * pearl_luster;
        result += vec3(0.18, 0.20, 0.22) * rim;
    } else {
        vec3 inward = refract(-view, n, 1.0 / refractive_index);
        float thickness = 0.0;
        vec3 exit_normal;
        bool has_path = next_surface(point_local - n * 0.0004, inward, thickness, exit_normal);
        // Soft surroundings preserve glassy depth without copying the faceted
        // gem's narrow studio strips into these cloudy cabochon interiors.
        vec3 transmitted = mix(vec3(0.18, 0.22, 0.27), vec3(1.6, 1.8, 1.95),
                               smoothstep(-0.4, 0.9, (object_rotation * inward).y));
        vec3 extinction = -log(clamp(tint, vec3(0.03), vec3(0.98))) * absorption * 0.55;
        vec3 transmission = exp(-extinction * (has_path ? thickness : 1.0));
        float white_gloss = pow(nh, 180.0) * 2.5
                          + pow(max(dot(n, fill_h), 0.0), 160.0) * 0.70;
        if (material_mode == 5) {
            // Refracted view/light directions relative to fixed internal fibers.
            // The narrow reflection locus runs across the inclusion direction.
            vec3 internal_light = -refract(-key_light_local, n, 1.0 / refractive_index);
            vec3 internal_half = normalize(-inward + internal_light);
            // The broad focusing correction keeps the eye within the dome
            // under the large studio source; the inclusion axis remains fixed.
            float distance_to_eye = dot(internal_half - h * 0.78, eye_axis);
            float sigma = max(eye_width, 0.008);
            float core = exp(-0.5 * pow(distance_to_eye / sigma, 2.0));
            float halo = exp(-0.5 * pow(distance_to_eye / (sigma * 3.0), 2.0));
            float window = pow(nh, 1.6);
            float milk_side = smoothstep(-0.14, 0.14, distance_to_eye);
            float silky = 0.96 + 0.04 * sin(dot(point_local, cross(eye_axis, vec3(0, 1, 0))) * 320.0);
            result = tint * (0.25 + key_wrap * 0.95 + fill_wrap * 0.20)
                     * mix(0.72, 1.38, milk_side) * 1.75;
            result += mix(transmission, tint, 0.3) * transmitted * 0.055;
            phenomenon = vec3(1.0, 0.93, 0.70) * (core * 5.4 + halo * 0.72)
                         * window * eye_strength * silky;
            result += phenomenon;
            result += vec3(1.0, 0.98, 0.90) * white_gloss * 0.60;
        } else {
            // A broad, shallow, layer-oriented blue scattering cloud behind the
            // sharp exterior polish. Depth changes the refracted sampling position.
            vec3 probe = point_local + inward * moon_depth * 0.72;
            vec3 inner_n = normalize((probe - geometry_center) / (zone_extent * zone_extent)
                                    + vec3(0.0, 0.20, 0.0));
            vec3 layer_n = normalize(vec3(0.16, 1.0, 0.28));
            float layer_alignment = 0.28 + 0.72 * pow(abs(dot(h, layer_n)), 2.0);
            vec3 glow_direction = normalize(h + layer_n * 0.22);
            float alignment = max(dot(inner_n, glow_direction), 0.0);
            float cloud = 0.88 + 0.12 * sin(probe.x * 5.0 + probe.z * 3.0)
                                           * sin(probe.y * 6.0 - probe.z * 2.0);
            float broad = pow(alignment, mix(16.0, 3.0, moon_spread)) * cloud;
            float core = pow(alignment, 38.0);
            result = tint * (0.22 + key_wrap * 0.50 + fill_wrap * 0.22) * 1.50;
            result += transmission * transmitted * 0.085;
            result += transmission * vec3(0.32, 0.39, 0.48);
            vec3 blue_sheen = (vec3(0.045, 0.62, 3.6) * broad
                              + vec3(0.35, 0.65, 1.05) * core) * 2.0;
            // A continuous, shallow layer response, fixed in the stone. Its
            // broad overlapping color lobes move with the refracted probe and
            // the view/light half-vector; no screen-space or time-driven hue.
            vec3 layered_position = (probe - geometry_center) / zone_extent;
            float layer_coordinate = dot(layered_position, vec3(0.08, 0.35, -0.90));
            layer_coordinate += dot(h, normalize(vec3(0.30, 0.0, 0.95))) * 0.85;
            vec3 band_centers = vec3(0.46, 0.02, -0.46);
            vec3 bands = exp(-0.5 * pow((vec3(layer_coordinate) - band_centers)
                                      / vec3(0.40, 0.39, 0.44), vec3(2.0)));
            vec3 rainbow_color = vec3(0.12, 0.15, 0.23) + bands * vec3(1.35, 1.65, 2.3);
            float crown_window = smoothstep(-0.65, 0.25,
                (point_local.y - geometry_center.y) / zone_extent.y);
            float wide_alignment = clamp(0.50 + 0.50 * dot(inner_n, glow_direction), 0.0, 1.0);
            float wide_cloud = 1.30 * pow(wide_alignment, mix(4.0, 0.30, moon_spread))
                               * cloud * crown_window;
            vec3 rainbow_sheen = rainbow_color * wide_cloud * 6.0
                                + vec3(0.16, 0.25, 0.38) * core;
            phenomenon = mix(blue_sheen, rainbow_sheen, moon_rainbow)
                         * moon_strength * layer_alignment;
            result += phenomenon;
            result += vec3(0.94, 0.98, 1.0) * white_gloss * 0.60;
            result += vec3(0.08, 0.14, 0.22) * rim;
        }
    }
    vec3 lighting_scale = illuminant_tint * (0.82 + brilliance * 0.18);
    phenomenon *= lighting_scale;
    return max(result, vec3(0.0)) * lighting_scale;
}
