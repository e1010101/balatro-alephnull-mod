#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

// vec2 named after the shader key — sent automatically by draw_shader
extern MY_HIGHP_OR_MEDIUMP vec2 creator_base;
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

vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;

    number T = cx_time;
    number TAU = 6.2831853;

    number aspect = texture_details.b / texture_details.a;
    vec2 P = (uv - 0.5) * vec2(aspect, 1.0);
    number rad = length(P);
    number ang = atan(P.y, P.x);

    // keep the card border still: warping/wash fades out near the frame edge
    number edge = smoothstep(0.0, 0.14, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));

    vec4 tex = Texel(texture, frame_uv(uv));

    // ---- shimmering psychedelic hypnosis: fast inward rings x spinning
    // spokes drive a constantly churning two-layer hue field ----
    number rings  = sin(22.0*rad - 5.5*T);
    number wheel  = sin(7.0*ang + 3.2*T + 3.0*rad*sin(0.5*T));
    number breath = sin(0.9*T);
    number h = 0.22*T + 0.30*rings + 0.22*wheel + 0.40*rad + 0.001*creator_base.x;
    vec3 c1 = 0.62 + 0.38*cos(TAU*h + vec3(0.0, 2.094, 4.188));
    vec3 c2 = 0.62 + 0.38*cos(TAU*(h + 0.45) + vec3(0.0, 2.094, 4.188));
    vec3 field = mix(c1, c2, 0.5 + 0.5*rings*wheel);

    // ---- gloss, entity-adjacent: lacquer contrast, sweeping glint beam,
    // caustic hotspots, and the finishing shimmer ----
    field = field*field*(3.0 - 2.0*field);
    field = mix(field, field*field, 0.22);
    number d1 = dot(P, vec2(0.8, 0.6));
    number d2 = dot(P, vec2(-0.5, 0.866));
    number sheen1 = pow(clamp(0.5 + 0.5*sin(6.0*d1 - 1.7*T), 0.0, 1.0), 24.0);
    number sheen2 = pow(clamp(0.5 + 0.5*sin(4.5*d2 + 1.15*T), 0.0, 1.0), 40.0);
    // a highlight beam rotating around the face like light raking lacquer
    number glint = pow(max(0.0, cos(ang - 1.3*T)), 10.0) * (0.30 + 0.15*breath);
    // hotspots where the rings and spokes align
    number hot = 0.30*pow(max(0.0, rings*wheel), 6.0);
    field += (0.55*sheen1 + 0.40*sheen2)*(0.7 + 0.3*breath) + glint + hot;
    // finishing shimmer (finer + slower than the Entity's): scanlines + pulse
    field *= (0.965 + 0.035*sin(uv.y*110.0 + T*6.0)) * (1.0 + 0.07*sin(1.7*T + rad*5.0));

    // lay the field over the card face; luma weighting keeps the dark art dark
    number luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    tex.rgb = mix(tex.rgb, field*(0.30 + 0.70*luma), (0.85*edge + 0.10)*tex.a);

    // ---- random negative flicker: the whole face inverts for one ~33 ms
    // tick, roughly once a second on average ----
    number fl_tick = floor(T * 30.0);
    number neg = step(0.965, hash21(vec2(fl_tick, 4.2)));
    tex.rgb = mix(tex.rgb, vec3(1.0) - tex.rgb, neg*0.9);

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
