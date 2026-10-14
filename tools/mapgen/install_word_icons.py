# -*- coding: utf-8 -*-
"""확장 단어 100개의 아이콘을 오픈소스 아이콘 세트에서 골라 설치한다.

- assets/open_source/words_exp/word_exp_<단어>.png 로 32x32 통일 저장
- word_database_expansion_100.json 의 icon 필드를 ./assets/open_source/... 로 갱신
"""
import json
import os
import shutil

from PIL import Image

ROOT = r"E:\project\word_card\godot"
OUT_DIR = os.path.join(ROOT, "assets", "open_source", "words_exp")
JSON_PATH = os.path.join(ROOT, "assets", "data", "word_database_expansion_100.json")

IV = os.path.join(ROOT, "assets", "open_source", "idylwild_inventory")
IA = os.path.join(ROOT, "assets", "open_source", "idylwild_arsenal")
RG = os.path.join(ROOT, "assets", "open_source", "rpg_icons_496")

# 단어 -> (세트, 아이콘 이름)
MAP = {
    "도망": (RG, "S_Wind01"), "도장": (RG, "I_Ink"), "도로": (RG, "I_Map"),
    "도시": (RG, "S_Holy05"), "도서": (RG, "W_Book01"), "도안": (RG, "I_Scroll"),
    "도구": (IV, "silver_shovel"), "대장": (RG, "Ac_Medal01"), "대문": (RG, "I_Key01"),
    "가방": (IV, "sack"), "가루": (IV, "bonemeal"), "가죽": (IV, "leather"),
    "가설": (RG, "E_Wood01"), "나라": (RG, "S_Holy06"), "다리": (RG, "E_Wood03"),
    "다섯": (RG, "E_Gold02"), "다짐": (RG, "S_Buff01"), "다수": (RG, "I_SilverCoin"),
    "다발": (IV, "wheat"), "라운드": (RG, "I_Clock"), "마루": (RG, "E_Wood02"),
    "마디": (IV, "stick"), "마상": (RG, "S_Physic01"), "마왕": (RG, "S_Shadow01"),
    "바다": (RG, "S_Water01"), "바지": (RG, "A_Clothing01"), "사과": (IV, "apple"),
    "사기": (RG, "S_Buff02"), "사막": (RG, "S_Earth01"), "사방": (RG, "S_Wind02"),
    "사슬": (IV, "chain"), "사슴": (RG, "I_FoxTail"), "사제": (RG, "S_Holy01"),
    "아군": (RG, "Ac_Medal02"), "아기": (IV, "egg"), "아들": (RG, "A_Clothing02"),
    "안식": (RG, "P_Medicine01"), "어부": (RG, "I_C_Fish"), "어전": (RG, "S_Holy03"),
    "어림": (RG, "I_Telescope"), "오두막": (RG, "E_Wood04"), "오솔길": (RG, "I_Scroll02"),
    "오름": (RG, "S_Wind03"), "오목": (RG, "I_Rock02"), "오징어": (RG, "I_Tentacle"),
    "우물": (RG, "I_Water"), "우산": (RG, "C_Hat02"), "우주": (RG, "I_Amethist"),
    "우승": (RG, "Ac_Medal03"), "우등": (RG, "Ac_Medal04"), "우수": (RG, "Ac_Necklace01"),
    "우정": (RG, "Ac_Ring01"), "이동": (RG, "S_Wind04"), "이름": (IV, "quill"),
    "이마": (RG, "I_Eye"), "이불": (RG, "I_Fabric"), "이슬": (RG, "I_Bottle02"),
    "이식": (IV, "herb"), "이자": (RG, "I_GoldCoin"), "이족": (RG, "A_Shoes01"),
    "수비": (RG, "A_Armor04"), "전사": (RG, "S_Physic02"), "장수": (RG, "S_Sword01"),
    "군사": (RG, "S_Sword02"), "전술": (RG, "I_Book"), "돌진": (RG, "W_Spear001"),
    "전진": (RG, "S_Wind05"), "석궁": (IA, "crossbow1"), "단도": (IA, "dagger1"),
    "방망이": (IA, "club1"), "머리": (RG, "C_Hat01"), "몸": (RG, "A_Armour01"),
    "마음": (RG, "P_Pink01"), "입": (RG, "I_C_RedPepper"), "입구": (RG, "I_Key02"),
    "문서": (IV, "parchment"), "서랍": (RG, "I_Chest02"), "상자": (IV, "basket"),
    "보관": (IV, "urn"), "보급": (RG, "I_Bottle03"), "보상": (RG, "E_Gold01"),
    "자원": (IV, "iron_ore"), "자물쇠": (RG, "I_Key03"), "수정": (RG, "I_Crystal01"),
    "수정구": (RG, "I_Crystal02"), "구슬": (RG, "I_Jade"), "구름": (RG, "S_Wind06"),
    "구멍": (RG, "I_Rock03"), "비밀": (RG, "I_Key04"), "비상": (RG, "S_Light01"),
    "비수": (RG, "W_Dagger001"), "불길": (RG, "S_Fire01"), "불씨": (RG, "S_Fire02"),
    "불덩이": (RG, "S_Fire03"), "물레": (IV, "thread"), "얼굴": (RG, "I_Mirror"),
    "눈물": (RG, "I_Bottle04"), "산맥": (RG, "S_Earth02"), "산길": (RG, "I_Rock04"),
    "산적": (RG, "S_Shadow02"),
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    data = json.load(open(JSON_PATH, encoding="utf-8"))
    missing_words = [w for w in data if w not in MAP]
    if missing_words:
        print("UNMAPPED:", missing_words)
    used = {}
    for word, (folder, name) in MAP.items():
        src = os.path.join(folder, name + ".png")
        if not os.path.exists(src):
            print("MISSING SOURCE:", word, src)
            continue
        dst = os.path.join(OUT_DIR, "word_exp_%s.png" % word)
        img = Image.open(src).convert("RGBA").resize((32, 32), Image.LANCZOS)
        img.save(dst)
        used[name] = used.get(name, 0) + 1
        if word in data:
            data[word]["icon"] = "./assets/open_source/words_exp/word_exp_%s.png" % word
    json.dump(data, open(JSON_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print("installed:", len(os.listdir(OUT_DIR)) // 1, "files")
    print("distinct icons used:", len(used))
    dupes = {k: v for k, v in used.items() if v > 1}
    print("reused icons:", dupes)


main()
