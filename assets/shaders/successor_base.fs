#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

// vec2 named after the shader key — sent automatically by draw_shader (x drifts with time/rotation)
extern MY_HIGHP_OR_MEDIUMP vec2 successor_base;
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

// Old-television treatment for the Successor's paper base: full black-and-white
// conversion with contrast punch, per-texel animated snow, scanlines, a bright
// band rolling down the frame, tick-gated horizontal row jitter, frame-wide
// brightness flicker and a CRT corner vignette. The ink art stays legible
// underneath — the fuzz rides on top of the luminance.
vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;

    number T = cx_time;
    number tick = floor(T * 24.0);            // static refreshes at ~24fps

    // occasional horizontal tracking error: a tick where 2px rows shove sideways
    number jgate = step(0.90, hash21(vec2(tick, 3.7)));
    number row = floor(uv.y * texture_details.a / 2.0);
    number jr = hash21(vec2(row, tick + successor_base.x));
    vec2 suv = uv;
    suv.x += jgate * step(0.55, jr) * (jr - 0.775) * 0.12;

    vec4 tex = Texel(texture, frame_uv(suv));

    // black & white with an S-curve for tube contrast
    number lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    lum = smoothstep(0.06, 0.94, lum);

    // per-texel animated snow
    vec2 cell = floor(uv * texture_details.ba);
    number n = hash21(cell + vec2(tick*7.13, tick*3.71));
    lum += (n - 0.5) * 0.22;

    // scanlines
    lum *= 0.86 + 0.14*sin(uv.y * texture_details.a * 3.14159);

    // bright band rolling down the frame
    number band = fract(uv.y - T * 0.12);
    lum += 0.10 * smoothstep(0.0, 0.08, band) * smoothstep(0.16, 0.08, band);

    // frame-wide flicker + corner vignette
    lum *= 0.92 + 0.08*hash21(vec2(tick, 9.1));
    vec2 cv = uv - 0.5;
    lum *= 1.0 - 0.60*dot(cv, cv);

    vec4 outc = vec4(vec3(clamp(lum, 0.0, 1.0)), tex.a);
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
