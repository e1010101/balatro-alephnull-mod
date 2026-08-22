#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

// vec2 named after the shader key — sent automatically by draw_shader
extern MY_HIGHP_OR_MEDIUMP vec2 creator;
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

vec2 rot2(vec2 v, number a)
{
    number c = cos(a);
    number s = sin(a);
    return vec2(c*v.x - s*v.y, s*v.x + c*v.y);
}

// resolve the split/swirl/reform: for a frame-local uv, find which drifting
// shard shows that point (inverse mapping over six angular pieces) and sample
vec4 shard_sample(Image texture, vec2 u, number e, number orbit, number T)
{
    number PI = 3.14159265;
    number TAU = 6.2831853;
    number aspect = texture_details.b / texture_details.a;
    vec2 P = (u - 0.5) * vec2(aspect, 1.0);
    vec4 tex = vec4(0.0);
    for (int i = 0; i < 6; i++) {
        number fi = float(i);
        number A = (fi + 0.5) * (TAU / 6.0);
        number dir = A + orbit + e*0.35*sin(0.6*T + fi*2.1);
        number R = e * (0.17 + 0.045*sin(fi*2.399 + 0.4*T));
        vec2 off = R * vec2(cos(dir), sin(dir));
        number spin = (mod(fi, 2.0) < 1.0) ? 1.0 : -1.0;
        number rho = e * (0.8*sin(0.45*T + fi*1.7) + 0.12*spin*orbit);
        vec2 q = rot2(P - off, -rho);
        number sa = atan(q.y, q.x);
        number d = abs(mod(sa - A + PI, TAU) - PI);
        if (d <= (PI / 6.0)) {
            vec2 suv = q / vec2(aspect, 1.0) + 0.5;
            if (suv.x > 0.0 && suv.x < 1.0 && suv.y > 0.0 && suv.y < 1.0) {
                vec4 s = Texel(texture, frame_uv(suv));
                if (s.a > tex.a) { tex = s; }
            }
        }
    }
    return tex;
}

vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;

    number T = cx_time;           // real-time clock: drives the shard cycle
    number TT = cx_time * 10.0;   // entity-speed clock: drives the glitch treatment
    number seed = time * 0.001;

    // split / swirl / reform, one cycle every 5 seconds; angle keeps advancing
    // while the radius collapses with e, so pieces spiral home on reform
    number p = fract(T / 5.0);
    number e = smoothstep(0.12, 0.40, p) * (1.0 - smoothstep(0.62, 0.92, p));
    number orbit = 6.2831853 * smoothstep(0.12, 0.92, p);

    vec2 cuv = uv - 0.5;
    number rad = length(cuv);
    number ang = atan(cuv.y, cuv.x + 0.0001);

    // ---- from here down: the Entity's treatment, sampling through the shards ----

    // reality "breathing" — ripples radially like it can't hold its shape
    number warp = 0.010*sin(7.0*rad - 2.2*TT + seed) + 0.006*sin(5.0*ang + 1.6*TT);
    vec2 wuv = uv + warp * vec2(cos(ang), sin(ang));

    // glitch bursts — short windows where 3px rows tear sideways
    number tick = floor(TT*10.0);
    number burst = step(0.90, hash21(vec2(tick, seed)));
    number row = floor(wuv.y * texture_details.a / 3.0);
    number rh = hash21(vec2(row, tick));
    wuv.x += burst * step(0.55, rh) * (rh - 0.775) * 0.35;

    // chromatic aberration on a slowly rotating axis, stronger at the rim and during bursts
    number ab_amt = 0.006 + 0.014*rad + 0.012*burst + 0.003*sin(2.4*TT + creator.x);
    vec2 ab_dir = vec2(cos(0.8*TT + creator.x*0.5), sin(0.8*TT + creator.x*0.5));
    vec4 sR = shard_sample(texture, wuv + ab_amt*ab_dir, e, orbit, T);
    vec4 sC = shard_sample(texture, wuv, e, orbit, T);
    vec4 sB = shard_sample(texture, wuv - ab_amt*ab_dir, e, orbit, T);
    vec4 tex = vec4(sR.r, sC.g, sB.b, max(sC.a, 0.6*max(sR.a, sB.a)));

    // iridescent hue drift, weighted by saturation so blacks/whites keep their identity
    number mx = max(tex.r, max(tex.g, tex.b));
    number mn = min(tex.r, min(tex.g, tex.b));
    number sat_w = smoothstep(0.05, 0.30, mx - mn);
    tex.rgb = mix(tex.rgb, hue_rotate(tex.rgb, 1.1*TT + 4.0*rad - ang), sat_w);

    // pulsing rgb rim glow around the (shard-mapped) silhouette
    number px = 1.5 / texture_details.b;
    number py = 1.5 / texture_details.a;
    number a_n = min(min(shard_sample(texture, wuv + vec2(px, 0.), e, orbit, T).a,
                         shard_sample(texture, wuv - vec2(px, 0.), e, orbit, T).a),
                     min(shard_sample(texture, wuv + vec2(0., py), e, orbit, T).a,
                         shard_sample(texture, wuv - vec2(0., py), e, orbit, T).a));
    number rim = clamp(sC.a - a_n, 0.0, 1.0) * (0.65 + 0.35*sin(3.1*TT + ang*2.0));
    vec3 rim_col = 0.5 + 0.5*vec3(sin(1.3*TT), sin(1.3*TT + 2.094), sin(1.3*TT + 4.188));
    tex.rgb += rim * rim_col * 0.9;
    tex.a = max(tex.a, rim * 0.8);

    // negative flash on some bursts
    tex.rgb = mix(tex.rgb, vec3(1.0) - tex.rgb, burst * step(0.7, hash21(vec2(tick, 7.77))) * 0.85);

    // faint scanline shimmer + slow radial brightness pulse
    tex.rgb *= (0.96 + 0.04*sin(uv.y*90.0 + TT*8.0)) * (1.0 + 0.08*sin(2.0*TT + rad*6.0));

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
