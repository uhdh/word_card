# 에테르AI (AetherForge) 무료 에셋 API 가이드

## 🔗 API Endpoint

```
GET https://www.aetherforgeai.com/api/assets
```

### 파라미터

| 파라미터 | 설명 | 예시 |
|---------|------|------|
| `style` | 에셋 스타일 | `32px_pastel`, `32px`, `adventure_rpg`, `dark_pixel_rpg` |
| `category` | 에셋 카테고리 | `Sword, Greatsword, Dagger` |
| `limit` | 페이지당 결과 수 | `50` (최대 50 권장) |
| `page` | 페이지 번호 | `1` |

### 사용 가능한 스타일 목록
- `32px_pastel` ← 이 프로젝트에서 사용
- `32px`
- `adventure_rpg`
- `casual_mmorpg`
- `classic_fantasy_rpg`
- `dark_pixel_rpg`
- `eastern_4d_rpg`

### 사용 가능한 카테고리 목록
- `Alchemy Materials`
- `Axe, Hammer, Mace`
- `Belt, Cape, Cloak, Mask, Shoulder Accessory`
- `Bow, Crossbow, Gun`
- `Building`
- `Character`
- `Cloth Armor`
- `Consumables`
- `Daily Life Materials`
- `Daily Tools`
- `Electronics`
- `Event Items`
- `Gathering Materials`
- `Head Accessory, Wings`
- `Leather Armor`
- `Minerals & Gem Materials`
- `Monster`
- `Monster Loot`
- `Neklace, Earrings, Ring, Bracelets`
- `Plate Armor`
- `Prop`
- `Sample`
- `Seal, Talisman, Artifact, Emblem`
- `Spear, Polearm, Gauntlet`
- `Staff, Wand, Orb, Spellbook`
- `Sword, Greatsword, Dagger`
- `Textile Materials`
- `Whip, Scythe, Shield`

---

## 📡 API 응답 형식

```json
{
  "assets": [
    {
      "id": "6e970201-8ceb-4f4f-a6fc-d32c37abcc5d",
      "style": "32px_pastel",
      "category": "Sword, Greatsword, Dagger",
      "image_url": "assets/5b0c9eac-d2b2-4ad0-8138-4ff731b10ec8.png"
    }
  ],
  "categories": [...],
  "styles": [...],
  "total": 19014,
  "total_pages": 1902,
  "limit": 10,
  "page": 1
}
```

### 이미지 CDN URL 조합 방법
```
https://cdn.aetherforgeai.com/ + image_url
= https://cdn.aetherforgeai.com/assets/{UUID}.png
```

---

## 🐍 Python 다운로드 예시

```python
import urllib.request
import urllib.parse
import json
import os
import time

BASE_CDN = "https://cdn.aetherforgeai.com/"
API_BASE = "https://www.aetherforgeai.com/api/assets"

def fetch_assets(category, style="32px_pastel", limit=50, page=1):
    url = (
        f"{API_BASE}"
        f"?style={urllib.parse.quote(style)}"
        f"&category={urllib.parse.quote(category)}"
        f"&limit={limit}&page={page}"
    )
    req = urllib.request.Request(
        url, headers={"Accept": "application/json", "User-Agent": "Mozilla/5.0"}
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())

def download_image(image_url, local_path):
    full_url = BASE_CDN + image_url
    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    req = urllib.request.Request(full_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        with open(local_path, "wb") as f:
            f.write(resp.read())

# 사용 예시
data = fetch_assets(category="Sword, Greatsword, Dagger", style="32px_pastel", limit=50)
print(f"총 {data['total']}개 에셋 중 {len(data['assets'])}개 로드")

for i, asset in enumerate(data["assets"][:3]):
    local_path = f"assets/sword_{i+1}_32px_pastel.png"
    download_image(asset["image_url"], local_path)
    print(f"저장: {local_path}")
    time.sleep(0.2)  # 서버 부하 방지
```

---

## 📂 이 프로젝트의 에셋 저장 규칙

### 폴더 구조
```
E:\project\word_card\assets\
├── 01_무기_공격/{영문명}_{한글}/
├── 02_방어_장비/{영문명}_{한글}/
├── 03_원소_마법/{영문명}_{한글}/
├── 04_생물_소환/{영문명}_{한글}/
├── 05_구조_필드/{영문명}_{한글}/
├── 06_회복_치유/{영문명}_{한글}/
└── 07_버프_유틸/{영문명}_{한글}/
```

### 파일명 규칙
```
{영문명}_{번호}_32px_pastel.png
예: sword_1_32px_pastel.png
```

### manifest 구조 (assets/word_assets_manifest.json)
단어 -> { word, name_en, category_group, desc, asset_count, assets: [{id, file_name, relative_path, style, category, url}] }

---

## ⚠️ 주의사항

- 에테르AI 무료 에셋 페이지는 SPA(Next.js)라 read_url_content로는 에셋 목록이 안 보임
- API는 로그인 없이 GET 요청으로 사용 가능 (무료 에셋 한정)
- 다운로드 요청 사이에 time.sleep(0.2) 정도 넣어 서버 부하 방지
- 같은 카테고리에서 여러 단어가 에셋을 공유하면 offset 인덱스로 구분
- 카테고리명에 쉼표/특수문자 있으므로 반드시 urllib.parse.quote() 처리
