#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

// vec2 named after the shader key — sent automatically by draw_shader
extern MY_HIGHP_OR_MEDIUMP vec2 successor_fractal;
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

vec2 hash22(vec2 p)
{
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// full-spectrum hue wheel. The old cosine palette plus the 1.45 saturation
// overdrive collapsed colours to the gamut corners — everything read as pure
// R/G/B. This walks the whole rainbow smoothly; 0.31 slows the traversal so
// arms show broad spectral gradients instead of tight candy stripes.
vec3 hsv2rgb(number h, number s, number v)
{
    vec3 p = abs(fract(vec3(h) + vec3(0.0, 0.6666667, 0.3333333)) * 6.0 - 3.0);
    return v * mix(vec3(1.0), clamp(p - vec3(1.0), 0.0, 1.0), s);
}

vec3 palette(number t, number shift)
{
    return hsv2rgb(fract(t*0.5 + shift), 0.95, 1.0);
}

vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec2 uv = (((texture_coords)*(image_details)) - texture_details.xy*texture_details.ba)/texture_details.ba;

    number T = cx_time;
    number aspect = texture_details.b / max(texture_details.a, 1.0);
    vec4 base = Texel(texture, frame_uv(uv));

    // --- vortex field: swimming spiral centres on a jittered grid (voronoi
    // basins kept for the ids/edges, but each basin now hosts a spiral
    // instead of a kali-fractal shard). Deliberately multi-centre so nothing
    // reads as radiating from the card's middle.
    vec2 vp = vec2(uv.x * aspect, uv.y) * 3.5;
    vec2 n = floor(vp);
    vec2 f = fract(vp);
    number f1 = 8.0;
    number f2 = 8.0;
    vec2 id = vec2(0.0);
    vec2 mr = vec2(0.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash22(n + g);
            o = 0.5 + 0.4*sin(0.6*T + 6.2831*o + successor_fractal.x*0.3);
            vec2 r = g + o - f;
            number d = dot(r, r);
            if (d < f1) { f2 = f1; f1 = d; id = n + g; mr = r; }
            else if (d < f2) { f2 = d; }
        }
    }
    f1 = sqrt(f1);
    f2 = sqrt(f2);
    number edge = f2 - f1;
    number shard_rand = hash21(id);

    // --- the spiral: log-spiral ink arms winding into the basin's swimming
    // centre. Arm count, spin rate and handedness are per-vortex; arms
    // sharpen via pow and brighten toward a hot core.
    number arms = 2.0 + floor(shard_rand * 3.0);
    number dir = hash21(id + 3.3) > 0.5 ? 1.0 : -1.0;
    number spin = T * dir * (0.5 + 0.7*shard_rand);
    number va = atan(mr.y, mr.x + 0.0001);
    number band = 0.5 + 0.5*sin(arms*va - 7.0*log(f1 + 0.06) + spin);
    number acc = pow(band, 3.0) * (0.45 + 0.9*exp(-2.2*f1));
    acc += 0.8*exp(-8.0*f1);

    // --- ever-shifting gradient colouring (CT: colour clock runs 5x the pattern clock)
    number CT = T * 5.0;
    // full colour VOLUME, not just the hue rim: a wheel at fixed s/v only
    // produces the fully-saturated rainbow edge — the "pure RGB" look.
    // Saturation and value get their own independently drifting fields, so
    // pastels, muted tones, deep shades and vivid hues all coexist.
    // acc*1.6: one arm gradient sweeps multiple full rainbows. The sine
    // interference grid scatters extra hue WITHIN arms — many hues in view
    // at once, not one colour family per vortex.
    number hue = acc*1.6 + uv.y*0.55 - uv.x*0.35 + 0.065*CT + shard_rand*0.6
               + 0.22*sin(uv.x*37.0 + 0.9*CT)*sin(uv.y*29.0 - 0.7*CT);
    number sat = 0.40 + 0.58*(0.5 + 0.5*sin(6.2831*(acc*0.37 + 2.7*shard_rand + 0.021*CT)));
    number val = 0.62 + 0.38*(0.5 + 0.5*sin(6.2831*(acc*0.23 + uv.x*0.45 + 3.3*shard_rand + 0.017*CT)));
    vec3 col = hsv2rgb(fract(hue), sat, val);
    col += palette(acc*0.5 + 0.07*CT, 0.5 + 0.03*CT) * acc * 0.35;

    // --- glowing cracks between shards
    number crack = smoothstep(0.08, 0.0, edge);
    col += crack * palette(0.85 + 0.09*CT, shard_rand) * 1.1;

    // --- flicker: per-shard shimmer every tick + rare global spikes
    number tick = floor(T*300.0);   // 25x the entity base flicker (saturates at display fps)
    number fl = 0.82 + 0.36*hash21(id + tick);
    number spike = step(0.94, hash21(vec2(tick, 5.7)));
    col = col * fl + col * spike * 0.7;

    // --- let the base art's structure ghost through the fractal
    number lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
    col *= 0.55 + 0.6*lum;

    // --- silhouette rim pulse
    number px = 1.5 / texture_details.b;
    number py = 1.5 / texture_details.a;
    number a_n = min(min(Texel(texture, frame_uv(uv + vec2(px, 0.))).a,
                         Texel(texture, frame_uv(uv - vec2(px, 0.))).a),
                     min(Texel(texture, frame_uv(uv + vec2(0., py))).a,
                         Texel(texture, frame_uv(uv - vec2(0., py))).a));
    number rim = clamp(base.a - a_n, 0.0, 1.0) * (0.6 + 0.4*sin(2.7*T + uv.y*6.0));
    col += rim * palette(0.2 + 0.11*CT, 0.6) * 1.2;

    // barely-there saturation trim — the hue wheel is already fully saturated;
    // overdriving here is what crushed the spectrum to R/G/B corners before
    number cl = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(vec3(cl), col, 1.05);

    // negative: clamp then invert — ink outlines flare bright, glow becomes shadow
    col = vec3(1.0) - clamp(col, 0.0, 1.0);

    vec4 tex = vec4(col, base.a * (0.88 + 0.06*sin(7.3*T) + 0.06*spike));

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
