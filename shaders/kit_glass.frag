// KitGlass: a liquid-glass backdrop filter (design standard §10, glass).
//
// Runs as ImageFilter.compose(outer: this shader, inner: a small blur) inside
// a BackdropFilterLayer, clipped by the widget's rounded rectangle: the blur
// is the frost (Impeller's downsampled Gaussian, cheaper and smoother than
// taps here), this pass is the lens and the light. Impeller hands it the
// (frosted) backdrop as u_texture and
// sets u_size to that texture's size; FlutterFragCoord() is a pixel of that
// texture, which is the screen's physical pixel grid for the app's layers.
//
// Cost budget (issue #87: performance is the gate): one pass over the glass's
// own rectangle, two texture reads per pixel, no loops. Everything else is
// arithmetic on the rounded rectangle's distance field.
//
//   1. Lens: within u_band of the edge the backdrop is read from further
//      inside, pulling the content outwards like the thick rim of a lens.
//   2. Dispersion: red is read a little further in than green and blue at
//      the rim (one extra read), a hint of a prism.
//   3. Tint: the surface colour at full strength over the middle, where the
//      labels sit (the 4.5:1 contrast the frosted dock guarantees), thinning
//      to half across the band so the bent edge shows.
//   4. Rim: an analytic specular highlight lit from the top left, a fainter
//      one opposite, and a slight inner glow across the band.

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;    // backdrop texture size (set by the engine)
uniform vec4 u_rect;    // glass rectangle in backdrop pixels: l, t, r, b
uniform float u_radius; // corner radius, pixels
uniform float u_band;   // width of the refracting edge, pixels
uniform float u_bend;   // largest displacement at the edge, pixels
uniform float u_rim;    // rim light strength, 0..1
uniform float u_px;     // one logical pixel in backdrop pixels (dpr)
uniform vec4 u_tint;    // surface colour (straight rgb) and its opacity

uniform sampler2D u_texture;

out vec4 frag_color;

vec4 backdrop(vec2 px) {
  // Stay inside the glass: the backdrop outside the clip may be cut out.
  vec2 p = clamp(px, u_rect.xy + 0.5, u_rect.zw - 0.5);
  vec2 uv = p / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_texture, uv);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 half_size = (u_rect.zw - u_rect.xy) * 0.5;
  vec2 p = frag - (u_rect.xy + half_size);
  float r = min(u_radius, min(half_size.x, half_size.y));

  // Signed distance to the rounded rectangle (negative inside) and the
  // outward normal of the nearest edge.
  vec2 q = abs(p) - half_size + r;
  vec2 s = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
  float outside = length(max(q, 0.0));
  float dist = outside + min(max(q.x, q.y), 0.0) - r;
  vec2 normal;
  if (q.x > 0.0 && q.y > 0.0) {
    normal = s * (q / max(outside, 0.0001));
  } else if (q.x > q.y) {
    normal = vec2(s.x, 0.0);
  } else {
    normal = vec2(0.0, s.y);
  }

  float depth = max(-dist, 0.0);
  float edge = clamp(1.0 - depth / u_band, 0.0, 1.0);
  float bend = u_bend * edge * edge;

  vec4 color = backdrop(frag - normal * bend);
  // Dispersion: red from a little further in, only where the lens bends.
  float red = backdrop(frag - normal * bend * 1.35).r;
  color.r = mix(color.r, red, edge * 0.6);

  color.rgb = mix(color.rgb, u_tint.rgb, u_tint.a * (1.0 - 0.5 * edge * edge));

  // Specular rim: a thin line of light where the edge faces the light,
  // softer where it faces away, and a faint glow across the band.
  vec2 light = vec2(-0.6, -0.8);
  float facing = dot(normal, light);
  float line = 1.0 - smoothstep(0.0, 1.6 * u_px, depth);
  float halo = 1.0 - smoothstep(0.0, 6.0 * u_px, depth);
  float spec = line * (0.28 + 0.62 * pow(max(facing, 0.0), 2.0) +
                       0.3 * pow(max(-facing, 0.0), 3.0)) +
               halo * 0.16 * pow(max(facing, 0.0), 3.0) + edge * 0.035;
  color.rgb = mix(color.rgb, vec3(1.0), clamp(spec * u_rim, 0.0, 1.0));
  color.a = 1.0;
  frag_color = color;
}
