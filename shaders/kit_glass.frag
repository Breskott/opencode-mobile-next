// KitGlass: a liquid-glass backdrop filter (design standard §10, glass).
//
// Two ways to run, one program (loaded once; nothing compiles per frame):
//
// - One surface (u_cover == 0): ImageFilter.compose(outer: this shader,
//   inner: a small blur) inside a BackdropFilterLayer, clipped by the
//   widget's rounded rectangle. The blur is the frost (Impeller's
//   downsampled Gaussian); the clip is the crisp edge; this pass is the lens
//   and the light.
// - Two surfaces joined like drops (u_cover > 0, KitGlass.pair): this
//   shader alone inside a rectangular clip around both. It draws its own
//   edge from the distance field (one physical pixel of anti-aliasing, so
//   the joined outline is as crisp as a clip), frosts with seven taps of
//   radius u_cover, and draws nothing (transparent) outside the shapes, so
//   the backdrop there is untouched.
//
// Impeller hands it the backdrop as u_texture and sets u_size to that
// texture's size; FlutterFragCoord() is a pixel of that texture, which is the
// screen's physical pixel grid for the app's layers.
//
// Cost budget (issue #87: performance is the gate): one pass over the glass's
// own rectangle; two texture reads per pixel for one surface, eight for the
// joined pair (a small top control); no loops.
//
//   1. Lens: within u_band of the edge the backdrop is read from further
//      inside, pulling the content outwards like the thick rim of a lens.
//   2. Dispersion: red is read a little further in than green and blue at
//      the rim (one extra read), a hint of a prism.
//   3. Tint: the surface colour at full strength over the middle, where the
//      labels sit (the 4.5:1 contrast the frosted dock guarantees), clearing
//      over the outer few pixels of the band (to about a quarter at the rim)
//      so the bent edge shows as a clear lens ring.
//   4. Rim: a one-physical-pixel specular line lit from the top left, a
//      fainter one opposite, no halo; pressed glass (u_glow) is a little
//      brighter.

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;     // backdrop texture size (set by the engine)
uniform vec4 u_rect;     // glass rectangle in backdrop pixels: l, t, r, b
uniform float u_radius;  // corner radius, pixels
uniform float u_band;    // width of the refracting edge, pixels
uniform float u_bend;    // largest displacement at the edge, pixels
uniform float u_rim;     // rim light strength, 0..1
uniform float u_px;      // one logical pixel in backdrop pixels (dpr)
uniform vec4 u_tint;     // surface colour (straight rgb) and its opacity
uniform vec4 u_rect2;    // a second rectangle (== u_rect for one surface)
uniform float u_radius2; // its corner radius, pixels
uniform float u_blend;   // how far the two melt together, pixels (0: none)
uniform float u_glow;    // pressed: 0 at rest, about 1 under a finger
uniform float u_cover;   // 0: one clipped surface; > 0: frost radius, pixels

uniform sampler2D u_texture;

out vec4 frag_color;

vec4 backdrop(vec2 px, vec4 bounds) {
  // Stay inside the glass: the backdrop outside the clip may be cut out.
  // clamp() is undefined when its low bound passes its high one (a glass
  // thinner than a pixel), so the high bound never goes below the low.
  vec2 lo = bounds.xy + 0.5;
  vec2 hi = max(bounds.zw - 0.5, lo);
  vec2 p = clamp(px, lo, hi);
  // Never divide by a zero texture size, never read outside the texture.
  vec2 uv = clamp(p / max(u_size, vec2(1.0)), vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_texture, uv);
}

// The frost for the joined pair: the centre and six taps on a ring.
vec4 frost(vec2 p, vec4 bounds) {
  float r = clamp(u_cover, 0.0, 64.0);
  vec4 c = backdrop(p, bounds) * 0.25;
  c += backdrop(p + vec2(r, 0.0), bounds) * 0.125;
  c += backdrop(p + vec2(-r, 0.0), bounds) * 0.125;
  c += backdrop(p + vec2(0.5 * r, 0.866 * r), bounds) * 0.125;
  c += backdrop(p + vec2(-0.5 * r, 0.866 * r), bounds) * 0.125;
  c += backdrop(p + vec2(0.5 * r, -0.866 * r), bounds) * 0.125;
  c += backdrop(p + vec2(-0.5 * r, -0.866 * r), bounds) * 0.125;
  return c;
}

// Signed distance to a rounded rectangle (negative inside) and the outward
// normal of its nearest edge.
float box(vec2 frag, vec4 rect, float radius, out vec2 normal) {
  // A rectangle of no size (or turned inside out) is a point, not NaN.
  vec2 half_size = max((rect.zw - rect.xy) * 0.5, vec2(0.0));
  vec2 p = frag - (rect.xy + half_size);
  float r = clamp(radius, 0.0, min(half_size.x, half_size.y));
  vec2 q = abs(p) - half_size + r;
  vec2 s = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
  float outside = length(max(q, 0.0));
  if (q.x > 0.0 && q.y > 0.0) {
    normal = s * (q / max(outside, 0.0001));
  } else if (q.x > q.y) {
    normal = vec2(s.x, 0.0);
  } else {
    normal = vec2(0.0, s.y);
  }
  return outside + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec4 bounds = vec4(min(u_rect.xy, u_rect2.xy), max(u_rect.zw, u_rect2.zw));
  // Every length the glass is given is kept in a safe range: no division
  // by zero, no negative widths, no runaway reach (weak and software GPUs
  // may crash rather than return NaN).
  float band = max(u_band, 1.0);
  float reach = clamp(u_bend, 0.0, band);
  float blend = max(u_blend, 0.0);
  float rim = clamp(u_rim, 0.0, 1.0);
  float glow = clamp(u_glow, 0.0, 1.0);
  float px_size = max(u_px, 1.0);
  vec4 tint = clamp(u_tint, vec4(0.0), vec4(1.0));

  vec2 n1;
  vec2 n2;
  float d1 = box(frag, u_rect, u_radius, n1);
  float d2 = box(frag, u_rect2, u_radius2, n2);
  float dist;
  vec2 normal;
  if (blend > 0.0) {
    // A smooth union: the two shapes melt into one where they are closer
    // than u_blend, like two drops touching.
    float h = clamp(0.5 + 0.5 * (d2 - d1) / blend, 0.0, 1.0);
    dist = mix(d2, d1, h) - blend * h * (1.0 - h);
    vec2 n = mix(n2, n1, h);
    normal = n / max(length(n), 0.0001);
  } else if (d1 <= d2) {
    dist = d1;
    normal = n1;
  } else {
    dist = d2;
    normal = n2;
  }

  float cover = 1.0;
  if (u_cover > 0.0) {
    cover = clamp(0.5 - dist, 0.0, 1.0);
    if (cover <= 0.0) {
      // Outside the shapes nothing is drawn: the backdrop shows through
      // untouched (the filter is laid over it), never a copy of it that
      // could differ, a dark rectangle round the pair (emulator QA 61/62).
      frag_color = vec4(0.0);
      return;
    }
  }

  float depth = max(-dist, 0.0);
  float edge = clamp(1.0 - depth / band, 0.0, 1.0);
  float bend = reach * edge * edge;

  vec4 color;
  float red;
  if (u_cover > 0.0) {
    color = frost(frag - normal * bend, bounds);
    red = backdrop(frag - normal * bend * 1.35, bounds).r;
  } else {
    color = backdrop(frag - normal * bend, bounds);
    // Dispersion: red from a little further in, only where the lens bends.
    red = backdrop(frag - normal * bend * 1.35, bounds).r;
  }
  color.r = mix(color.r, red, edge * 0.6);

  // The tint is full over the middle, where labels sit (their 4.5:1), and
  // clears towards the rim over the outer few pixels only, so the bent
  // backdrop shows there: a clear lens ring, not a white or grey blob.
  color.rgb = mix(color.rgb, tint.rgb, tint.a * (1.0 - 0.72 * edge * edge * edge));
  color.rgb = mix(color.rgb, vec3(1.0), 0.07 * glow);
  // A faint sheen lit from above over the top half, fading to nothing by
  // the middle: the body of the glass (the canvas's GlassWork), not a glow.
  float rise = clamp((frag.y - bounds.y) / max(bounds.w - bounds.y, 1.0), 0.0, 1.0);
  color.rgb = mix(color.rgb, vec3(1.0), 0.05 * rim * max(1.0 - 2.0 * rise, 0.0));

  // Specular rim: a line one physical pixel wide where the edge faces the
  // light, softer where it faces away. No halo and no glow across the band
  // (visual language §7: a crisp line, never a soft blur of light).
  vec2 light = vec2(-0.6, -0.8);
  float facing = clamp(dot(normal, light), -1.0, 1.0);
  float line = 1.0 - smoothstep(0.0, 1.0, depth);
  // Squares and cubes by multiplication: pow() of 0 is undefined on some
  // GPUs (exp2(y * log2(0))).
  float lit = max(facing, 0.0);
  float away = max(-facing, 0.0);
  float spec = line * (0.28 + 0.62 * lit * lit + 0.3 * away * away * away);
  spec *= 1.0 + 0.6 * glow;
  // Pressed glass: its outermost logical pixel brightens, hard-edged.
  spec += 0.15 * glow * (1.0 - step(px_size, depth));
  color.rgb = mix(color.rgb, vec3(1.0), clamp(spec * rim, 0.0, 1.0));
  // Whatever came in, what goes out is a colour.
  color = clamp(color, vec4(0.0), vec4(1.0));
  color.a = 1.0;
  // The joined pair's own anti-aliased edge: premultiplied, laid over the
  // backdrop, so the edge pixel mixes with what is really there.
  frag_color = color * cover;
}
