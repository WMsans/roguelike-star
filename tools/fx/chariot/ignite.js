import { Particles, Lights, P, PF, Rng, fit, TAU, WHITE, rgb } from "../../core/index.js";

export const meta = {
  name: "Ignite",
  desc: "A part catches fire: an orange pop, a whoosh of flame licks up off it and rolls into smoke, sparks and embers float away.",
  tags: ["fire", "burn", "status", "one-shot", "chariot"],
  size: [60, 96],
  origin: [30, 70],
  duration: 2.0,
  loop: false,
  fps: 30,
  bg: "sky",
  options: { palette: ["#4a1712", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"], seed: 3 },
};

export function create(o) {
  const F = fit(o.palette, 8), R = new Rng(o.seed);
  const ps = new Particles({ rng: R, sparks: [F[7], F[6], F[4], F[2]] }), lights = new Lights();
  lights.add(0, -4, 30, rgb(255, 150, 70), 0.55, 0.7);
  lights.add(0, 0, 12, WHITE, 0.5, 0.08);
  // the whoosh: a column of flame balls shoved up, the late ones smaller and higher
  for (let i = 0; i < 12; i++) {
    const d = R.range(0, 0.18);
    ps.spawn(P.FIRE, R.range(-4, 4), R.range(-2, 2), R.range(-14, 14), -R.range(50, 120), R.range(0.3, 0.55), 0, R.range(2.4, 4.4) * (1 - d * 2), d, R.chance(0.5) ? PF.SMOKES : 0);
  }
  for (let i = 0; i < 3; i++) ps.spawn(P.SMOKE, R.range(-3, 3), -R.range(6, 12), R.range(-8, 8), -R.range(25, 45), R.range(0.6, 0.9), 0, R.range(3, 4.5), R.range(0.2, 0.35));
  for (let i = 0; i < 9; i++) {
    const a = -Math.PI / 2 + R.range(-1.1, 1.1), sp = R.range(80, 190);
    ps.spawn(P.SPARK, 0, 0, Math.cos(a) * sp, Math.sin(a) * sp, R.range(0.15, 0.4));
  }
  for (let i = 0; i < 7; i++) ps.spawn(P.EMBER, R.range(-5, 5), R.range(-6, 0), R.range(-20, 20), -R.range(20, 50), R.range(0.6, 1.1), F[3]);
  let t = 0;
  return {
    update(dt) {
      t += dt;
      ps.update(dt);
      lights.update(dt);
    },
    draw(p) {
      ps.draw(p, "back");
      ps.draw(p, "front");
      if (t < 0.06) {
        p.circle(0, 0, 4.5, F[5]);
        p.circle(0, 0, 3, WHITE);
      }
      const k = t / 0.2;
      if (k < 1) p.ring(0, 0, 3 + 10 * (1 - Math.pow(1 - k, 3)), 1, k < 0.4 ? F[6] : F[4], 1 - k);
      lights.draw(p);
      void TAU;
    },
  };
}
