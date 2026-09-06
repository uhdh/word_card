import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const read = path => readFileSync(path, 'utf8');

test('web and Godot expose the new lore and recipe-book entry points', () => {
  const html = read('index.html');
  const webApp = read('src/js/app.js');
  const godotScene = read('godot/scenes/TowerDefenseMain.tscn');
  const godotMain = read('godot/scripts/ui/TowerDefenseMain.gd');

  assert.match(html, /btn-lore/);
  assert.match(webApp, /openLoreModal/);
  assert.match(webApp, /자모 합성 규칙/);
  assert.match(godotScene, /BtnLore/);
  assert.match(godotMain, /_on_lore_pressed/);
  assert.match(read('godot/scripts/ui/LexiconModal.gd'), /자모 합성 규칙/);
});

test('both runtimes ship the sanctuary map and all 265 word symbols', () => {
  assert.ok(existsSync('public/assets/map/map_grand_sanctuary_1024x352.png'));
  assert.ok(existsSync('godot/assets/map/map_grand_sanctuary_1024x352.png'));

  const webDb = read('src/js/core/wordDatabase.js');
  const godotDb = JSON.parse(read('godot/assets/data/word_database_265.json'));
  assert.equal((webDb.match(/^  "[^"]+": \{$/gm) || []).length, 265);
  assert.equal(Object.keys(godotDb).length, 265);
  assert.match(webDb, /words_symbol_32px/);
  assert.match(read('godot/scripts/core/WordDatabase.gd'), /word_database_265\.json/);
  for (const word of Object.values(godotDb)) {
    const file = word.icon.replace('./assets/', '');
    assert.ok(existsSync(`public/assets/${file}`), `missing web icon: ${file}`);
    assert.ok(existsSync(`godot/assets/${file}`), `missing Godot icon: ${file}`);
  }
});

test('safe Godot launcher bypasses the broken NVIDIA overlay path', () => {
  const launcher = read('run-godot-safe.cmd');
  const project = read('godot/project.godot');
  assert.match(launcher, /VK_LOADER_LAYERS_DISABLE=\*/);
  assert.match(launcher, /--rendering-driver d3d12 --gpu-index 1/);
  assert.match(launcher, /--path "%~dp0godot"/);
  assert.match(project, /\[editor\][\s\S]*run\/main_run_args="--rendering-driver d3d12 --gpu-index 1"/);
});

test('Godot sanctuary uses one responsive map instead of repeated fixed tiles', () => {
  const fieldScene = read('godot/scenes/tower/DefenseField.tscn');
  const fieldScript = read('godot/scripts/tower/DefenseField.gd');
  assert.match(fieldScene, /texture_repeat = 0/);
  assert.match(fieldScene, /stretch_mode = 0/);
  assert.match(fieldScript, /_layout_sanctuary/);
  assert.match(fieldScript, /size\.x \/ 1024\.0/);
  assert.match(fieldScript, /size\.y \/ 352\.0/);
});

test('Godot tower HUD lays info and actions out in one row', () => {
  const scene = read('godot/scenes/TowerDefenseMain.tscn');
  const script = read('godot/scripts/ui/TowerDefenseMain.gd');
  assert.match(scene, /node name="Row" type="HBoxContainer" parent="TopBar"/);
  assert.match(scene, /node name="Info" type="HBoxContainer" parent="TopBar\/Row"/);
  assert.match(scene, /node name="Actions" type="HBoxContainer" parent="TopBar\/Row"/);
  assert.match(scene, /custom_minimum_size = Vector2\(110, 36\)/);
  assert.match(scene, /text = "▶ 웨이브"/);
  assert.match(script, /\$TopBar\/Row\/Info/);
});

test('magic circle appears only for the first crafted tower', () => {
  const fieldScene = read('godot/scenes/tower/DefenseField.tscn');
  const fieldScript = read('godot/scripts/tower/DefenseField.gd');
  const towerScript = read('godot/scripts/tower/WordTower.gd');
  assert.match(fieldScene, /map_grand_sanctuary_clean_1024x352\.png/);
  assert.match(fieldScript, /first_magic_circle_pending/);
  assert.match(towerScript, /show_magic_circle/);
  assert.match(towerScript, /magic_circle_time_left/);
});
