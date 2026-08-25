#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

// vec2 named after the shader key — sent automatically by draw_shader (x drifts with time/rotation)
extern MY_HIGHP_OR_MEDIUMP vec2 successor;
// true animated clock, sent via SMODS.Shader send_vars (the built-in `time` extern is a static per-sprite value)
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

// convert a local 0-1 uv back to atlas coords, clamped so warped samples never bleed into neighbouring frames
vec2 frame_uv(vec2 u)
{
    u = clamp(u, vec2(0.002), vec2(0.998));
    return ((u + texture_details.xy) * texture_details.ba) / image_details;
}

number hash21(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// rotate a colour around the grey axis (cheap hue rotation, no HSL round-trip)
vec3 hue_rotate(vec3 c, number a)
{
    const vec3 k = vec3(0.57735, 0.57735, 0.57735);
    number ca = cos(a);
    number sa = sin(a);
    return c*ca + cross(k, c)*sa + k*dot(k, c)*(1.0 - ca);
}

// Heavy glitch for the Successor's arrows. Deliberately NO polar terms: the
// first version reused entity.fs's radial breathing/hue/pulse, and at cranked
// amplitude those sin(rad)/sin(ang) fields read as a regular floral mandala
// radiating from the card centre. This one is built on a staggered block
// lattice instead — individual bricks pop toward the viewer (zoom toward
// their own centre + catch light), shove sideways, and channel-split on their
// own axes, so the glitch is chunky and spatial rather than a flat warped pane.
vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;

    number T = cx_time * 10.0;
    number seed = time * 0.001;

    // staggered brick lattice on its own clock (brick rows so no regular mesh)
    number btick = floor(T * 2.5);
    number rowi = floor(uv.y * 9.0);
    number stag = hash21(vec2(rowi, 5.1));
    number colf = uv.x * 6.0 + stag;
    vec2 cellId = vec2(floor(colf), rowi);
    number ch = hash21(cellId + vec2(btick, seed));
    number gate = step(0.62, ch);
    number depth = gate * (ch - 0.62) / 0.38;
    vec2 cellCenter = vec2((floor(colf) + 0.5 - stag) / 6.0, (rowi + 0.5) / 9.0);

    // popped bricks zoom toward the viewer and shove in a random direction
    vec2 wuv = mix(uv, cellCenter + (uv - cellCenter) * (1.0 - 0.24*depth), gate);
    wuv += (vec2(hash21(cellId + vec2(btick, 1.7)),
                 hash21(cellId + vec2(btick, 4.3))) - 0.5) * 0.11 * gate;

    // planar ink wobble — crossed travelling waves, nothing radiates
    wuv += 0.007 * vec2(sin(uv.y*13.0 + 1.9*T) + 0.6*sin(uv.y*29.0 - 1.3*T),
                        sin(uv.x*11.0 - 1.6*T) + 0.6*sin(uv.x*23.0 + 2.1*T));

    // fast row tears on 2px rows
    number tick = floor(T*16.0);
    number burst = step(0.35, hash21(vec2(tick, seed)));
    number row = floor(wuv.y * texture_details.a / 2.0);
    number rh = hash21(vec2(row, tick));
    wuv.x += burst * step(0.35, rh) * (rh - 0.675) * 0.90;

    // aberration: slow global axis, but popped bricks override it with their
    // own random axis and a much larger split — separated ink plates per chunk
    vec2 gdir = vec2(cos(0.8*T + successor.x*0.5), sin(0.8*T + successor.x*0.5));
    vec2 cdir = normalize(vec2(hash21(cellId + vec2(btick, 8.2)) - 0.5,
                               hash21(cellId + vec2(btick, 2.9)) - 0.5) + vec2(0.001));
    vec2 ab_dir = normalize(mix(gdir, cdir, gate));
    number ab_amt = 0.010 + 0.055*depth + 0.060*burst + 0.006*sin(2.4*T + successor.x);
    vec4 sR = Texel(texture, frame_uv(wuv + ab_amt*ab_dir));
    vec4 sC = Texel(texture, frame_uv(wuv));
    vec4 sB = Texel(texture, frame_uv(wuv - ab_amt*ab_dir));
    vec4 tex = vec4(sR.r, sC.g, sB.b, max(sC.a, 0.6*max(sR.a, sB.a)));

    // hue drift: diagonal sweep + hard per-brick jump — no rings
    number mx = max(tex.r, max(tex.g, tex.b));
    number mn = min(tex.r, min(tex.g, tex.b));
    number sat_w = smoothstep(0.05, 0.30, mx - mn);
    tex.rgb = mix(tex.rgb, hue_rotate(tex.rgb, 1.1*T + 3.0*(uv.x - uv.y) + 6.28*ch*gate), sat_w);

    // pulsing rgb rim glow around the silhouette (phase runs on the diagonal)
    number px = 1.5 / texture_details.b;
    number py = 1.5 / texture_details.a;
    number a_n = min(min(Texel(texture, frame_uv(wuv + vec2(px, 0.))).a,
                         Texel(texture, frame_uv(wuv - vec2(px, 0.))).a),
                     min(Texel(texture, frame_uv(wuv + vec2(0., py))).a,
                         Texel(texture, frame_uv(wuv - vec2(0., py))).a));
    number rim = clamp(sC.a - a_n, 0.0, 1.0) * (0.65 + 0.35*sin(3.1*T + (uv.x + uv.y)*6.0));
    vec3 rim_col = 0.5 + 0.5*vec3(sin(1.3*T), sin(1.3*T + 2.094), sin(1.3*T + 4.188));
    tex.rgb += rim * rim_col * 0.9;
    tex.a = max(tex.a, rim * 0.8);

    // negative flash: per popped brick often, whole frame rarely
    tex.rgb = mix(tex.rgb, vec3(1.0) - tex.rgb, gate * step(0.75, hash21(cellId + vec2(btick, 7.7))) * 0.9);
    tex.rgb = mix(tex.rgb, vec3(1.0) - tex.rgb, burst * step(0.85, hash21(vec2(tick, 7.77))) * 0.85);

    // popped bricks catch light; scanline shimmer stays; radial pulse is gone
    tex.rgb *= 1.0 + 0.16*depth;
    tex.rgb *= 0.90 + 0.10*sin(uv.y*90.0 + T*8.0);

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
