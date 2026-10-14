const CHOSUNG = ["ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ","ㅁ","ㅂ","ㅃ","ㅅ","ㅆ","ㅇ","ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"];
const JUNGSUNG = ["ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅘ","ㅙ","ㅚ","ㅛ","ㅜ","ㅝ","ㅞ","ㅟ","ㅠ","ㅡ","ㅢ","ㅣ"];
const JONGSUNG = ["","ㄱ","ㄲ","ㄳ","ㄴ","ㄵ","ㄶ","ㄷ","ㄹ","ㄺ","ㄻ","ㄼ","ㄽ","ㄾ","ㄿ","ㅀ","ㅁ","ㅂ","ㅄ","ㅅ","ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ"];
const CAT_LABELS = { weapon:"무기", element:"원소", nature:"자연", magic:"마법", summon:"생물", buff:"강화", defense:"방어", heal:"회복", skill:"기술" };
const TRAIT_NAMES = { balanced:"균형", sniper:"저격", damage_over_time:"지속 피해", splash:"폭발", rapid:"연사", pierce:"관통", control:"제어", chain:"연쇄", bounce:"3연속 바운스", orbit:"선회", meteor:"유성" };
const TRAIT_COLORS = { balanced:"#8de8ff", sniper:"#ff8a65", damage_over_time:"#ffb04a", splash:"#ff6b9d", rapid:"#ffe66d", pierce:"#d7dce5", control:"#72cfff", chain:"#c99cff", bounce:"#80e27e", orbit:"#7fe3d4", meteor:"#ff9a5c" };
const TIER_COLOR = { 1:"#80e6ff", 2:"#ffd94d", 3:"#ff66e6" };
const RULES = [
  { trait:"damage_over_time", label:"불꽃", keys:["불꽃","불길","화염","불타","태우","화상","작열","용암","홍염","불덩","뜨거","화산"] },
  { trait:"control", label:"혹한", keys:["얼음","빙결","동결","서리","눈보라","냉기","혹한","한파","설원","빙판"] },
  { trait:"chain", label:"번개", keys:["번개","벼락","천둥","전격","감전","뇌전","전류","뇌명"] },
  { trait:"rapid", label:"질풍", keys:["바람","질풍","회오리","돌풍","태풍","광풍","선풍","폭풍"] },
  { trait:"control", label:"급류", keys:["파도","해일","홍수","물결","급류","물보라","소용돌이","바닷"] },
  { trait:"splash", label:"대지", keys:["대지","지진","바위","암석","모래","흙더미","돌덩","산사태","낙석"] },
  { trait:"splash", label:"자연", keys:["가시","덩굴","뿌리","이끼","숲","풀잎","꽃잎","나뭇","씨앗","수액"] },
  { trait:"meteor", label:"심판", keys:["신성","정화","퇴마","성광","빛기둥","심판","축복","홀리"] },
  { trait:"damage_over_time", label:"저주", keys:["저주","어둠","암흑","독기","맹독","부패","저승","그림자","흑마"] },
  { trait:"sniper", label:"예리", keys:["검기","칼날","대검","장검","창끝","화살","예리","베어","참격","단검","비수","단도","석궁","저격","암살","급소"] },
  { trait:"pierce", label:"강타", keys:["강타","충격","분쇄","참격","내리치","때려","망치","철퇴","도끼","해머","몽둥이","방망이","곤봉"] },
  { trait:"control", label:"정지", keys:["시간","정지","멈춤","느려","지연","시계","속박"] },
  { trait:"chain", label:"공명", keys:["함성","포효","외침","고함","메아리","공명","울림","노래"] },
  { trait:"orbit", label:"지혜", keys:["성경","책장","글귀","지식","기록","두루마리","문장","학문","서책"] },
  { trait:"orbit", label:"야수", keys:["소환","불러","정령","사역","야수","짐승","새끼","사슴","오징어","매미","나비","거머리","너구리","고양이","여우","늑대","호랑이","사자","개구리","도마뱀","거북","독수리","까마귀","구렁이","악어","기러기","물개","두더지","오리","질주마"] },
  { trait:"rapid", label:"황금", keys:["황금","금화","보물","재물","동전","금괴"] },
  { trait:"control", label:"생명", keys:["회복","치유","소생","생명","약초","치료","봄바람","온기"] }
];
const EXACT = { "불":"damage_over_time", "얼":"control", "눈":"control", "빙":"control", "번":"chain", "뇌":"chain", "바":"rapid", "물":"control", "돌":"splash", "칼":"sniper", "검":"sniper", "활":"sniper", "책":"orbit", "성":"meteor", "금":"rapid", "봄":"control", "숲":"splash", "산":"splash", "강":"control" };
const CATEGORY_FALLBACK = { weapon:"sniper", element:"damage_over_time", nature:"splash", magic:"meteor", summon:"orbit", buff:"rapid", defense:"pierce", heal:"control", skill:"chain" };
const VOLLEY = [1, 2, 3];
const INTERVAL_MULT = [1.0, 0.85, 0.70];
const BASE_DAMAGE = [8.0, 9.5, 11.0];
const TRAIT_INTERVAL = { sniper:1.6, pierce:1.0, rapid:0.3, control:1.2, chain:0.9, splash:1.1, damage_over_time:0.8, meteor:2.2, orbit:0.9, bounce:0.8, balanced:0.8 };
const TRAIT_RANGE = { sniper:230, pierce:105, rapid:125, control:290, chain:185, splash:135, damage_over_time:150, meteor:175, orbit:76, bounce:150, balanced:150 };
const TRAIT_MULT = { sniper:2.6, splash:1.35, rapid:0.38, pierce:1.9, control:0.55, chain:0.85, orbit:0.6, meteor:1.5 };
const PIG = { word:"돼지", name:"돼지 (돌진/꿀꿀 박치기)", category:"summon", tier:2, cost:2, damage:30, desc:"돼지가 빠르게 돌진해 연속 박치기 피해를 줍니다.", icon:"res://assets/monsters/monster_boar_1_32px_pastel.png", sound:"play_attack" };

const TYPE_LABELS = { normal:"일반", fast:"질풍", armored:"중갑", swarm:"군집", boss:"보스" };
const TYPE_COLORS = { normal:"#9aa0c4", fast:"#f3991a", armored:"#94adc1", swarm:"#d973ad", boss:"#f25959" };
const ATTR_LABELS = { regen:"재생", splitter:"분열", swift:"질주" };
const ATTR_COLORS = { regen:"#33bf59", splitter:"#bf40b2", swift:"#f2991a", warded:"#4080f2" };
const MONSTERS = [
  { act:1, name:"낱자 슬라임", type:"normal", icon:"monster_slime_1_32px_pastel.png", attrs:[] },
  { act:1, name:"그늘 박쥐", type:"fast", icon:"monster_bat_1_32px_pastel.png", attrs:["swift"] },
  { act:1, name:"엄니 멧돼지", type:"armored", icon:"monster_boar_1_32px_pastel.png", attrs:[] },
  { act:1, name:"풀숲 고블린", type:"swarm", icon:"monster_goblin_1_32px_pastel.png", attrs:[] },
  { act:1, name:"되살아난 덩굴", type:"normal", icon:"monster_vine_1_32px_pastel.png", attrs:["regen"] },
  { act:1, name:"정원의 파수 골렘", type:"boss", icon:"monster_golem_boss_1_32px_pastel.png", attrs:[] },
  { act:2, name:"뼈 무덤지기", type:"armored", icon:"monster_skeleton_1_32px_pastel.png", attrs:[] },
  { act:2, name:"갱도 거미", type:"swarm", icon:"monster_spider_1_32px_pastel.png", attrs:["splitter"] },
  { act:2, name:"심연 늑대", type:"fast", icon:"monster_wolf_1_32px_pastel.png", attrs:["swift"] },
  { act:2, name:"광맥 망령", type:"normal", icon:"monster_spirit_1_32px_pastel.png", attrs:["warded:control"] },
  { act:2, name:"결정 슬라임", type:"normal", icon:"monster_slime_2_32px_pastel.png", attrs:["regen"] },
  { act:2, name:"갱도의 심장 골렘", type:"boss", icon:"monster_golem_boss_2_32px_pastel.png", attrs:[] },
  { act:3, name:"뇌운의 아룡", type:"fast", icon:"monster_dragon_1_32px_pastel.png", attrs:["swift"] },
  { act:3, name:"성광 정령", type:"normal", icon:"monster_spirit_2_32px_pastel.png", attrs:["warded:damage_over_time"] },
  { act:3, name:"창공 가시덩굴", type:"swarm", icon:"monster_vine_2_32px_pastel.png", attrs:["splitter"] },
  { act:3, name:"강철 멧돼지", type:"armored", icon:"monster_boar_2_32px_pastel.png", attrs:["regen"] },
  { act:3, name:"천공의 수문장", type:"boss", icon:"monster_golem_boss_2_32px_pastel.png", attrs:[] }
];
const RELICS = [
  { id:"relic_golden_dice", name:"황금 주사위", cost:25, desc:"보상 리롤 주사위 +2", icon:"relic_golden_dice_32px_pastel.png" },
  { id:"relic_essence_power", name:"활자의 정수", cost:35, desc:"모든 활자 타워 공격력 +20%", icon:"relic_essence_power_32px_pastel.png" },
  { id:"relic_fortress_rune", name:"철옹성 룬", cost:30, desc:"기지 최대 체력 +10, 즉시 10 회복", icon:"relic_fortress_rune_32px_pastel.png" },
  { id:"relic_haste_compass", name:"신속의 나침반", cost:35, desc:"모든 활자 타워 공격 속도 +20%", icon:"relic_haste_compass_32px_pastel.png" },
  { id:"relic_merchant_pouch", name:"상인의 보물주머니", cost:30, desc:"웨이브 클리어 골드 +50%", icon:"relic_merchant_pouch_32px_pastel.png" },
  { id:"relic_crit_lens", name:"예리한 렌즈", cost:35, desc:"공격 시 25% 확률로 2배 치명타", icon:"relic_crit_lens_32px_pastel.png" },
  { id:"relic_range_rune", name:"천리안의 룬", cost:30, desc:"모든 타워 공격 범위 +15%", icon:"relic_range_rune_32px_pastel.png" },
  { id:"relic_bounty_coin", name:"현상금 동전", cost:35, desc:"라운드 보너스 골드 +5", icon:"relic_bounty_coin_32px_pastel.png" },
  { id:"relic_healing_incense", name:"회복의 향로", cost:30, desc:"웨이브 종료 시 기지 HP 2 회복", icon:"relic_healing_incense_32px_pastel.png" },
  { id:"relic_first_strike", name:"선봉의 깃털", cost:35, desc:"각 타워의 첫 공격 피해 2배", icon:"relic_first_strike_32px_pastel.png" },
  { id:"relic_three_syllable_seal", name:"삼문자 인장", cost:40, desc:"3글자 타워 피해 +25%", icon:"relic_three_syllable_seal_32px_pastel.png" },
  { id:"relic_initial_compass", name:"훈민정음의 나침반", cost:35, desc:"세 슬롯 최적 조합을 한 번에 채점", icon:"relic_initial_compass_32px_pastel.png" },
  { id:"relic_tense_hammer", name:"된소리 망치", cost:35, desc:"된소리 초성 타워 피해 +25%", icon:"relic_tense_hammer_32px_pastel.png" },
  { id:"relic_final_weight", name:"종성의 무게추", cost:30, desc:"받침 있는 타워 피해 +20%", icon:"relic_final_weight_32px_pastel.png" },
  { id:"relic_open_feather", name:"민소리 깃털", cost:30, desc:"받침 없는 타워 공격속도 +18%", icon:"relic_open_feather_32px_pastel.png" },
  { id:"relic_cluster_anvil", name:"겹받침 모루", cost:40, desc:"겹받침 타워 피해 +35%", icon:"relic_cluster_anvil_32px_pastel.png" },
  { id:"relic_vowel_crystal", name:"겹모음 수정", cost:35, desc:"겹모음 타워 사거리 +20%", icon:"relic_vowel_crystal_32px_pastel.png" },
  { id:"relic_initial_drum", name:"첫소리 북", cost:40, desc:"모든 음절 초성이 같으면 피해 +25%", icon:"relic_initial_drum_32px_pastel.png" },
  { id:"relic_vowel_resonance", name:"모음 공명석", cost:35, desc:"같은 모음이 반복되면 공격속도 +20%", icon:"relic_vowel_resonance_32px_pastel.png" },
  { id:"relic_consonant_ring", name:"자음 고리", cost:40, desc:"받침과 다음 초성이 같으면 치명타 +20%", icon:"relic_consonant_ring_32px_pastel.png" },
  { id:"relic_balance_ink", name:"균형의 먹", cost:35, desc:"자음과 모음 수가 같으면 피해·사거리 +10%", icon:"relic_balance_ink_32px_pastel.png" },
  { id:"relic_open_chime", name:"무받침 풍경", cost:35, desc:"무받침 타워 연속 배치 시 양쪽 공격속도 +12%", icon:"relic_open_chime_32px_pastel.png" },
  { id:"relic_blast_charge", name:"폭발의 뇌관", cost:35, desc:"폭발 타워 피해 +25%, 함께 맞는 대상 +1", icon:"relic_gourd_32px_pastel.png" },
  { id:"relic_chain_loom", name:"연쇄의 베틀", cost:35, desc:"연쇄 타워 피해 +15%, 튀는 대상 +1", icon:"relic_bell_32px_pastel.png" },
  { id:"relic_orbit_gear", name:"선회의 톱니", cost:40, desc:"선회 타워의 궤도 오브 +1개", icon:"relic_crystal_32px_pastel.png" },
  { id:"relic_pierce_auger", name:"관통 송곳", cost:30, desc:"관통 타워 사거리 +10%, 꿰뚫는 대상 +1", icon:"relic_magnifier_32px_pastel.png" },
  { id:"relic_burn_oil", name:"발화 기름", cost:30, desc:"지속 피해 타워 화상 지속시간 +50%", icon:"relic_ink_stone_32px_pastel.png" }
];

const PROJECTILES = [
  { id:"bullet", name:"마법 비탄 (균형)", speed:350, icon:"proj_magic_32px_pastel.png", desc:"룬 마력탄. 균형(기본) 계열 타워가 발사하며 표준 속도(350 px/s)로 유도 비행합니다.", special:"균형 (표준 350 px/s)" },
  { id:"slash", name:"바람 참격 (연사)", speed:700, icon:"proj_slash_32px_pastel.png", desc:"초고속 풍인 검기. 연사(질풍) 특성 타워 발사체.", special:"연사 (초고속 700 px/s)" },
  { id:"fire", name:"폭발 화염구 (폭발)", speed:300, icon:"proj_fire_32px_pastel.png", desc:"묵직한 작열 폭발구. 폭발(대지/자연) 특성 타워 발사체.", special:"폭발 (광역 타격 300 px/s)" },
  { id:"dot", name:"맹독 침 (지속 피해)", speed:350, icon:"proj_dot_32px_pastel.png", desc:"불타는 독성 가시침. 지속 피해(불꽃/독) 특성 타워 발사체.", special:"지속 화상/독 피해" },
  { id:"arrow", name:"저격 화살 (저격)", speed:650, icon:"proj_arrow_32px_pastel.png", desc:"고정밀 강철 저격 화살. 저격(예리) 특성 타워 발사체.", special:"저격 (장거리 고속 650 px/s)" },
  { id:"pierce", name:"관통 투창 (관통)", speed:500, icon:"proj_pierce_32px_pastel.png", desc:"푸른빛 회전 투창. 관통(강타) 특성 타워 발사체.", special:"관통 (다수 타격 500 px/s)" },
  { id:"ice", name:"혹한 고드름 (제어)", speed:350, icon:"proj_ice_32px_pastel.png", desc:"빙결 서리 결정. 제어(혹한/급류/정지) 특성 타워 발사체.", special:"둔화 50% (2.5초)" },
  { id:"lightning", name:"뇌전 탄환 (연쇄)", speed:600, icon:"proj_lightning_32px_pastel.png", desc:"전광석화 뇌전 구체. 연쇄(번개/공명) 특성 타워 발사체.", special:"연쇄 (최고 탄속 600 px/s)" },
  { id:"bounce", name:"도탄 팽이구 (바운스)", speed:350, icon:"proj_bounce_32px_pastel.png", desc:"회전하는 쇠구슬 팽이. 3연속 바운스(도탄) 특성 타워 발사체.", special:"도탄 (3회 바운스·고속 회전)" }
];

function styleFor(word, data) {
  const category = String(data.category || "");
  const fallback = CATEGORY_FALLBACK[category] || "balanced";
  if (EXACT[word]) {
    const trait = EXACT[word];
    return { trait, label: (RULES.find(r => r.trait === trait) || {}).label || TRAIT_NAMES[trait], source:"exact" };
  }
  const hay = word + " " + (data.name || "") + " " + (data.desc || "");
  for (const rule of RULES) {
    if (rule.keys.some(k => hay.includes(k))) return { trait: rule.trait, label: rule.label, source:"rule" };
  }
  return { trait: fallback, label: CAT_LABELS[category] || "", source:"category" };
}

function previewStats(word, data) {
  const level = Math.max(1, Math.min(3, Array.from(word).length));
  const base = BASE_DAMAGE[level - 1] * 1.25;
  let trait = styleFor(word, data).trait;
  if (word === "볼") trait = "bounce";
  const interval = (TRAIT_INTERVAL[trait] ?? 0.8) * INTERVAL_MULT[level - 1];
  const perHit = base * (TRAIT_MULT[trait] ?? 1);
  const volley = (trait === "meteor" || trait === "orbit") ? 1 : VOLLEY[level - 1];
  return { perHit, volley, interval, dps: perHit * volley / Math.max(interval, 0.001), trait, range: TRAIT_RANGE[trait] ?? 150 };
}

function recipe(word) {
  return Array.from(word).map(ch => {
    const code = ch.codePointAt(0);
    if (code < 0xAC00 || code > 0xD7A3) return ch;
    const s = code - 0xAC00;
    const cho = Math.floor(s / 588);
    const jung = Math.floor((s % 588) / 28);
    const jong = s % 28;
    return [CHOSUNG[cho], JUNGSUNG[jung], JONGSUNG[jong]].filter(Boolean).join("");
  }).join(" + ");
}

function iconSrc(icon) {
  if (!icon) return "";
  return encodeURI(String(icon).replace("res://assets/", "./assets/"));
}

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, c => ({ "&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;" }[c]));
}

const balanced1 = previewStats("가", {});
if (Math.abs(balanced1.dps - 12.5) > 0.05) {
  throw new Error("preview_stats drift");
}

const FILTERS = [
  { id:"all", name:"전체" },
  { id:"tier1", name:"1글자" },
  { id:"tier2", name:"2글자" },
  { id:"tier3", name:"3글자" },
  ...Object.entries(CAT_LABELS).map(([id, name]) => ({ id, name }))
];
const MONSTER_FILTERS = [
  { id:"all", name:"전체" },
  { id:"act1", name:"1막" },
  { id:"act2", name:"2막" },
  { id:"act3", name:"3막" },
  { id:"boss", name:"보스" },
  { id:"fast", name:"질풍" },
  { id:"armored", name:"중갑" },
  { id:"swarm", name:"군집" },
  { id:"regen", name:"재생" },
  { id:"splitter", name:"분열" },
  { id:"swift", name:"질주" },
  { id:"warded", name:"결계" }
];
const RELIC_FILTERS = [
  { id:"all", name:"전체" },
  { id:"c25", name:"25G" },
  { id:"c30", name:"30G" },
  { id:"c35", name:"35G" },
  { id:"c40", name:"40G" }
];
const PROJECTILE_FILTERS = [
  { id:"all", name:"전체" },
  { id:"bullet", name:"균형" },
  { id:"slash", name:"연사" },
  { id:"fire", name:"폭발" },
  { id:"dot", name:"지속피해" },
  { id:"arrow", name:"저격" },
  { id:"pierce", name:"관통" },
  { id:"ice", name:"제어" },
  { id:"lightning", name:"연쇄" },
  { id:"bounce", name:"도탄" }
];

let words = [];
let filter = "all";
let section = "words";

function currentFilters() {
  if (section === "monsters") return MONSTER_FILTERS;
  if (section === "relics") return RELIC_FILTERS;
  if (section === "projectiles") return PROJECTILE_FILTERS;
  return FILTERS;
}
function attrLabel(attr) {
  if (attr.startsWith("warded:")) return "결계(" + (TRAIT_NAMES[attr.slice(7)] || attr.slice(7)) + ")";
  return ATTR_LABELS[attr] || attr;
}
function attrColor(attr) {
  return ATTR_COLORS[attr.startsWith("warded:") ? "warded" : attr] || "#9aa0c4";
}
function passMonster(m) {
  if (filter === "all") return true;
  if (filter.startsWith("act")) return m.act === Number(filter.slice(3));
  if (filter === "boss" || filter === "fast" || filter === "armored" || filter === "swarm") return m.type === filter;
  if (filter === "warded") return m.attrs.some(a => a.startsWith("warded:"));
  return m.attrs.includes(filter);
}
function picture(src, fallback) {
  return src
    ? "<img class='icon' src='" + src + "' alt='' data-fallback='" + esc(fallback) + "' />"
    : "<div class='glyph'>" + esc(fallback) + "</div>";
}
function monsterHtml(m) {
  const badges = ["<span class='badge'>" + m.act + "막</span>",
    "<span class='badge' style='color:" + TYPE_COLORS[m.type] + "'>" + esc(TYPE_LABELS[m.type]) + "</span>"]
    .concat(m.attrs.map(a => "<span class='badge' style='color:" + attrColor(a) + "'>" + esc(attrLabel(a)) + "</span>"));
  return "<article class='card'>" + picture(encodeURI("./assets/monsters/" + m.icon), m.name[0]) +
    "<div class='name'>" + esc(m.name) + "</div><div class='note'>" + badges.join(" ") + "</div></article>";
}
function relicHtml(r) {
  return "<article class='card'>" + picture(encodeURI("./assets/relics/" + r.icon), r.name[0]) +
    "<div class='name'>" + esc(r.name) + "</div><div class='dps'>" + r.cost + " G</div>" +
    "<div class='note'>" + esc(r.desc) + "</div></article>";
}
function projectileHtml(p) {
  return "<article class='card'>" + picture(encodeURI("./assets/projectiles/" + p.icon), p.name[0]) +
    "<div class='name'>" + esc(p.name) + "</div>" +
    "<div class='dps'>" + esc(p.special) + "</div>" +
    "<div class='note'>" + esc(p.desc) + "</div></article>";
}
function syncSection() {
  const titles = { words:"활자 도감", monsters:"몬스터 도감", relics:"유물 도감", projectiles:"투사체 도감" };
  document.getElementById("title").textContent = titles[section];
  document.getElementById("rules").style.display = section === "words" ? "" : "none";
  document.querySelectorAll("#sections button").forEach(btn => btn.classList.toggle("on", btn.dataset.section === section));
  const sort = document.getElementById("sort");
  if (section === "words") {
    sort.innerHTML = "<option value='no'>번호순</option><option value='dps'>DPS 높은순</option><option value='len'>글자수</option><option value='name'>이름</option>";
    document.getElementById("q").placeholder = "단어, 이름, 설명, 특성 검색";
  } else if (section === "monsters") {
    sort.innerHTML = "<option value='act'>막 순서</option><option value='name'>이름</option>";
    document.getElementById("q").placeholder = "몬스터, 타입, 속성 검색";
  } else if (section === "projectiles") {
    sort.innerHTML = "<option value='speed'>탄속순</option><option value='name'>이름</option>";
    document.getElementById("q").placeholder = "투사체, 설명, 특수효과 검색";
  } else {
    sort.innerHTML = "<option value='cost'>가격순</option><option value='name'>이름</option>";
    document.getElementById("q").placeholder = "유물, 효과 검색";
  }
  renderTabs();
}

async function loadJson(path) {
  const res = await fetch(path);
  if (!res.ok) throw new Error(path + " " + res.status);
  return res.json();
}

function mergeDb(base, extra) {
  const out = { ...base };
  for (const [k, v] of Object.entries(extra)) {
    if (!out[k]) out[k] = v;
  }
  if (!out["돼지"]) out["돼지"] = PIG;
  return Object.values(out).map((w, i) => {
    const word = String(w.word || "");
    const stats = previewStats(word, w);
    const style = styleFor(word, w);
    return {
      ...w,
      word,
      no: w.no ?? (1000 + i),
      length: word.length,
      stats,
      style,
      recipe: recipe(word)
    };
  });
}

function renderTabs() {
  document.getElementById("tabs").innerHTML = currentFilters().map(f =>
    "<button type='button' data-id='" + f.id + "' class='" + (f.id === filter ? "on" : "") + "'>" + f.name + "</button>"
  ).join("");
}

function passFilter(w) {
  if (filter === "all") return true;
  if (filter === "tier1") return w.length === 1;
  if (filter === "tier2") return w.length === 2;
  if (filter === "tier3") return w.length >= 3;
  return w.category === filter;
}

function cardHtml(w) {
  const tier = w.length >= 3 ? 3 : w.length;
  const src = iconSrc(w.icon);
  const fallback = esc(w.word[0] || "?");
  const icon = src
    ? "<img class='icon' src='" + src + "' alt='' data-fallback='" + fallback + "' />"
    : "<div class='glyph'>" + fallback + "</div>";
  return "<article class='card'>" + icon +
    "<div class='name' style='color:" + TIER_COLOR[tier] + "'>" + esc(w.word) +
    " <span class='badge' style='color:" + (TRAIT_COLORS[w.stats.trait] || "#fff") + "'>" + esc(TRAIT_NAMES[w.stats.trait] || w.stats.trait) + "</span></div>" +
    "<div class='dps'>💥 " + w.stats.perHit.toFixed(1) + " · DPS " + w.stats.dps.toFixed(1) + "</div></article>";
}

function render() {
  const q = document.getElementById("q").value.trim();
  const sort = document.getElementById("sort").value;
  let list, total, html;
  if (section === "monsters") {
    list = MONSTERS.filter(passMonster);
    if (q) list = list.filter(m => [m.name, TYPE_LABELS[m.type], m.attrs.map(attrLabel).join(" ")].join(" ").includes(q));
    list.sort((a, b) => sort === "name" ? a.name.localeCompare(b.name, "ko") : a.act - b.act || a.name.localeCompare(b.name, "ko"));
    total = MONSTERS.length;
    html = list.map(monsterHtml).join("");
    document.getElementById("count").textContent = list.length + " / " + total + "종";
  } else if (section === "relics") {
    list = RELICS.filter(r => filter === "all" || ("c" + r.cost) === filter);
    if (q) list = list.filter(r => [r.name, r.desc].join(" ").includes(q));
    list.sort((a, b) => sort === "name" ? a.name.localeCompare(b.name, "ko") : a.cost - b.cost || a.name.localeCompare(b.name, "ko"));
    total = RELICS.length;
    html = list.map(relicHtml).join("");
    document.getElementById("count").textContent = list.length + " / " + total + "종";
  } else if (section === "projectiles") {
    list = PROJECTILES.filter(p => filter === "all" || p.id === filter);
    if (q) list = list.filter(p => [p.name, p.desc, p.special].join(" ").includes(q));
    list.sort((a, b) => sort === "name" ? a.name.localeCompare(b.name, "ko") : b.speed - a.speed || a.name.localeCompare(b.name, "ko"));
    total = PROJECTILES.length;
    html = list.map(projectileHtml).join("");
    document.getElementById("count").textContent = list.length + " / " + total + "종";
  } else {
    list = words.filter(passFilter);
    if (q) list = list.filter(w => [w.word, w.name, w.desc, TRAIT_NAMES[w.stats.trait], w.style.label].join(" ").includes(q));
    list.sort((a, b) => {
      if (sort === "dps") return b.stats.dps - a.stats.dps;
      if (sort === "len") return b.length - a.length || a.no - b.no;
      if (sort === "name") return a.word.localeCompare(b.word, "ko");
      return a.no - b.no;
    });
    total = words.length;
    html = list.map(cardHtml).join("");
    document.getElementById("count").textContent = list.length + " / " + total + "종 · 발당·DPS는 본편 타워와 같은 식";
  }
  document.getElementById("grid").innerHTML = html;
}

document.getElementById("tabs").addEventListener("click", e => {
  const id = e.target.dataset.id;
  if (!id) return;
  filter = id;
  renderTabs();
  render();
});
document.getElementById("sections").addEventListener("click", e => {
  const next = e.target.dataset.section;
  if (!next || next === section) return;
  section = next;
  filter = "all";
  syncSection();
  render();
});
document.getElementById("grid").addEventListener("error", e => {
  const img = e.target;
  if (img.tagName !== "IMG" || !img.classList.contains("icon")) return;
  const g = document.createElement("div");
  g.className = "glyph";
  g.textContent = img.dataset.fallback || "?";
  img.replaceWith(g);
}, true);
document.getElementById("q").addEventListener("input", render);
document.getElementById("sort").addEventListener("change", render);
syncSection();

Promise.all([
  loadJson("./assets/data/word_database_265.json"),
  loadJson("./assets/data/word_database_expansion_100.json")
]).then(([base, extra]) => {
  words = mergeDb(base, extra);
  render();
}).catch(err => {
  document.getElementById("count").textContent = "활자 데이터를 못 읽음";
  render();
});
