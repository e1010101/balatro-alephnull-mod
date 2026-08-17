#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

// vec2 named after the shader key — sent automatically by draw_shader
extern MY_HIGHP_OR_MEDIUMP vec2 entity_base;
// true animated clock, sent via SMODS.Shader send_vars
extern MY_HIGHP_OR_MEDIUMP number cx_time;

extern MY_HIGHP_OR_MEDIUMP number dissolve;
extern MY_HIGHP_OR_MEDIUMP number time;
extern MY_HIGHP_OR_MEDIUMP vec4 texture_details;
extern MY_HIGHP_OR_MEDIUMP vec2 image_details;
extern bool shadow;
extern MY_HIGHP_OR_MEDIUMP vec4 burn_colour_1;
extern MY_HIGHP_OR_MEDIUMP vec4 burn_colour_2;

vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv)
{
    if (dissolve < 0.001) {
        return vec4(shadow ? vec3(0.,0.,0.) : tex.xyz, shadow ? tex.a*0.3: tex.a);
    }

    float adjusted_dissolve = (dissolve*dissolve*(3.-2.*dissolve))*1.02 - 0.01; //Adjusting 0.0-1.0 to fall to -0.1 - 1.1 scale so the mask does not pause at extreme values

    float t = time * 10.0 + 2003.;
    vec2 floored_uv = (floor((uv*texture_details.ba)))/max(texture_details.b, texture_details.a);
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(texture_details.b, texture_details.a);

    vec2 field_part1 = uv_scaled_centered + 50.*vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.*vec2(cos( t / 53.1532),  cos( t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.*vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1.+ (
        cos(length(field_part1) / 19.483) + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92) ))/2.;
    vec2 borders = vec2(0.2, 0.8);

    float res = (.5 + .5* cos( (adjusted_dissolve) / 82.612 + ( field + -.5 ) *3.14))
    - (floored_uv.x > borders.y ? (floored_uv.x - borders.y)*(5. + 5.*dissolve) : 0.)*(dissolve)
    - (floored_uv.y > borders.y ? (floored_uv.y - borders.y)*(5. + 5.*dissolve) : 0.)*(dissolve)
    - (floored_uv.x < borders.x ? (borders.x - floored_uv.x)*(5. + 5.*dissolve) : 0.)*(dissolve)
    - (floored_uv.y < borders.x ? (borders.x - floored_uv.y)*(5. + 5.*dissolve) : 0.)*(dissolve);

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow && res < adjusted_dissolve + 0.8*(0.5-abs(adjusted_dissolve-0.5)) && res > adjusted_dissolve) {
        if (!shadow && res < adjusted_dissolve + 0.5*(0.5-abs(adjusted_dissolve-0.5)) && res > adjusted_dissolve) {
            tex.rgba = burn_colour_1.rgba;
        } else if (burn_colour_2.a > 0.01) {
            tex.rgba = burn_colour_2.rgba;
        }
    }

    return vec4(shadow ? vec3(0.,6.,0.) : tex.xyz, res > adjusted_dissolve ? (shadow ? tex.a*0.3: tex.a) : .0);
}

vec2 frame_uv(vec2 u)
{
    u = clamp(u, vec2(0.002), vec2(0.998));
    return ((u + texture_details.xy) * texture_details.ba) / image_details;
}

number hash21(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Overlay pass: drawn on top of the card base + edition. Mostly transparent —
// the conceptual edition laminate stays visible; this just tears reality on top of it.
vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;

    number T = cx_time;
    number seed = time * 0.001;

    vec4 base = Texel(texture, frame_uv(uv));
    vec4 outc = vec4(0.0);

    vec3 cycle_col = 0.5 + 0.5*vec3(sin(1.3*T), sin(1.3*T + 2.094), sin(1.3*T + 4.188));

    // sweeping scan band travelling down the card
    number band_pos = fract(0.27*T + 0.05*sin(entity_base.x));
    number band = smoothstep(0.07, 0.0, abs(uv.y - band_pos));
    outc.rgb += cycle_col * band * 0.4;
    outc.a = max(outc.a, band * 0.26 * base.a);

    // glitch tears — 4px rows of the base art rip sideways with chromatic split
    number tick = floor(T*10.0);
    number burst = step(0.90, hash21(vec2(tick, seed + 3.3)));
    number row = floor(uv.y * texture_details.a / 4.0);
    number rh = hash21(vec2(row, tick));
    number sel = step(0.62, rh);
    vec2 tuv = uv;
    tuv.x += burst * sel * (rh - 0.81) * 0.4;
    number ab = 0.010 + 0.020*burst;
    vec3 torn = vec3(Texel(texture, frame_uv(tuv + vec2(ab, 0.))).r,
                     Texel(texture, frame_uv(tuv)).g,
                     Texel(texture, frame_uv(tuv - vec2(ab, 0.))).b);
    number tear_a = burst * sel * Texel(texture, frame_uv(tuv)).a * 0.9;
    outc.rgb = mix(outc.rgb, torn, tear_a);
    outc.a = max(outc.a, tear_a);

    // brief negative flash of the whole base on some bursts
    number neg = burst * step(0.75, hash21(vec2(tick, 9.31)));
    outc.rgb = mix(outc.rgb, vec3(1.0) - base.rgb, neg * 0.6);
    outc.a = max(outc.a, neg * 0.45 * base.a);

    // pulsing rim glow tracing the card silhouette
    number px = 1.5 / texture_details.b;
    number py = 1.5 / texture_details.a;
    number a_n = min(min(Texel(texture, frame_uv(uv + vec2(px, 0.))).a,
                         Texel(texture, frame_uv(uv - vec2(px, 0.))).a),
                     min(Texel(texture, frame_uv(uv + vec2(0., py))).a,
                         Texel(texture, frame_uv(uv - vec2(0., py))).a));
    number rim = clamp(base.a - a_n, 0.0, 1.0) * (0.6 + 0.4*sin(3.1*T + uv.y*5.0));
    outc.rgb += cycle_col * rim;
    outc.a = max(outc.a, rim * 0.75);

    // faint iridescent sheen wave so the base never sits fully still
    number wave = 0.5 + 0.5*sin(8.0*uv.x - 5.0*uv.y + 1.7*T);
    outc.rgb += cycle_col * wave * 0.06;
    outc.a = max(outc.a, 0.05 * wave * base.a);

    // scanline flicker on the overlay itself
    outc.a *= 0.9 + 0.1*sin(uv.y*120.0 + 9.0*T);

    return dissolve_mask(outc*colour, texture_coords, uv);
}

extern MY_HIGHP_OR_MEDIUMP vec2 mouse_screen_pos;
extern MY_HIGHP_OR_MEDIUMP float hovering;
extern MY_HIGHP_OR_MEDIUMP float screen_scale;

#ifdef VERTEX
vec4 position( mat4 transform_projection, vec4 vertex_position )
{
    if (hovering <= 0.){
        return transform_projection * vertex_position;
    }
    float mid_dist = length(vertex_position.xy - 0.5*love_ScreenSize.xy)/length(love_ScreenSize.xy);
    vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy)/screen_scale;
    float scale = 0.2*(-0.03 - 0.3*max(0., 0.3-mid_dist))
                *hovering*(length(mouse_offset)*length(mouse_offset))/(2. -mid_dist);

    return transform_projection * vertex_position + vec4(0,0,0,scale);
}
#endif
