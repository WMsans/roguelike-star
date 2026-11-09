import { Particles, Bits, Lights, P, B, Rng, fit, flare, TAU, WHITE } from "../../core/index.js";

export const meta = {
  name: "Ice shatter",
  desc: "A frozen part is smashed: a white star flares, the ice bursts into tumbling shards and glittering chips that fall away in a puff of cold dust.",
  tags: ["ice", "shatter", "impact", "one-shot", "chariot"],
  size: [128, 112],
  origin: [64, 48],
  duration: 1.2,
  loop: false,
  fps: 30,
  bg: "sky",
  // aim: the angle the blow came in along; the burst kicks that way
  options: { palette: ["#151a3d", "#212f6b", "#2c58aa", "#3a8bd8", "#62c8f4", "#a6ecff", "#dcfbff", "#ffffff"], aim: 0, seed: 6 },
};

export function create(o) {
  const C = fit(o.palette, 8), R = new Rng(o.seed), A = o.aim;
  const ps = new Particles({ rng: R, sparks: [WHITE, C[6], C[5], C[3]], haze: C[4] });
  const bits = new Bits(), lights = new Lights();
  const ICE = [C[1], C[3], C[4], C[5], C[7]].map((c) => "#" + [c & 255, (c >>> 8) & 255, (c >>> 16) & 255].map((v) => v.toString(16).padStart(2, "0")).join(""));
  lights.add(0, 0, 40, C[5], 0.6, 0.5);
  lights.add(0, 0, 16, WHITE, 0.8, 0.1);
  // big chunks: shaded, tumbling, thrown along the blow and up, falling away
  for (let i = 0; i < 7; i++) {
    const a = A + R.range(-1.4, 1.4) - 0.4, sp = R.range(60, 150);
    bits.add({ kind: B.CHUNK, x: R.range(-2, 2), y: R.range(-2, 2), vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 60, g: 0.8, drag: 0.8, life: R.range(0.7, 1.0), a: R.range(0, TAU), va: R.range(-14, 14), s: R.range(2.4, 3.4), ramp: ICE });
  }
  // thin glassy shards all round
  for (let i = 0; i < 14; i++) {
    const a = R.range(0, TAU), sp = R.range(100, 260);
    bits.add({ kind: B.SHARD, x: 0, y: 0, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 50, g: 0.7, drag: 1.4, life: R.range(0.4, 0.8), a: R.range(0, TAU), va: R.range(-25, 25), s: R.range(2, 4), c: ICE[3] });
  }
  for (let i = 0; i < 16; i++) {
    const a = R.range(0, TAU), sp = R.range(140, 300);
    ps.spawn(P.SPARK, 0, 0, Math.cos(a) * sp, Math.sin(a) * sp - 30, R.range(0.12, 0.3));
  }
  for (let i = 0; i < 8; i++) ps.spawn(P.STAR, R.range(-10, 10), R.range(-10, 6), R.range(-20, 20), R.range(-20, 10), R.range(0.3, 0.7), WHITE, R.range(0.6, 2.2), R.range(0.08, 0.35));
  for (let i = 0; i < 5; i++) {
    const a = R.range(0, TAU);
    ps.spawn(P.VAPOUR, Math.cos(a) * 3, Math.sin(a) * 3, Math.cos(a) * 25, Math.sin(a) * 15 + 8, R.range(0.6, 0.9), C[5], R.range(3, 6), R.range(0.02, 0.1));
  }
  let t = 0;
  return {
    update(dt) {
      t += dt;
      bits.update(dt);
      ps.update(dt);
      lights.update(dt);
    },
    draw(p) {
      ps.draw(p, "back");
      bits.draw(p);
      ps.draw(p, "front");
      if (t < 0.05) {
        p.circle(0, 0, 6, C[6]);
        p.circle(0, 0, 4, WHITE);
      }
      if (t < 0.16) flare(p, 0, 0, 16 * (1 - t / 0.16) + 2, 0.6, [C[2], C[4], C[5], C[6]]);
      const k = t / 0.25;
      if (k < 1) p.ring(0, 0, 5 + 16 * (1 - Math.pow(1 - k, 3)), Math.max(1, 2 * (1 - k)), k < 0.4 ? WHITE : C[5], Math.min(1, (1 - k) * 1.8));
      lights.draw(p);
    },
  };
}
