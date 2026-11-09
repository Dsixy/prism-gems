// A fixed 3D field stores domain normals and spacings, not rainbow colors.
// View/light directions select the visible diffraction response at runtime.
uniform sampler3D opal_domains : filter_linear, repeat_enable;
uniform sampler3D black_opal_domains : filter_nearest, repeat_enable;
uniform sampler3D opal_domain_order : filter_linear, repeat_enable;
uniform int opal_kind = 0;
uniform vec3 black_opal_pattern_offset = vec3(1.448, 1.044, 1.652);
uniform float opal_patch_size : hint_range(0.0, 1.0) = 0.55;
uniform float opal_strength : hint_range(0.0, 2.0) = 1.15;
uniform float opal_haze : hint_range(0.0, 1.0) = 0.22;
uniform vec3 opal_key_local = vec3(-0.35, 0.55, 0.76);
uniform vec3 opal_fill_local = vec3(0.8, 0.35, -0.3);

vec3 opal_spectrum(float wavelength) {
    // Smooth display-space approximation to a narrow spectral reflection.
    vec3 color = exp(-0.5 * pow((vec3(wavelength) - vec3(615.0, 535.0, 453.0))
                               / vec3(37.0, 27.0, 25.0), vec3(2.0)));
    color.r += exp(-0.5 * pow((wavelength - 410.0) / 22.0, 2.0)) * 0.45;
    color /= max(max(color.r, color.g), max(color.b, 0.001));
    return color * smoothstep(380.0, 405.0, wavelength)
                 * (1.0 - smoothstep(700.0, 755.0, wavelength));
}

vec3 opal_light_response(vec4 domain, vec3 view, vec3 light) {
    vec3 plane = normalize(domain.rgb * 2.0 - 1.0 + vec3(0.0001));
    vec3 half_vector = normalize(view + light + vec3(0.0001));
    float alignment = abs(dot(plane, half_vector));
    float broad_flash = smoothstep(0.60, 0.96, alignment);
    float sharp_flash = pow(alignment, 56.0);
    // Reflection form of Bragg's relation, used as a real-time approximation.
    float spacing = mix(185.0, 305.0, domain.a);
    float wavelength = 2.0 * 1.45 * spacing * abs(dot(plane, light));
    return opal_spectrum(wavelength) * (broad_flash * 2.6 + sharp_flash * 5.0);
}

vec3 opal_segment(vec3 start, vec3 direction, float travel) {
    vec3 sum = vec3(0.0);
    float step_length = min(travel, 0.9) / 3.0;
    float frequency = mix(0.80, 0.24, opal_patch_size);
    for (int sample_index = 0; sample_index < 3; sample_index++) {
        float distance = (float(sample_index) + 0.35) * step_length;
        vec3 p = (start + direction * distance) / zone_extent;
        vec3 uvw = p * vec3(1.0, 0.28, 1.0) * frequency + vec3(0.41, 0.57, 0.23);
        // Low-amplitude warp avoids a regular grid while leaving domains fixed.
        uvw += sin(p.zxy * 5.3 + p.yzx * 2.7) * 0.014;
        vec4 domain = texture(opal_domains, uvw);
        vec3 color = opal_light_response(domain, -direction, opal_key_local);
        color += opal_light_response(domain, -direction, opal_fill_local) * 0.38;
        float attenuation = exp(-distance * (0.45 + opal_haze * 1.8));
        sum += color * attenuation * (1.0 - exp(-step_length * 1.5));
    }
    return sum * opal_strength * illuminant_tint * 1.25;
}

vec3 black_opal_response(vec4 domain, vec3 view, vec3 light) {
    vec3 plane = normalize(domain.rgb * 2.0 - 1.0);
    float alignment = abs(dot(plane, normalize(view + light)));
    float wavelength = 2.0 * 1.45 * mix(175.0, 285.0, domain.a) * abs(dot(plane, light));
    vec3 spectral = opal_spectrum(wavelength);
    spectral = mix(spectral, (opal_spectrum(wavelength - 12.0) + spectral
                           + opal_spectrum(wavelength + 12.0)) / 3.0, 0.55);
    return spectral * (0.12 + smoothstep(0.40, 0.95, alignment) * 3.2);
}

vec3 black_opal_radiance(vec3 surface, vec3 incoming, vec3 normal_in, vec3 tint) {
    vec3 inward = refract(incoming, normal_in, 1.0 / 1.45);
    float frequency = mix(0.65, 0.22, opal_patch_size);
    vec3 color = vec3(0.0);
    // Two closely spaced shallow samples keep large domains coherent. The
    // opaque dark backing does not repeat them through ten mirror-like bounces.
    for (int layer = 0; layer < 2; layer++) {
        vec3 p = (surface + inward * (0.10 + float(layer) * 0.18)) / zone_extent;
        vec3 uvw = p * vec3(1.0, 0.13, 1.0) * frequency + black_opal_pattern_offset;
        uvw += sin(p.zxy * 4.1 + p.yzx * 2.4) * 0.035;
        vec4 domain = texture(black_opal_domains, uvw);
        float order = texture(opal_domain_order, uvw).r;
        vec3 broad = black_opal_response(domain, -inward, opal_key_local);
        broad += black_opal_response(domain, -inward, opal_fill_local) * 0.35;
        // The small-scale signal controls glints, not a second full-strength
        // rainbow competing with the large patch's hue.
        vec4 micro = texture(black_opal_domains, uvw * 3.7 + vec3(0.19, 0.07, 0.31));
        // Fine variation stays inside the parent hue, giving a patch depth
        // without turning every grain boundary into a new rainbow.
        float grain = texture(opal_domains, uvw * 8.3 + vec3(0.11, 0.29, 0.67)).a;
        broad *= 0.60 + 0.60 * smoothstep(0.2, 0.8, grain);
        vec3 plane = normalize(domain.rgb * 2.0 - 1.0);
        vec3 halfway = normalize(-inward + opal_key_local);
        float glint = pow(abs(dot(plane, halfway)), 90.0) * smoothstep(0.72, 0.95, micro.a);
        broad += mix(opal_spectrum(2.0 * 1.45 * mix(175.0, 285.0, domain.a)
                     * abs(dot(plane, opal_key_local))), vec3(1.0), 0.35) * glint * 2.4;
        float weight = layer == 0 ? 0.78 : 0.22;
        color += broad * mix(0.02, 1.0, order) * weight;
    }
    vec3 view = -incoming;
    vec3 half_key = normalize(view + opal_key_local);
    float wrapped = clamp((dot(normal_in, opal_key_local) + 0.40) / 1.40, 0.0, 1.0);
    vec3 backing = mix(vec3(0.030, 0.043, 0.060), tint * 0.48, 0.35)
                 * (0.55 + wrapped * 0.85);
    float polish = pow(max(dot(normal_in, half_key), 0.0), 1200.0) * 6.5;
    float rim = pow(1.0 - max(dot(view, normal_in), 0.0), 4.0);
    float depth_gain = mix(1.05, 0.72, opal_haze);
    return (backing + color * opal_strength * depth_gain * 1.25
           + vec3(1.0) * polish + vec3(0.10, 0.13, 0.17) * rim)
           * illuminant_tint * (0.85 + brilliance * 0.75);
}
