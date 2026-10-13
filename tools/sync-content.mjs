// Copies what the iOS app bundles from the Android checkout (which is generated from the site by
// its own tools/sync-content.mjs). Run from tools/ after the Android repo is synced:
//
//   node sync-content.mjs            (Android repo at ../../pisacoma-android or $ANDROID)
//
// Output (all generated, never edited by hand):
//   Pisacoma/Content/      ← app/src/main/assets (home, covers, indices, licenses, manifest.json)
//   Pisacoma/Fonts/        ← app/src/main/res/font/*.ttf (the variable fonts, no _ext subsets)
//   PisacomaTests/Content/ ← content/ (the downloadable files, so the model tests read real data)
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const ANDROID = resolve(process.env.ANDROID ?? join(here, "../../pisacoma-android"));
const APP = resolve(here, "../Pisacoma/Content");
const FONTS = resolve(here, "../Pisacoma/Fonts");
const TESTS = resolve(here, "../PisacomaTests/Content");

if (!existsSync(join(ANDROID, "app/src/main/assets/manifest.json"))) {
  console.error(`Android repo not found at ${ANDROID} (set ANDROID=...)`);
  process.exit(1);
}

function dirSize(dir) {
  return readdirSync(dir).reduce((n, f) => {
    const p = join(dir, f);
    return n + (statSync(p).isDirectory() ? dirSize(p) : statSync(p).size);
  }, 0);
}

for (const [src, dest] of [
  [join(ANDROID, "app/src/main/assets"), APP],
  [join(ANDROID, "content"), TESTS],
]) {
  rmSync(dest, { recursive: true, force: true });
  mkdirSync(dirname(dest), { recursive: true });
  cpSync(src, dest, { recursive: true });
  console.log(`${(dirSize(dest) / 1024 / 1024).toFixed(1)} MB → ${dest}`);
}

rmSync(FONTS, { recursive: true, force: true });
mkdirSync(FONTS, { recursive: true });
for (const f of ["fraunces", "fraunces_italic", "inter", "dm_sans", "playfair"]) {
  cpSync(join(ANDROID, `app/src/main/res/font/${f}.ttf`), join(FONTS, `${f}.ttf`));
}
console.log(`${readdirSync(FONTS).length} fonts → ${FONTS}`);
