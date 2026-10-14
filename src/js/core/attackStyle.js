export const RULES = [
  { trait: "damage_over_time", proj: "dot", label: "불꽃",
    keys: ["불꽃", "불길", "화염", "불타", "태우", "화상", "작열", "용암", "홍염", "불덩", "뜨거", "화산"] },
  { trait: "control", proj: "ice", label: "혹한",
    keys: ["얼음", "빙결", "동결", "서리", "눈보라", "냉기", "혹한", "한파", "설원", "빙판"] },
  { trait: "chain", proj: "lightning", label: "번개",
    keys: ["번개", "벼락", "천둥", "전격", "감전", "뇌전", "전류", "뇌명"] },
  { trait: "rapid", proj: "slash", label: "질풍",
    keys: ["바람", "질풍", "회오리", "돌풍", "태풍", "광풍", "선풍", "폭풍"] },
  { trait: "control", proj: "ice", label: "급류",
    keys: ["파도", "해일", "홍수", "물결", "급류", "물보라", "소용돌이", "바닷"] },
  { trait: "splash", proj: "fire", label: "대지",
    keys: ["대지", "지진", "바위", "암석", "모래", "흙더미", "돌덩", "산사태", "낙석"] },
  { trait: "damage_over_time", proj: "dot", label: "독",
    keys: ["독가시", "독벌", "독샘", "독구름", "독안개", "맹독", "독기", "부식", "독액", "중독", "저주", "어둠", "암흑", "부패", "저승", "그림자", "흑마"] },
  { trait: "splash", proj: "fire", label: "자연",
    keys: ["가시", "덩굴", "뿌리", "이끼", "숲", "풀잎", "꽃잎", "나뭇", "씨앗", "수액"] },
  { trait: "meteor", proj: "lightning", label: "심판",
    keys: ["신성", "정화", "퇴마", "성광", "빛기둥", "심판", "축복", "홀리"] },
  { trait: "sniper", proj: "arrow", label: "예리",
    keys: ["검기", "칼날", "대검", "장검", "창끝", "화살", "예리", "베어", "참격",
           "단검", "비수", "단도", "석궁", "저격", "암살", "급소"] },
  { trait: "pierce", proj: "pierce", label: "강타",
    keys: ["강타", "충격", "분쇄", "참격", "내리치", "때려", "망치", "철퇴",
           "도끼", "해머", "몽둥이", "방망이", "곤봉"] },
  { trait: "control", proj: "ice", label: "정지",
    keys: ["시간", "정지", "멈춤", "느려", "지연", "시계", "속박"] },
  { trait: "chain", proj: "lightning", label: "공명",
    keys: ["함성", "포효", "외침", "고함", "메아리", "공명", "울림", "노래"] },
  { trait: "orbit", proj: "slash", label: "지혜",
    keys: ["성경", "책장", "글귀", "지식", "기록", "두루마리", "문장", "학문", "서책"] },
  { trait: "orbit", proj: "slash", label: "야수",
    keys: ["소환", "불러", "정령", "사역", "야수", "짐승", "새끼",
           "사슴", "오징어", "매미", "나비", "거머리", "너구리", "고양이", "여우",
           "늑대", "호랑이", "사자", "개구리", "도마뱀", "거북", "독수리",
           "까마귀", "구렁이", "악어", "기러기", "물개", "두더지", "오리", "질주마"] },
  { trait: "rapid", proj: "slash", label: "황금",
    keys: ["황금", "금화", "보물", "재물", "동전", "금괴"] },
  { trait: "control", proj: "ice", label: "생명",
    keys: ["회복", "치유", "소생", "생명", "약초", "치료", "봄바람", "온기"] },
  { trait: "bounce", proj: "bounce", label: "도탄",
    keys: ["바운스", "도탄", "쇠구슬", "유도탄", "개구리", "마술사", "도적단", "물수제비"] }
];

export const EXACT = {
  "불": "damage_over_time", "독": "damage_over_time", "얼": "control", "눈": "control", "빙": "control",
  "번": "chain", "뇌": "chain", "바": "rapid", "물": "control", "돌": "bounce",
  "칼": "sniper", "검": "sniper", "활": "sniper", "책": "orbit", "성": "meteor",
  "금": "rapid", "봄": "control", "숲": "splash", "산": "splash", "강": "control",
  "볼": "bounce", "감": "bounce", "굿": "bounce", "개구리": "bounce", "도적단": "bounce", "마술사": "bounce"
};

export const CATEGORY_FALLBACK = {
  "weapon": "sniper", "element": "damage_over_time", "nature": "splash",
  "magic": "meteor", "summon": "orbit", "buff": "rapid", "defense": "pierce",
  "heal": "control", "skill": "chain"
};

export const CATEGORY_LABELS = {
  "weapon": "무기", "element": "원소", "nature": "자연", "magic": "마법",
  "summon": "생물", "buff": "강화", "defense": "방어", "heal": "회복", "skill": "기술"
};

export function projForTrait(traitId) {
  switch (traitId) {
    case "damage_over_time": return "dot";
    case "splash": return "fire";
    case "sniper": return "arrow";
    case "pierce": return "pierce";
    case "rapid": return "slash";
    case "control": return "ice";
    case "chain": return "lightning";
    case "bounce": return "bounce";
    default: return "bullet";
  }
}

export function labelForTrait(traitId) {
  const r = RULES.find(rule => rule.trait === traitId);
  return r ? r.label : "";
}

export function styleFor(word, wordData = {}) {
  const category = String(wordData.category || "");
  const fallbackTrait = CATEGORY_FALLBACK[category] || "balanced";

  if (EXACT[word]) {
    const traitId = EXACT[word];
    return {
      trait: traitId,
      proj: projForTrait(traitId),
      label: labelForTrait(traitId),
      matched: true,
      source: "exact"
    };
  }

  const haystack = (word + " " + (wordData.name || "") + " " + (wordData.desc || ""));
  for (const rule of RULES) {
    for (const key of rule.keys) {
      if (haystack.includes(key)) {
        return {
          trait: rule.trait,
          proj: rule.proj,
          label: rule.label,
          matched: true,
          source: "rule"
        };
      }
    }
  }

  return {
    trait: fallbackTrait,
    proj: projForTrait(fallbackTrait),
    label: CATEGORY_LABELS[category] || "",
    matched: false,
    source: "category"
  };
}
