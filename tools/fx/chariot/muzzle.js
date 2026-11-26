// The flash lobes come from the projectile helpers, adapted from Sprite Fusion's open-source muzzle-flash
// (https://www.spritefusion.com/pixel-art-vfx/muzzle-flash), MIT License, Copyright (c) 2026 Hugo Duprez.
import { Particles, Lights, P, Rng, fit, WHITE } from "../../core/index.js";
import { flashShape, flash } from "../projectiles/_lib.js";

export const meta = {
  name: "Launch flash",
  desc: "A launcher fires right: two frames of spiky white-cored flash, a kick of sparks forward and a puff of gunsmoke that rolls out and thins.",
  tags: ["muzzle", "flash", "projectile", "directional", "one-shot", "chariot"],
  size: [56, 40],
  origin: [10, 22],
  duration: 0.8,
  loop: false,
  fps: 30,
  bg: "sky",
  options: { palette: ["#4a1712", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"], size: 0.7, seed: 2 },
};

export function create(o) {
  const F = fit(o.palette, 8), R = new Rng(o.seed), S = o.size;
  const ps = new Particles({ rng: R, sparks: [F[7], F[6], F[4], F[2]] }), lights = new Lights();
  const L1 = flashShape(new Rng(o.seed + 11), 1, { size: S }), L2 = flashShape(new Rng(o.seed + 11), 2, { size: S });
  lights.add(4, 0, 26, F[4], 0.55, 0.16);
  lights.add(1, 0, 9, WHITE, 0.6, 0.06);
  for (let i = 0; i < 7; i++) {
    const a = R.range(-0.45, 0.45), sp = R.range(140, 280);
    ps.spawn(P.SPARK, 2, 0, Math.cos(a) * sp, Math.sin(a) * sp - 20, R.range(0.1, 0.25));
  }
  for (let i = 0; i < 5; i++)
    ps.spawn(P.SMOKE, R.range(1, 6), R.range(-1, 1), R.range(25, 80), R.range(-12, 6), R.range(0.45, 0.7), 0, R.range(2, 3.5), R.range(0, 0.06));
  let t = 0;
  return {
    update(dt) {
      t += dt;
      ps.update(dt);
      lights.update(dt);
    },
    draw(p) {
      ps.draw(p, "back");
      if (t < 1 / 30) flash(p, 0, 0, 0, L1, [WHITE, F[6], F[4], F[2]], o.seed);
      else if (t < 2 / 30) flash(p, 0, 0, 0, L2, [F[6], F[5], F[3], F[1]], o.seed);
      ps.draw(p, "front");
      lights.draw(p);
    },
  };
}
