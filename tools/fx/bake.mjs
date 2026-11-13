// Bakes the battle's pixel VFX into sprite sheets under textures/fx/, plus the one manifest ChFx reads.
// The effects are pixelfx effects (https://github.com/patch-gg/pixelfx): the library's own, and the compact
// mid-air ones in tools/fx/chariot/, copied into the checkout's src/fx/chariot/ before rendering.
//   git clone https://github.com/patch-gg/pixelfx <dir>
//   node tools/fx/bake.mjs <dir>
// Then reimport in Godot (opening the editor, or godot --headless --import).
import { execFileSync } from "node:child_process";
import { cpSync, mkdirSync, readFileSync, writeFileSync, copyFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "../..");
const pixelfx = resolve(process.argv[2] ?? "");
const out = join(repo, "textures/fx");
const tmp = join(pixelfx, "records/_bake");

// Glow strength baked into the sheets: the arena is a bright daytime scene, so full glow washes the colours out.
const LIGHT = 0.6;

// name -> [pixelfx id, options]. Directional effects face right; ChFx turns them to the part's facing.
const FX = {
  blast: ["chariot/blast", {}],
  fire_blast: ["chariot/blast", { size: 1.4, seed: 3 }],
  fire_nova: ["chariot/fire-nova", { reach: 36 }],
  flamethrower: ["chariot/flamethrower", { reach: 40 }],
  spark_hit: ["chariot/spark-hit", {}],
  blunt_hit: ["impacts/blunt-hit", { height: 0 }],
  frost: ["chariot/frost", {}],
  shatter: ["chariot/shatter", {}],
  ignite: ["chariot/ignite", {}],
  muzzle: ["chariot/muzzle", {}],
  puff_fire: ["chariot/puff", {}],
  puff_smoke: [
    "chariot/puff",
    {
      kind: "smoke",
      palette: ["#1a171c", "#26222e", "#3d3846", "#5a5463", "#7e7887", "#a7a1ad", "#d0cad2", "#f1ecee"],
    },
  ],
};

const cats = join(pixelfx, "src/fx/categories.js");
const catSrc = readFileSync(cats, "utf8");
if (!catSrc.includes('id: "chariot"'))
  writeFileSync(cats, catSrc.replace(/\n\];/, '\n  { id: "chariot", name: "chariot", blurb: "compact mid-air hits for the chariot battler" },\n];'));
mkdirSync(join(pixelfx, "src/fx/chariot"), { recursive: true });
for (const f of readdirSync(join(here, "chariot"))) cpSync(join(here, "chariot", f), join(pixelfx, "src/fx/chariot", f));

mkdirSync(out, { recursive: true });
const manifest = {};
for (const [name, [id, opts]] of Object.entries(FX)) {
  const dir = join(tmp, name);
  execFileSync("node", ["tools/render.mjs", id, "--sheet", "--opts", JSON.stringify({ light: LIGHT, ...opts }), "--out", dir], { cwd: pixelfx, stdio: "pipe" });
  const base = join(dir, id, id.split("/")[1]);
  const meta = JSON.parse(readFileSync(base + ".json", "utf8")).meta.pixelfx;
  copyFileSync(base + ".png", join(out, name + ".png"));
  manifest[name] = { fps: meta.fps, loop: meta.loop, frames: meta.frames, size: meta.frameSize, pivot: meta.pivot, columns: meta.columns };
  console.log(name.padEnd(14), id.padEnd(22), `${meta.frames}f`, meta.frameSize.join("x"));
}
writeFileSync(join(out, "fx.json"), JSON.stringify(manifest, null, 1) + "\n");
