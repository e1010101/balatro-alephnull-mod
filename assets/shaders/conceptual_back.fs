#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

// vec2 named after the shader key — sent automatically by draw_shader
extern MY_HIGHP_OR_MEDIUMP vec2 conceptual_back;
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

// Deck-back exclusive: max-colour psychedelic plasma under intense datamosh-style
// glitching. Brightness floor is high — the dark back art shapes the pattern but
// never dims it.
vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;

    number T = cx_time;
    number seed = time * 0.001;
    vec4 sil = Texel(texture, frame_uv(uv)); // unglitched sample — silhouette only

    // --- heavy glitch displacement (uv space), ~half of all ticks are glitching
    number tick = floor(T*14.0);
    number burst = step(0.55, hash21(vec2(tick, seed)));

    vec2 guv = uv;
    // coarse block tears
    vec2 block = floor(uv * vec2(6.0, 10.0));
    number bh = hash21(block + tick);
    guv.x += burst * step(0.5, bh) * (bh - 0.75) * 0.5;
    // fine row jitter
    number row = floor(guv.y * texture_details.a / 2.0);
    number rh = hash21(vec2(row, tick*1.7));
    guv.x += burst * step(0.7, rh) * (rh - 0.85) * 0.3;
    // occasional vertical smear per column-block
    guv.y += burst * step(0.8, hash21(vec2(block.x, tick))) * (hash21(block + 1.1) - 0.5) * 0.2;

    number lum = dot(Texel(texture, frame_uv(guv)).rgb, vec3(0.299, 0.587, 0.114));

    // --- dense fast plasma on the glitched coordinates
    vec2 p = guv * 4.0;
    p += 0.80*vec2(sin(2.1*p.y + 1.9*T), cos(1.7*p.x + 1.6*T));
    p += 0.50*vec2(sin(3.3*p.y - 1.3*T + 1.7), cos(3.9*p.x + 1.1*T + 0.4));
    p += 0.30*vec2(cos(5.7*p.y + 2.3*T), sin(5.1*p.x - 2.1*T));

    number field = sin(p.x) + sin(p.y) + sin(p.x + p.y + 1.8*T) + sin(length(p)*2.0 - 1.5*T);
    number phase = field*0.5 + lum*1.2 + 0.35*T + conceptual_back.x*0.4;

    // rainbow-fringed channels: r/b sample offset phase, harder during bursts
    number d = 0.06 + 0.10*burst;
    vec3 fringe = vec3(d, 0.0, -d);
    vec3 colA = 0.5 + 0.5*cos(6.28318*(phase*2.2 + vec3(0.00, 0.33, 0.67) + fringe));
    vec3 colB = 0.5 + 0.5*cos(6.28318*(phase*3.7 + 0.30*T + vec3(0.13, 0.74, 0.46) + fringe));
    vec3 col = mix(colA, colB, 0.5 + 0.5*sin(field*1.7 + 2.0*T));

    // high brightness floor — colourful even where the art is black
    col *= 0.75 + 0.45*lum;

    // saturation crank
    number cl = dot(col, vec3(0.299, 0.587, 0.114));
    col = clamp(mix(vec3(cl, cl, cl), col, 1.7), 0.0, 1.0);

    // negative flash on some bursts
    number inv = burst * step(0.75, hash21(vec2(tick, 3.3)));
    col = mix(col, vec3(1.0) - col, inv*0.9);

    // fast scanline shimmer
    col *= 0.92 + 0.08*sin(uv.y*140.0 + 20.0*T);

    // silhouette rim pulse
    number px = 1.5 / texture_details.b;
    number py = 1.5 / texture_details.a;
    number a_n = min(min(Texel(texture, frame_uv(uv + vec2(px, 0.))).a,
                         Texel(texture, frame_uv(uv - vec2(px, 0.))).a),
                     min(Texel(texture, frame_uv(uv + vec2(0., py))).a,
                         Texel(texture, frame_uv(uv - vec2(0., py))).a));
    number rim = clamp(sil.a - a_n, 0.0, 1.0);
    col += rim * (0.5 + 0.5*cos(6.28318*(0.45*T + vec3(0.00, 0.33, 0.67))));

    // alpha from the UNGLITCHED silhouette so tears never leak past the card shape
    vec4 tex = vec4(col, sil.a);

    return dissolve_mask(tex*colour, texture_coords, uv);
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
