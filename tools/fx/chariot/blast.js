// The fireball, spark and smoke recipe is adapted from Sprite Fusion's open-source explosion
// (https://www.spritefusion.com/pixel-art-vfx/explosion), MIT License, Copyright (c) 2026 Hugo Duprez.
import { Particles, Bits, Lights, P, PF, B, Rng, fit, TAU, WHITE, rgb, sparkle } from "../../core/index.js";

export const meta = {
  name: "Chariot blast",
  desc: "A compact mid-air blast for a shell bursting on a hull: a white hero frame, a fireball that cools into a smoke puff, a snapping shock ring, a sphere of sparks and hot scrap that falls away.",
  tags: ["explosion", "fire", "impact", "one-shot", "chariot"],
  size: [128, 120],
  origin: [64, 68],
  duration: 2.0,
  loop: false,
  fps: 30,
  bg: "sky",
  options: { palette: ["#4a1712", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"], size: 1, seed: 7 },
};

const SMOKE_LIGHT = rgb(150, 142, 150), WARM = rgb(255, 176, 96), SCRAP = ["#15121c", "#2c2834", "#4a4452", "#77707e", "#b0a8b4"];

export function create(o) {
  const F = fit(o.palette, 8), S = o.size, RAD = 9 * S, POWER = Math.pow(S, 0.8);
  const R = new Rng(o.seed);
  const ps = new Particles({ rng: R, sparks: [F[7], F[6], F[4], F[2]] });
  const scrap = new Bits(), lights = new Lights();
  let t = 0;

  lights.add(0, 0, RAD * 4, WARM, 0.55 * POWER, 0.6);
  lights.add(0, 0, RAD * 1.8, WHITE, 0.7, 0.09);
  // the core of the ball: fat flames that hang a beat, then the shell flung out and cooling to smoke
  for (let i = 0; i < 9; i++) {
    const a = R.range(0, TAU), d = R.range(0, RAD * 0.45);
    ps.spawn(P.FIRE, Math.cos(a) * d, Math.sin(a) * d, Math.cos(a) * 25, Math.sin(a) * 20 - 15, R.range(0.22, 0.38), 0, R.range(RAD * 0.55, RAD * 0.8), 0, R.chance(0.3) ? PF.SMOKES : 0);
  }
  for (let i = 0; i < Math.round(14 * POWER); i++) {
    const a = R.range(0, TAU), d = R.range(0, RAD * 0.5), sp = R.range(30, 100) * POWER;
    ps.spawn(P.FIRE, Math.cos(a) * d, Math.sin(a) * d, Math.cos(a) * sp, Math.sin(a) * sp * 0.85 - 25, R.range(0.3, 0.6), 0, R.range(RAD * 0.35, RAD * 0.6), R.range(0, 0.04), R.chance(0.4) ? PF.SMOKES : 0);
  }

  // a short smoke puff that rolls up out of the ball once it cools
  for (let i = 0; i < Math.round(5 * POWER); i++) {
    const a = R.range(0, TAU), d = R.range(0, RAD * 0.7), sp = R.range(10, 60);
    ps.spawn(P.SMOKE, Math.cos(a) * d, Math.sin(a) * d, Math.cos(a) * sp, Math.sin(a) * sp * 0.5 - 30, R.range(0.6, 1.0), SMOKE_LIGHT, R.range(RAD * 0.3, RAD * 0.5), R.range(0.12, 0.3), PF.BIG);
  }
  // a sphere of sparks, faster than the fire, falling as they slow
  for (let i = 0; i < Math.round(36 * POWER); i++) {
    const a = R.range(0, TAU), sp = R.range(150, 360) * POWER;
    ps.spawn(P.SPARK, 0, 0, Math.cos(a) * sp, Math.sin(a) * sp - 60, R.range(0.15, 0.5));
  }
  for (let i = 0; i < Math.round(14 * POWER); i++) {
    const a = R.range(0, TAU), sp = R.range(30, 120);
    ps.spawn(P.EMBER, Math.cos(a) * RAD * 0.4, Math.sin(a) * RAD * 0.4, Math.cos(a) * sp, Math.sin(a) * sp - 50, R.range(0.6, 1.2), F[3]);
  }
  // hot scrap off the hull: tumbling chunks thrown up and out, falling out of the frame
  for (let i = 0; i < Math.round(7 * POWER); i++) {
    const a = -Math.PI / 2 + R.range(-1.4, 1.4), sp = R.range(110, 230);
    scrap.add({ kind: B.CHUNK, x: 0, y: 0, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, g: 0.9, drag: 0.6, life: R.range(0.7, 1.1), a: R.range(0, TAU), va: R.range(-18, 18), s: R.int(1, 2), ramp: SCRAP });
  }

  return {
    update(dt) {
      t += dt;
      scrap.update(dt);
      ps.update(dt);
      lights.update(dt);
    },
    draw(p) {
      scrap.draw(p);
      ps.draw(p, "back");
      ps.draw(p, "front");
      // the hero frames: two of solid white-hot ball, then it falls away into the flames
      if (t < 0.07) {
        const k = 1 - t / 0.07, r = RAD * (1.05 + 0.25 * (1 - k));
        p.circle(0, 0, r + 1.3, F[3]);
        p.circle(0, 0, r, k > 0.4 ? F[7] : F[6]);
        p.circle(0, 0, r * 0.62, WHITE);
      }
      // the shock ring: snaps out past the ball and thins to nothing
      const k = t / 0.28;
      if (k < 1) {
        const e = 1 - Math.pow(1 - k, 3);
        p.ring(0, 0, RAD * (0.6 + 2.3 * e), Math.max(1, 2.6 * (1 - k)), k < 0.4 ? F[7] : F[5], Math.min(1, (1 - k) * 1.8));
      }
      if (t < 0.12) sparkle(p, 0, 0, RAD * 1.6 * (1 - t / 0.12), F[6], F[4], 0.5);
      lights.draw(p);
    },
  };
}
