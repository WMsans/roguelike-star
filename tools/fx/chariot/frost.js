import { Particles, Lights, P, Rng, fit, clamp, ease, rand, TAU, WHITE, sparkle } from "../../core/index.js";

export const meta = {
  name: "Frost lock",
  desc: "A part freezes solid: a cold white pop, a crown of faceted ice shards snaps out round it, glints, hangs with frost drifting off, then the shards thin and wink out.",
  tags: ["ice", "freeze", "status", "one-shot", "chariot"],
  size: [84, 84],
  origin: [42, 42],
  duration: 1.3,
  loop: false,
  fps: 30,
  bg: "sky",
  options: { palette: ["#151a3d", "#212f6b", "#2c58aa", "#3a8bd8", "#62c8f4", "#a6ecff", "#dcfbff", "#ffffff"], count: 8, seed: 8 },
};

// one shard: a long thin diamond pointing out along a, a lit edge on its upper side, a dark one under
function shard(p, a, r0, L, w, C, alpha, white) {
  const ca = Math.cos(a), sa = Math.sin(a), lit = sa < 0.2;
  for (let d = 0; d <= L; d += 0.5) {
    const u = d / L, hw = w * (u < 0.3 ? u / 0.3 : (1 - u) / 0.7);
    for (let e = -hw; e <= hw + 0.01; e += 0.5) {
      const x = ca * (r0 + d) - sa * e, y = sa * (r0 + d) + ca * e;
      const edge = Math.abs(e) > hw - 0.6, upper = e < 0 === lit;
      const c = white ? WHITE : edge ? (upper ? C[6] : C[2]) : u > 0.75 ? C[6] : upper ? C[5] : C[4];
      p.dot(x, y, c, alpha);
    }
  }
}

export function create(o) {
  const C = fit(o.palette, 8), R = new Rng(o.seed), N = o.count;
  const ps = new Particles({ rng: R, sparks: [WHITE, C[6], C[5], C[3]], haze: C[4] }), lights = new Lights();
  const shards = [];
  for (let i = 0; i < N; i++)
    shards.push({ a: (i / N) * TAU + R.range(-0.25, 0.25), L: R.range(6, 11), w: R.range(1.2, 2), d: R.range(0, 0.06), r0: R.range(1, 3), out: R.range(0.75, 1.05) });
  lights.add(0, 0, 34, C[5], 0.55, 0.5);
  lights.add(0, 0, 14, WHITE, 0.6, 0.1);
  for (let i = 0; i < 14; i++) {
    const a = R.range(0, TAU), sp = R.range(40, 110);
    ps.spawn(P.FLAKE, Math.cos(a) * 4, Math.sin(a) * 4, Math.cos(a) * sp, Math.sin(a) * sp - 10, R.range(0.6, 1.1), R.pick([C[6], C[5], WHITE]), R.range(1, 2));
  }
  for (let i = 0; i < 5; i++) {
    const a = R.range(0, TAU);
    ps.spawn(P.VAPOUR, Math.cos(a) * 5, Math.sin(a) * 5, Math.cos(a) * 15, Math.sin(a) * 10 + 6, R.range(0.6, 1), C[6], R.range(2, 3.5), R.range(0.05, 0.2));
  }
  let t = 0;
  return {
    update(dt) {
      t += dt;
      ps.update(dt);
      lights.update(dt);
    },
    draw(p) {
      ps.draw(p, "back");
      const fade = 1 - clamp((t - 0.75) / 0.5);
      for (const s of shards) {
        const k = clamp((t - s.d) / 0.12);
        if (k <= 0 || fade <= 0) continue;
        const g = ease.outBack ? ease.outBack(k) : ease.outCubic(k), L = s.L * g * s.out;
        // thinning out: the shard breaks up from its tip down with a dither
        shard(p, s.a, s.r0, L, s.w * (0.6 + 0.4 * fade), C, fade > 0.5 ? 1 : fade * 2, t - s.d < 0.05);
      }
      // a glint that runs round the crown, one shard at a time
      const gi = Math.floor((t - 0.2) / 0.09);
      if (t > 0.2 && gi < N && fade > 0.5) {
        const s = shards[gi], d = s.r0 + s.L * s.out * 0.8;
        sparkle(p, Math.cos(s.a) * d, Math.sin(s.a) * d, 3, WHITE, C[5], 0.4);
      }
      // the pop: a white disc and a cold ring snapping out
      if (t < 0.06) p.circle(0, 0, 5, WHITE);
      const k = t / 0.3;
      if (k < 1) p.ring(0, 0, 4 + 18 * ease.outCubic(k), Math.max(1, 2 * (1 - k)), k < 0.4 ? WHITE : C[5], Math.min(1, (1 - k) * 1.8));
      ps.draw(p, "front");
      p.glow(0, 0, 12, C[5], 0.25 * fade);
      lights.draw(p);
      void rand;
    },
  };
}
