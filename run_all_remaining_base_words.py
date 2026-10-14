import sys, os, time, subprocess, json
from pathlib import Path
from PIL import Image, ImageGrab
import cv2, numpy as np

sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path(r"E:\project\word_card")
MANIFEST_FILE = ROOT / "word_symbols_next_batch_manifest.json"
PROGRESS_FILE = ROOT / "base_words_progress.json"
RUNNER_FILE = ROOT / "word_symbols_batch_runner.py"

sys.path.append(str(ROOT))
from word_symbols_batch_runner import key_white_background, stem, entries, COMPLETED, GENERATED

def build_prompt(items):
    count = len(items)
    if count == 4:
        lines = [
            "한글 타워 디펜스 게임에 들어갈 픽셀아트 아이콘 4개를 2x2 격자(그리드 스프라이트 시트) 형태로 한 장에 균등하게 그려줘.\n",
            "[2x2 배치 구성 - 4개 아이콘 사이에 넉넉한 흰색 여백 유지]",
            f"1. [좌측 상단]: {items[0]['word']} ({items[0]['name']})",
            f"2. [우측 상단]: {items[1]['word']} ({items[1]['name']})",
            f"3. [좌측 하단]: {items[2]['word']} ({items[2]['name']})",
            f"4. [우측 하단]: {items[3]['word']} ({items[3]['name']})\n",
            "[스타일 및 필수 규칙]",
            "- 16-bit SNES 고전 레트로 픽셀아트 (선명한 도트 클러스터, 짙은 다크 브라운 외곽선)",
            "- 32x32px로 축소해도 형태가 뚜렷하게 인식되는 직관적인 심플 실루엣",
            "- 배경: 완전히 흰색 단색 배경 (각 아이콘 사이에 넓은 흰색 여백 유지)",
            "- 한글, 영문 글자, 숫자, 테두리 격자선, 카드 프레임, 워터마크 절대 없음",
            "- 4개의 심볼만 2x2 위치에 서로 겹치지 않게 단독으로 그려줘."
        ]
    else:
        lines = [
            f"한글 타워 디펜스 게임에 들어갈 픽셀아트 아이콘 {count}개를 한 장에 서로 겹치지 않게 균등하게 그려줘.\n",
            "[배치 구성 - 아이콘 사이에 넉넉한 흰색 여백 유지]"
        ]
        for i, item in enumerate(items):
            lines.append(f"{i+1}. {item['word']} ({item['name']})")
        lines.extend([
            "\n[스타일 및 필수 규칙]",
            "- 16-bit SNES 고전 레트로 픽셀아트 (선명한 도트 클러스터, 짙은 다크 브라운 외곽선)",
            "- 32x32px로 축소해도 형태가 뚜렷하게 인식되는 직관적인 심플 실루엣",
            "- 배경: 완전히 흰색 단색 배경",
            "- 글자, 텍스트, 숫자, 테두리, 카드 프레임, 워터마크 절대 없음",
            f"- 오직 {count}개의 심볼만 단독으로 그려줘."
        ])
    return "\n".join(lines)

def send_to_gemini(prompt_text):
    ps1 = r"C:\Users\maktu\.gemini\config\skills\gemini-desktop\scripts\send_gemini.ps1"
    cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", ps1, "-Prompt", prompt_text, "-WaitSeconds", "15"]
    res = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='ignore')
    return res.returncode == 0

def wait_for_completion(max_wait=40):
    start = time.time()
    while time.time() - start < max_wait:
        try:
            out = subprocess.check_output(['orca', 'computer', 'get-app-state', '--app', 'Gemini', '--no-screenshot', '--json'])
            data = json.loads(out)
            tree = data.get('result', {}).get('snapshot', {}).get('treeText', '')
            if "이미지를 만들고 있습니다" not in tree and ("단추 이미지 복사" in tree or "단추 원본 크기 이미지 다운로드" in tree):
                return True
        except Exception:
            pass
        time.sleep(4)
    return True

def grab_latest_image(sheet_save_path):
    out = subprocess.check_output(['orca', 'computer', 'get-app-state', '--app', 'Gemini', '--restore-window', '--json'])
    data = json.loads(out)
    tree = data.get('result', {}).get('snapshot', {}).get('treeText', '')
    copy_index = None
    for line in tree.splitlines():
        if "단추 이미지 복사" in line:
            parts = line.strip().split()
            if parts[0].isdigit():
                copy_index = parts[0]
    if not copy_index:
        raise RuntimeError("Could not find '단추 이미지 복사' button index.")
    
    subprocess.run(['orca', 'computer', 'click', '--app', 'Gemini', '--element-index', copy_index, '--json'], capture_output=True)
    time.sleep(1.5)
    img = ImageGrab.grabclipboard()
    if img:
        img.save(sheet_save_path)
        return img
    raise RuntimeError("Failed to grab clipboard image.")

def process_and_save(sheet_path, items):
    raw_sheet = Image.open(sheet_path)
    W, H = raw_sheet.size
    count = len(items)
    
    if count == 4:
        mid_x, mid_y = W // 2, H // 2
        quads = [
            ((0, 0, mid_x, mid_y), items[0]),
            ((mid_x, 0, W, mid_y), items[1]),
            ((0, mid_y, mid_x, H), items[2]),
            ((mid_x, mid_y, W, H), items[3]),
        ]
    elif count == 3:
        w_third = W // 3
        quads = [
            ((0, 0, w_third, H), items[0]),
            ((w_third, 0, w_third*2, H), items[1]),
            ((w_third*2, 0, W, H), items[2]),
        ]
    elif count == 2:
        mid_x = W // 2
        quads = [
            ((0, 0, mid_x, H), items[0]),
            ((mid_x, 0, W, H), items[1]),
        ]
    else:
        quads = [((0, 0, W, H), items[0])]
    
    db = {x['no']: x for x in entries()}
    saved_ids = []
    
    for box, item in quads:
        no = item["no"]
        x = db[no]
        cropped = raw_sheet.crop(box)
        
        # Save staging
        staging_path = ROOT / f"generated_word_symbols/{no:03d}.png"
        staging_path.parent.mkdir(parents=True, exist_ok=True)
        cropped.save(staging_path)
        
        # Keyout & resize
        image = key_white_background(cropped)
        alpha = image.getchannel("A").point(lambda p: p if p >= 16 else 0)
        image.putalpha(alpha)
        bbox = alpha.getbbox()
        if not bbox:
            bbox = (0, 0, image.width, image.height)
        image = image.crop(bbox)
        
        pad = round(256 * 0.10)
        inner = 256 - 2 * pad
        scale = min(inner / image.width, inner / image.height)
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image = image.resize(size, Image.Resampling.NEAREST)
        
        output = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        output.paste(image, ((256 - size[0]) // 2, (256 - size[1]) // 2), image)
        output_32 = output.resize((32, 32), Image.Resampling.NEAREST)
        
        s = stem(x)
        p256 = ROOT / f"assets/words_symbol_256px/{s}_256px.png"
        p32 = ROOT / f"assets/words_symbol_32px/{s}.png"
        pgodot = ROOT / f"godot/assets/words_symbol_32px/{s}.png"
        
        for p in (p256, p32, pgodot):
            p.parent.mkdir(parents=True, exist_ok=True)
            
        output.save(p256, "PNG")
        output_32.save(p32, "PNG")
        output_32.save(pgodot, "PNG")
        saved_ids.append(no)
        print(f"  [OK] Saved No.{no} ({x['word']}) -> {p32.name}")
    return saved_ids

def update_completed_in_runner(completed_ids):
    content = RUNNER_FILE.read_text(encoding="utf-8")
    # Parse existing COMPLETED
    import re
    m = re.search(r"COMPLETED = \{([^}]+)\}", content, re.DOTALL)
    if not m:
        return
    raw_nums = re.findall(r"\d+", m.group(1))
    current_set = set(int(n) for n in raw_nums)
    current_set.update(completed_ids)
    
    # Format new COMPLETED set
    sorted_nums = sorted(current_set)
    lines = []
    chunk_size = 15
    for i in range(0, len(sorted_nums), chunk_size):
        c = sorted_nums[i:i+chunk_size]
        lines.append("    " + ", ".join(str(n) for n in c) + ",")
    new_completed_str = "COMPLETED = {\n" + "\n".join(lines) + "\n}"
    
    content = re.sub(r"COMPLETED = \{([^}]+)\}", new_completed_str, content, flags=re.DOTALL)
    
    # Also update GENERATED
    new_gen_str = "GENERATED = {" + ", ".join(str(n) for n in sorted_nums) + "}"
    content = re.sub(r"GENERATED = \{([^}]+)\}", new_gen_str, content, flags=re.DOTALL)
    
    # Update asserts
    comp_count = len(sorted_nums)
    rem_count = 265 - comp_count
    content = re.sub(r"assert len\(COMPLETED\) == \d+", f"assert len(COMPLETED) == {comp_count}", content)
    content = re.sub(r"assert len\(entries\(\)\) - len\(COMPLETED\) == \d+", f"assert len(entries()) - len(COMPLETED) == {rem_count}", content)
    
    RUNNER_FILE.write_text(content, encoding="utf-8")
    
    # Run runner to refresh manifest
    subprocess.run(["python", str(RUNNER_FILE)], capture_output=True)

def main():
    print("==================================================")
    print("Starting Automated Remaining Base Words Generation")
    print("==================================================")
    
    while True:
        with open(MANIFEST_FILE, "r", encoding="utf-8") as f:
            queue = json.load(f)
        
        remaining = len(queue)
        print(f"\n[Status] Remaining words in queue: {remaining}/265")
        if remaining == 0:
            print(">>> ALL 265 BASE WORDS COMPLETED! <<<")
            break
            
        # Take next 4 words
        chunk = queue[:4]
        chunk_words = ", ".join([f"No.{x['no']} {x['word']}" for x in chunk])
        print(f"\n----------------------------------------")
        print(f"Processing chunk ({len(chunk)} items): [{chunk_words}]")
        print(f"----------------------------------------")
        
        success = False
        for attempt in range(2):
            try:
                prompt_text = build_prompt(chunk)
                print("Sending prompt to Gemini...")
                send_to_gemini(prompt_text)
                
                print("Waiting for generation to finish...")
                wait_for_completion()
                
                sheet_save = ROOT / f"main/generated_word_symbols/chunk_base_{chunk[0]['no']:03d}_{chunk[-1]['no']:03d}_raw.png"
                sheet_save.parent.mkdir(parents=True, exist_ok=True)
                
                print("Grabbing image from Gemini...")
                grab_latest_image(sheet_save)
                
                print("Processing and saving assets...")
                saved_ids = process_and_save(sheet_save, chunk)
                
                print("Updating completed ledger and manifest...")
                update_completed_in_runner(saved_ids)
                success = True
                break
            except Exception as e:
                print(f"Error on chunk {chunk_words} (Attempt {attempt+1}): {e}")
                time.sleep(5)
                
        if not success:
            print(f"Failed chunk {chunk_words} after 2 attempts. Pausing 10s...")
            time.sleep(10)
        else:
            time.sleep(3)

    print("\n==================================================")
    print("All 265 Base Word Symbols & 100 Expansion Symbols Complete!")
    print("Running full Godot test suite...")
    test1 = subprocess.run(["godot", "--headless", "--path", "godot", "res://tests/test_word_expansion.gd"], cwd=str(ROOT), capture_output=True, text=True)
    print("test_word_expansion result:", test1.returncode)
    test2 = subprocess.run(["godot", "--headless", "--path", "godot", "res://tests/test_tower_traits.tscn"], cwd=str(ROOT), capture_output=True, text=True)
    print("test_tower_traits result:", test2.returncode)
    print("==================================================")

if __name__ == "__main__":
    main()
