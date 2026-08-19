#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

// Text-pipeline shader: applied per letter via DynaText:set_letter_shader.
// The letter pipeline sends text_*/letter_* uniforms (NOT the sprite uniforms),
// and LOVE errors on sends to undeclared uniforms — every extern below must
// exist and be used.

// vec2 named after the shader key — sent as {G.TIMERS.REAL/28, G.TIMERS.REAL}
extern MY_HIGHP_OR_MEDIUMP vec2 entity_text;
// true animated clock, sent via SMODS.Shader send_vars
extern MY_HIGHP_OR_MEDIUMP number cx_time;

extern MY_HIGHP_OR_MEDIUMP vec4 text_details;    // screen rect of the whole text (px)
extern MY_HIGHP_OR_MEDIUMP number text_scale;
extern MY_HIGHP_OR_MEDIUMP number text_rot;
extern MY_HIGHP_OR_MEDIUMP vec4 letter_details;  // letter offset + dims (px)
extern MY_HIGHP_OR_MEDIUMP number letter_scale;
extern MY_HIGHP_OR_MEDIUMP number letter_rot;
extern bool text_shadow;

number hash21(vec2 p)
{
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    vec4 tex = Texel(texture, texture_coords); // glyph mask

    // continuous coordinates across the whole text block, so the plasma flows
    // through the word and the letters act as windows into it
    vec2 suv = (screen_coords - text_details.xy) / max(vec2(text_details.z, text_details.w), vec2(1.0, 1.0));

    number T = cx_time;
    number lseed = letter_details.x*0.37 + letter_details.z*0.011;
    number rot = text_rot + letter_rot;

    // glitch: horizontal slice tears through the text
    number tick = floor(T*12.0);
    number burst = step(0.6, hash21(vec2(tick, lseed)));
    number row = floor(suv.y * 14.0);
    number rh = hash21(vec2(row, tick));
    suv.x += burst * step(0.6, rh) * (rh - 0.8) * 0.25;

    // plasma turbulence, matching the deck back's colour language
    vec2 p = suv * vec2(3.0, 2.0);
    p += 0.8*vec2(sin(2.3*p.y + 2.0*T + rot), cos(1.9*p.x + 1.7*T));
    p += 0.5*vec2(sin(3.7*p.y - 1.4*T + lseed), cos(4.1*p.x + 1.2*T));
    number field = sin(p.x) + sin(p.y) + sin(p.x + p.y + 2.0*T) + sin(length(p)*2.2 - 1.6*T);
    number phase = field*0.5 + 0.4*T + entity_text.x*0.5 + suv.x*1.5;

    // rainbow-fringed channels, harder during bursts
    number d = 0.06 + 0.08*burst;
    vec3 col = 0.5 + 0.5*cos(6.28318*(phase*2.6 + vec3(0.00, 0.33, 0.67) + vec3(d, 0.0, -d)));

    // luminous: text must glow, never go muddy
    number cl = dot(col, vec3(0.299, 0.587, 0.114));
    col = clamp(mix(vec3(cl, cl, cl), col, 1.6), 0.0, 1.0);
    col = 0.25 + 0.85*col;
    col *= 0.94 + 0.06*sin(6.0*T + text_scale + letter_scale);

    if (text_shadow) {
        col *= 0.25;
    }

    return vec4(col, tex.a) * colour;
}
