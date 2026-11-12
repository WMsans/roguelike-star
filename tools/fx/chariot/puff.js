// One puff of an emitter's trail: a cluster of flame tongues, or the same cluster in smoke greys, born within a
// cell of the origin and drifting out and up as it dies. Baked twice (see tools/fx/bake.mjs) and dropped into
// the world by ChProjectile and the Flamethrower, so a stream of them reads as a plume while no single sheet
// carries the whole plume inside its frames.
// The tongue and smoke recipes are adapted from Sprite Fusion's open-source fire
// (https://www.spritefusion.com/pixel-art-vfx/fire), MIT License, Copyright (c) 2026 Hugo Duprez.
import { fit, hex, rng } from "../../core/index.js";
import { firePuff, flameTongue, noiseFor, smokePuff } from "../fire/_lib.js";

export const meta = {
  name: "Puff",
  desc: "One small puff of an emitter's trail: a cluster of flame tongues cooling through the fire palette, or the same cluster in smoke greys.",
  tags: ["puff", "trail", "smoke", "fire", "one-shot", "chariot"],
  size: [24, 24],
  origin: [12, 12],
  duration: 0.4,
  loop: false,
  fps: 30,
  bg: "sky",
  options: {
    kind: "fire",
    seed: 4,
    palette: ["#4a1712", "#c9281f", "#f2561d", "#ff8a2a", "#ffc23d", "#ffe26b", "#fff3a6", "#ffffff"],
  },
};

const LUMPS = 7;
const STAGGER = 0.02; // seconds between births: the last is born at 0.12, so all seven overlap
const NZ = noiseFor(0); // one-shots: plain noise, no loop to match

export function draw(p, t, o) {
  const H = fit(o.palette, 8), S = o.seed, LIFE = meta.duration, smoke = o.kind === "smoke";
  const COL = hex(o.palette[5]);
  // flameTongue's noise asks (rate, seed, off); the time is the frame's, so the tongues waver
  const N = (rate, seed = 0, off = 0) => NZ(t, rate, seed, off);
  for (let i = 0; i < LUMPS; i++) {
    const r = rng(S, i);
    // one generator per lump, asked in this order every frame, so a bake is the same every run
    const a = r.range(0, Math.PI * 2);
    const out = smoke ? r.range(10, 18) : r.range(5, 12), rise = smoke ? r.range(6, 14) : r.range(10, 20);
    const s0 = smoke ? r.range(2.4, 3.6) : r.range(2.6, 4.4), lean = r.range(-0.6, 0.6);
    const age = t - i * STAGGER;
    if (age <= 0 || age >= LIFE) continue;
    const k = 1 - age / LIFE; // life left
    const x = Math.cos(a) * out * age, y = Math.sin(a) * out * 0.4 * age - rise * age;
    // grows out of nothing, then burns down to nothing: the puff swells before it fades
    const grow = Math.min(1, age * 6) * Math.min(1, k * 3);
    const size = s0 * (0.75 + 0.45 * (age / LIFE)) * (0.6 + 0.4 * grow);
    if (smoke) smokePuff(p, x, y, k, size, COL, false, 0.4);
    else {
      // a hot lump with a tongue off its top: the lump is the mass, the tongue is what reads as flame
      firePuff(p, x, y, k, size, 0.5, H, 0.08);
      if (i % 2 === 0) flameTongue(p, x, y + size * 0.7, size * 0.9 * grow, 1.5, lean, N, i, H, undefined, 0.35, 0.7);
    }
  }
}
