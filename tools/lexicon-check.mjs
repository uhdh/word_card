import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const src = fs.readFileSync(path.join(root, "godot", "lexicon.js"), "utf8").split("const FILTERS")[0];
const ctx = { console, Math, Object, Array, String, Number, Boolean };
vm.createContext(ctx);
vm.runInContext(src + "\nthis.previewStats = previewStats; this.styleFor = styleFor;", ctx);

assert.ok(Math.abs(ctx.previewStats("가", {}).dps - 12.5) < 0.05);
const needle = ctx.previewStats("바늘", { name:"바늘", desc:"급소", category:"weapon" });
assert.equal(needle.trait, "sniper");
assert.ok(Math.abs(needle.dps - 45.4) < 0.15);
const base = JSON.parse(fs.readFileSync(path.join(root, "godot/assets/data/word_database_265.json"), "utf8"));
const extra = JSON.parse(fs.readFileSync(path.join(root, "godot/assets/data/word_database_expansion_100.json"), "utf8"));
const overlap = Object.keys(extra).filter((k) => base[k]).length;
const pig = (base["돼지"] || extra["돼지"]) ? 0 : 1;
assert.equal(Object.keys(base).length + Object.keys(extra).length - overlap + pig, 366);
console.log("ok", 366);
