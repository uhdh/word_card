# AttackStyle.gd
# 단어의 '뜻' 을 공격의 '형태' 로 번역한다.
#
# 문제: 예전에는 word_data["category"] (weapon/element/nature/…) 만 보고 특성을 정했다.
#   - 카테고리는 9종뿐이라 "불" 과 "얼음" 이 똑같이 element → 지속 피해가 됐다.
#   - 3음절이 되면 무조건 meteor/orbit 로 '승격' 시켜서, 단어 뜻이 통째로 지워졌다.
#     (예: "불사조" 가 유성이 됨)
# 결과적으로 플레이어가 단어를 고르는 기준이 '숫자' 밖에 없었다.
#
# 해법: 단어/이름/설명 텍스트에서 의미 키워드를 찾아 공격 형태로 매핑한다.
#   우선순위 = EXACT(단어 자체) → KEYWORDS(이름+설명 스캔) → CATEGORY(기존 폴백).
#   못 찾으면 지금까지의 카테고리 규칙을 그대로 쓴다 — 회귀 없음.
class_name AttackStyle
extends RefCounted

## 공격 형태 하나. trait 은 WordTower 의 특성 id, proj 는 Projectile 텍스처 키.
## keys 는 단어/이름/설명에서 찾을 조각. 2글자 이상을 기본으로 한다
## (한 글자는 "문화"의 '화', "그물"의 '물' 처럼 엉뚱한 단어에 걸린다).
const RULES: Array = [
	# ── 불 ──
	{"trait": "damage_over_time", "proj": "dot", "label": "불꽃",
	 "keys": ["불꽃", "불길", "화염", "불타", "태우", "화상", "작열", "용암", "홍염", "불덩", "뜨거", "화산"]},
	# ── 얼음/냉기 ──
	{"trait": "control", "proj": "ice", "label": "혹한",
	 "keys": ["얼음", "빙결", "동결", "서리", "눈보라", "냉기", "혹한", "한파", "설원", "빙판"]},
	# ── 번개 ──
	{"trait": "chain", "proj": "lightning", "label": "번개",
	 "keys": ["번개", "벼락", "천둥", "전격", "감전", "뇌전", "전류", "뇌명"]},
	# ── 바람 ──
	{"trait": "rapid", "proj": "slash", "label": "질풍",
	 "keys": ["바람", "질풍", "회오리", "돌풍", "태풍", "광풍", "선풍", "폭풍"]},
	# ── 물 ──
	{"trait": "control", "proj": "ice", "label": "급류",
	 "keys": ["파도", "해일", "홍수", "물결", "급류", "물보라", "소용돌이", "바닷"]},
	# ── 흙/돌/대지 ──
	{"trait": "splash", "proj": "fire", "label": "대지",
	 "keys": ["대지", "지진", "바위", "암석", "모래", "흙더미", "돌덩", "산사태", "낙석"]},
	# ── 어둠/저주/독 ──
	{"trait": "damage_over_time", "proj": "dot", "label": "독",
	 "keys": ["독가시", "독벌", "독샘", "독구름", "독안개", "맹독", "독기", "부식", "독액", "중독", "저주", "어둠", "암흑", "부패", "저승", "그림자", "흑마"]},
	# ── 식물/자연 ──
	{"trait": "splash", "proj": "fire", "label": "자연",
	 "keys": ["가시", "덩굴", "뿌리", "이끼", "숲", "풀잎", "꽃잎", "나뭇", "씨앗", "수액"]},
	# ── 빛/신성 ──
	{"trait": "meteor", "proj": "lightning", "label": "심판",
	 "keys": ["신성", "정화", "퇴마", "성광", "빛기둥", "심판", "축복", "홀리"]},
	# ── 금속/칼 ──
	{"trait": "sniper", "proj": "arrow", "label": "예리",
	 "keys": ["검기", "칼날", "대검", "장검", "창끝", "화살", "예리", "베어", "참격",
	          "단검", "비수", "단도", "석궁", "저격", "암살", "급소"]},
	# ── 둔기/충격 ──
	{"trait": "pierce", "proj": "pierce", "label": "강타",
	 "keys": ["강타", "충격", "분쇄", "참격", "내리치", "때려", "망치", "철퇴",
	          "도끼", "해머", "몽둥이", "방망이", "곤봉"]},
	# ── 시간/정지 ──
	{"trait": "control", "proj": "ice", "label": "정지",
	 "keys": ["시간", "정지", "멈춤", "느려", "지연", "시계", "속박"]},
	# ── 소리/함성 ──
	{"trait": "chain", "proj": "lightning", "label": "공명",
	 "keys": ["함성", "포효", "외침", "고함", "메아리", "공명", "울림", "노래"]},
	# ── 지식/책 ──
	{"trait": "orbit", "proj": "slash", "label": "지혜",
	 "keys": ["성경", "책장", "글귀", "지식", "기록", "두루마리", "문장", "학문", "서책"]},
	# ── 소환수/짐승 ──
	# 주의: 짐승이라고 다 summon 카테고리가 아니다 — 사슴은 skill, 오징어는 defense,
	# 매미/나비/거머리/너구리도 skill 이다. 카테고리 폴백에 맡기면 사슴이 '연쇄',
	# 오징어가 '관통' 이 되어 뜻과 정면으로 어긋난다. 그래서 이름으로 먼저 잡는다.
	{"trait": "orbit", "proj": "slash", "label": "야수",
	 "keys": ["소환", "불러", "정령", "사역", "야수", "짐승", "새끼",
	          "사슴", "오징어", "매미", "나비", "거머리", "너구리", "고양이", "여우",
	          "늑대", "호랑이", "사자", "개구리", "도마뱀", "거북", "독수리",
	          "까마귀", "구렁이", "악어", "기러기", "물개", "두더지", "오리", "질주마"]},
	# ── 황금/재물 ──
	{"trait": "rapid", "proj": "slash", "label": "황금",
	 "keys": ["황금", "금화", "보물", "재물", "동전", "금괴"]},
	# ── 회복/생명 ──
	{"trait": "control", "proj": "ice", "label": "생명",
	 "keys": ["회복", "치유", "소생", "생명", "약초", "치료", "봄바람", "온기"]},
	# ── 도탄/바운스 ──
	{"trait": "bounce", "proj": "bounce", "label": "도탄",
	 "keys": ["바운스", "도탄", "쇠구슬", "유도탄", "개구리", "마술사", "도적단", "물수제비"]},
]

## 단어 자체가 곧 규칙인 경우. 키워드 스캔보다 먼저 본다.
const EXACT: Dictionary = {
	"불": "damage_over_time", "독": "damage_over_time", "얼": "control", "눈": "control", "빙": "control",
	"번": "chain", "뇌": "chain", "바": "rapid", "물": "control", "돌": "bounce",
	"칼": "sniper", "검": "sniper", "활": "sniper", "책": "orbit", "성": "meteor",
	"금": "rapid", "봄": "control", "숲": "splash", "산": "splash", "강": "control",
	"볼": "bounce", "감": "bounce", "굿": "bounce", "개구리": "bounce", "도적단": "bounce", "마술사": "bounce",
}

## 카테고리 폴백 — 의미 키워드를 하나도 못 찾았을 때만 쓴다.
## (예전 동작을 그대로 보존한다: 이게 있어야 기존 밸런스가 안 흔들린다)
const CATEGORY_FALLBACK: Dictionary = {
	"weapon": "sniper", "element": "damage_over_time", "nature": "splash",
	"magic": "meteor", "summon": "orbit", "buff": "rapid", "defense": "pierce",
	"heal": "control", "skill": "chain",
}

## 폴백이 쓰였을 때 툴팁에 보여 줄 카테고리 이름.
## 단어 DB 전체의 절반 가량이 여기로 떨어진다 — 그때 아무 표시도 없으면
## 플레이어는 "이 형태가 어디서 왔는지" 알 수 없다. 뜻에서 온 것과 구분해 준다.
## (LexiconModal 의 필터 이름과 맞춘다)
const CATEGORY_LABELS: Dictionary = {
	"weapon": "무기", "element": "원소", "nature": "자연", "magic": "마법",
	"summon": "생물", "buff": "강화", "defense": "방어", "heal": "회복", "skill": "기술",
}


## 단어 하나의 공격 형태를 정한다.
## 반환: {"trait": String, "proj": String, "label": String, "matched": bool, "source": String}
##   source = "exact" | "rule" | "category" — 형태가 어디서 결정됐는지.
static func style_for(word: String, word_data: Dictionary) -> Dictionary:
	var category := str(word_data.get("category", ""))
	var fallback_trait: String = CATEGORY_FALLBACK.get(category, "balanced")
	# 1) 단어 자체가 규칙이면 즉시 채택
	if EXACT.has(word):
		var trait_id: String = EXACT[word]
		return {"trait": trait_id, "proj": proj_for_trait(trait_id), "label": label_for_trait(trait_id), "matched": true, "source": "exact"}
	# 2) 이름 + 설명에서 의미 키워드를 찾는다
	var haystack := "%s %s %s" % [word, str(word_data.get("name", "")), str(word_data.get("desc", ""))]
	for rule in RULES:
		for key in rule["keys"]:
			if haystack.find(str(key)) >= 0:
				return {"trait": str(rule["trait"]), "proj": str(rule["proj"]), "label": str(rule["label"]), "matched": true, "source": "rule"}
	# 3) 폴백 — 예전과 동일한 카테고리 규칙. 뜻이 아니라 분류에서 온 형태임을 밝힌다.
	return {"trait": fallback_trait, "proj": proj_for_trait(fallback_trait), "label": str(CATEGORY_LABELS.get(category, "")), "matched": false, "source": "category"}


## 특성 id → 기본 투사체 외형.
static func proj_for_trait(trait_id: String) -> String:
	match trait_id:
		"damage_over_time": return "dot"
		"splash": return "fire"
		"sniper": return "arrow"
		"pierce": return "pierce"
		"rapid": return "slash"
		"control": return "ice"
		"chain": return "lightning"
		"bounce": return "bounce"
		_: return "bullet"


## 특성 id → 의미 라벨. 규칙에서 못 찾은 특성은 빈 문자열.
static func label_for_trait(trait_id: String) -> String:
	for rule in RULES:
		if str(rule["trait"]) == trait_id:
			return str(rule["label"])
	return ""
