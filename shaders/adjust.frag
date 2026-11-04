#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// El orden de los uniforms debe coincidir con Adjust en lib/adjust.dart.
uniform vec2 uSize;
uniform float uExposure;    // -1..1  (±2 EV)
uniform float uContrast;    // -1..1
uniform float uHighlights;  // -1..1
uniform float uShadows;     // -1..1
uniform float uWhites;      // -1..1
uniform float uBlacks;      // -1..1
uniform float uSaturation;  // -1..1
uniform float uVibrance;    // -1..1
uniform float uTemperature; // -1..1
uniform float uTint;        // -1..1
uniform float uSharpness;   //  0..1
uniform float uVignette;    //  0..1
uniform sampler2D uImage;

out vec4 fragColor;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

vec3 tap(vec2 uv) {
  return texture(uImage, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec3 c = tap(uv);

  // Nitidez: máscara de enfoque con radio proporcional al tamaño, para que
  // la vista previa y la exportación se vean igual.
  if (uSharpness > 0.0) {
    vec2 px = vec2(max(1.0, max(uSize.x, uSize.y) / 1600.0)) / uSize;
    vec3 blur = (tap(uv + vec2(px.x, 0.0)) + tap(uv - vec2(px.x, 0.0)) +
                 tap(uv + vec2(0.0, px.y)) + tap(uv - vec2(0.0, px.y))) *
                    0.15 +
                (tap(uv + px) + tap(uv - px) +
                 tap(uv + vec2(px.x, -px.y)) +
                 tap(uv + vec2(-px.x, px.y))) *
                    0.1;
    c += (c - blur) * uSharpness * 2.5;
  }

  // Exposición en espacio lineal.
  vec3 lin = pow(max(c, vec3(0.0)), vec3(2.2));
  lin *= exp2(uExposure * 2.0);
  c = pow(lin, vec3(1.0 / 2.2));

  // Balance de blancos: multiplica para no teñir los negros.
  c *= vec3(1.0 + uTemperature * 0.15, 1.0 - uTint * 0.12,
            1.0 - uTemperature * 0.15);

  // Tonos por zona.
  float l = dot(c, kLuma);
  c += uHighlights * 0.30 * smoothstep(0.45, 1.0, l);
  c += uShadows * 0.30 * (1.0 - smoothstep(0.0, 0.55, l));
  c += uWhites * 0.15 * smoothstep(0.7, 1.0, l);
  c += uBlacks * 0.15 * (1.0 - smoothstep(0.0, 0.3, l));

  // Contraste alrededor del gris medio.
  c = (c - 0.5) * (1.0 + uContrast * 0.6) + 0.5;

  // Saturación e intensidad (la intensidad afecta menos a lo ya saturado).
  l = dot(c, kLuma);
  float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
  c = mix(vec3(l), c, 1.0 + uSaturation);
  c = mix(vec3(l), c, 1.0 + uVibrance * (1.0 - clamp(sat, 0.0, 1.0)));

  // Viñeta.
  if (uVignette > 0.0) {
    vec2 d = (uv - 0.5) * vec2(uSize.x / max(uSize.x, uSize.y),
                               uSize.y / max(uSize.x, uSize.y));
    float v = smoothstep(0.75, 0.2, length(d) * 1.2);
    c *= mix(1.0, v, uVignette * 0.85);
  }

  fragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}
