import { Particles, Lights, P, PF, Rng, fit, rand, clamp, smooth, TAU, WHITE, rgb } from "../../core/index.js";

export const meta = {
  name: "Fire nova",
  desc: "A ring of fire bursts out of a point: a white pop, then a front of licking flame races out to its reach, flinging sparks, leaving embers that rise and gutter out.",
  tags: ["fire", "nova", "ring", "aoe", "one-shot", "chariot"],
  size: [120, 128],
  origin: [60, 66],
  duration: 2.6,
  loop: false,
  fps: 30,
  bg: "sky",
  // reach: radius at the end of the push; grow: seconds it takes (the ring starts a tenth of the way out)
  options: { palette: ["#4a1712", "#8a1f17", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"], reach: 36, grow: 0.9, seed: 6 },
};

const WARM = rgb(255, 150, 70);

export function create(o) {
  const F = fit(o.palette, 9), RE = o.reach, G = o.grow, R = new Rng(o.seed);
  const ps = new Particles({ rng: R, sparks: [F[8], F[7], F[5], F[3]] }), lights = new Lights();
  let t = 0, acc = 0;
  const front = (tt) => RE * clamp(0.1 + (0.9 * tt) / G, 0, 1);
  // how hard the front burns: full while it pushes, guttering after
  const heat = (tt) => 1 - smooth(G, G + 0.45, tt);
  lights.add(0, 0, 30, WHITE, 0.7, 0.12);
  lights.add(0, 0, 50, WARM, 0.45, 0.5);
  // the pop: a puff of fat flame and a burst of sparks out of the centre
  for (let i = 0; i < 8; i++) {
    const a = R.range(0, TAU), sp = R.range(30, 80);
    ps.spawn(P.FIRE, 0, 0, Math.cos(a) * sp, Math.sin(a) * sp - 20, R.range(0.2, 0.35), 0, R.range(2.5, 4), 0, PF.SMOKES);
  }
  for (let i = 0; i < 16; i++) {
    const a = R.range(0, TAU), sp = R.range(160, 300);
    ps.spawn(P.SPARK, 0, 0, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.15, 0.3));
  }

  return {
    update(dt) {
      t += dt;
      const r = front(t), h = heat(t);
      // flame fed along the front: puffs born on the ring, licking outward and up, cooling as they rise
      acc += dt * r * 9 * h;
      while (acc >= 1) {
        acc -= 1;
        const a = R.range(0, TAU), d = r + R.range(-1.5, 1);
        ps.spawn(P.FIRE, Math.cos(a) * d, Math.sin(a) * d, Math.cos(a) * R.range(10, 35), Math.sin(a) * R.range(10, 35) - R.range(15, 40), R.range(0.2, 0.45), 0, R.range(1.5, 3.2), 0, R.chance(0.4) ? PF.SMOKES : 0);
        if (R.chance(0.12)) {
          const sp = R.range(90, 200);
          ps.spawn(P.SPARK, Math.cos(a) * r, Math.sin(a) * r, Math.cos(a) * sp, Math.sin(a) * sp - 40, R.range(0.15, 0.35));
        }
        if (R.chance(0.08)) ps.spawn(P.EMBER, Math.cos(a) * r, Math.sin(a) * r, Math.cos(a) * 20, -R.range(10, 40), R.range(0.5, 0.9), F[4]);
      }
      ps.update(dt);
      lights.update(dt);
    },
    draw(p) {
      const r = front(t), h = heat(t), fr = Math.floor(t * 30 + 1e-6);
      // the band it leaves behind: scattered embers on the swept ring, cooling inward and with time
      if (h > 0.02)
        for (let j = 0, m = Math.ceil(r * TAU * 0.9); j < m; j++) {
          const a = (j / m) * TAU, depth = rand(j, 17, o.seed) * 7, d = r - 1.5 - depth;
          if (d < 2 || rand(j, fr >> 2, 3) > 0.55) continue;
          const k = (1 - depth / 7) * h;
          p.dot(Math.cos(a) * d, Math.sin(a) * d, k > 0.6 ? F[5] : k > 0.35 ? F[3] : F[1], clamp(k * 1.4));
        }
      ps.draw(p, "back");
      ps.draw(p, "front");
      // the front: a ragged band of flame, its tongues clumped into licks that flicker and lean up as flame does
      if (h > 0.02) {
        const m = Math.ceil(r * TAU * 1.6), lick = Math.max(5, Math.round(r * 0.55));
        for (let j = 0; j < m; j++) {
          const a = (j / m) * TAU, ca = Math.cos(a), sa = Math.sin(a);
          // licks: a slow swell round the ring (whole cells per frame pair) times a fast per-tongue flicker
          const g = (j / m) * lick, gi = Math.floor(g), gf = g - gi;
          const swell = rand(gi, fr >> 1, o.seed) * (1 - gf) + rand((gi + 1) % lick, fr >> 1, o.seed) * gf;
          const L = (1 + 7 * swell * swell + 2.5 * rand(j, fr, 5)) * (0.35 + 0.65 * h) * (0.5 + 0.5 * Math.min(1, r / 16));
          let dx = ca, dy = sa - 0.9;
          const n = Math.hypot(dx, dy) || 1;
          dx /= n, dy /= n;
          // the band's root, a little inside the front, then the tongue
          const th = 1.5 + 1.5 * swell;
          for (let d = -th; d <= L; d += 0.5) {
            const u = d < 0 ? 0 : d / L;
            const c = d < -th * 0.55 ? F[3] : u < 0.2 ? (h > 0.55 ? F[8] : F[7]) : u < 0.45 ? F[7] : u < 0.7 ? F[5] : u < 0.9 ? F[4] : F[2];
            const x = d < 0 ? ca * (r + d) : ca * r + dx * d, y = d < 0 ? sa * (r + d) : sa * r + dy * d;
            p.px(x, y, c);
          }
        }
        p.glowRing(0, 0, r, 7, F[5], 0.4 * h);
      }
      // the hero frames: a white disc and a star at the origin
      if (t < 0.08) {
        const k = 1 - t / 0.08;
        p.circle(0, 0, 4 + 3 * (1 - k), F[6]);
        p.circle(0, 0, 2.5 + 2 * (1 - k), WHITE);
      }
      lights.draw(p);
    },
  };
}
