#version 460 core
// ORBIT COMMANDO '94 - CRT post-process.
// Scanlines, barrel curvature, bloom, chromatic aberration, aperture mask,
// vignette and noise. Samples the low-res frame with nearest filtering.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;     // destination size in physical px
uniform vec2 uRes;      // source frame size (640x360, or 320x180)
uniform float uTime;
uniform float uScan;    // scanline strength 0..1
uniform float uCurve;   // barrel curvature 0..0.4
uniform float uChroma;  // chromatic aberration in source px
uniform float uBloom;   // glow 0..1
uniform float uNoise;   // grain 0..0.1
uniform float uRoll;    // "broken tube" vertical roll + wobble
uniform vec2 uOrigin;   // destination top-left
uniform sampler2D uTex;

out vec4 fragColor;

vec2 barrel(vec2 uv) {
  vec2 c = uv * 2.0 - 1.0;
  vec2 off = abs(c.yx) / vec2(6.0, 4.0);
  c = c + c * off * off * (uCurve * 4.0);
  return c * 0.5 + 0.5;
}

vec3 px(vec2 uv) {
  vec2 p = (floor(uv * uRes) + 0.5) / uRes;
  return texture(uTex, p).rgb;
}

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  vec2 frag = FlutterFragCoord().xy - uOrigin;
  vec2 uv = barrel(frag / uSize);
  if (uRoll > 0.0) {
    uv.y = fract(uv.y + uTime * 0.07 * uRoll);
    uv.x += sin(uv.y * 30.0 + uTime * 9.0) * 0.006 * uRoll;
  }
  if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    return;
  }
  float ca = uChroma / uRes.x;
  vec3 col = vec3(px(uv + vec2(ca, 0.0)).r, px(uv).g, px(uv - vec2(ca, 0.0)).b);

  if (uBloom > 0.0) {
    vec2 d = 1.0 / uRes;
    vec3 b = (px(uv + vec2(d.x, 0.0)) + px(uv - vec2(d.x, 0.0)) +
              px(uv + vec2(0.0, d.y)) + px(uv - vec2(0.0, d.y))) * 0.25;
    col += b * b * uBloom;
  }

  // Darken the edges of every source row: classic scanlines.
  float row = fract(uv.y * uRes.y);
  col *= 1.0 - uScan * smoothstep(0.35, 1.0, abs(row - 0.5) * 2.0);

  // Aperture grille every 3 physical pixels.
  float m = mod(frag.x, 3.0);
  col *= 1.0 - 0.10 * uScan * step(2.0, m);

  // Vignette.
  vec2 v = uv * (1.0 - uv.yx);
  col *= clamp(pow(v.x * v.y * 15.0, 0.12 + uCurve), 0.0, 1.0);

  col += (hash(frag + uTime) - 0.5) * uNoise;
  fragColor = vec4(col, 1.0);
}
